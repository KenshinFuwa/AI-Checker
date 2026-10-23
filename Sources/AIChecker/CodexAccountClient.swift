import Foundation
import AICheckerCore

/// An opt-in client for OpenAI's *official* `codex app-server` stdio protocol.
/// Every account uses its own CODEX_HOME, never ~/.codex or the desktop app's account.
/// AI Checker does not receive or store login credentials; Codex manages them.
final class CodexAccountClient {
    let profile: AICheckerAccount
    var onState: ((String) -> Void)?
    var onSnapshot: ((AIQuotaSnapshot?) -> Void)?
    var onFailure: ((ProviderFailure) -> Void)?
    var onOpenBrowser: ((URL) -> Void)?

    private let queue = DispatchQueue(label: "AI Checker.codex.rpc", qos: .utility)
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: (Result<[String: Any], Error>) -> Void] = [:]
    private var running = false
    private var authenticated = false
    private var isLoggingIn = false
    private var isInitialized = false
    private var loginRequested = false
    private let home: URL
    private let executableOverride: URL?
    private var stopRequested = false

    enum ClientError: LocalizedError {
        case missingBinary, invalidOutput, transportClosed, failed(String)
        var errorDescription: String? {
            switch self {
            case .missingBinary: return AppL10n.text("Codex CLIが見つかりません。codexの場所を設定してください。")
            case .invalidOutput: return AppL10n.text("Codex App Serverの応答形式が不正です。")
            case .transportClosed: return AppL10n.text("Codex App Serverとの接続が終了しました。")
            case .failed(let message): return message
            }
        }
    }

    init(profile: AICheckerAccount, executableOverride: URL? = nil, homeOverride: URL? = nil) {
        self.profile = profile
        self.executableOverride = executableOverride
        // UUID string is used as a single leaf path; never interpolate arbitrary labels.
        self.home = homeOverride ?? Self.accountHome(profile.id)
    }

    static func accountHome(_ id: UUID) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AI Checker/CodexAccounts", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func executable() -> URL? {
        let saved = UserDefaults.standard.string(forKey: "AIChecker.v13.codexExecutable")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [saved, "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex", "/usr/bin/codex"].compactMap { $0 }
        for path in candidates {
            guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else { continue }
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func state(_ value: String) { DispatchQueue.main.async { [weak self] in self?.onState?(value) } }
    private func snapshot(_ value: AIQuotaSnapshot?) { DispatchQueue.main.async { [weak self] in self?.onSnapshot?(value) } }
    private func failure(_ value: ProviderFailure) { DispatchQueue.main.async { [weak self] in self?.onFailure?(value) } }

    func start() {
        queue.async { [weak self] in self?.startInternal() }
    }

    private func startInternal() {
        guard !running else { return }
        stopRequested = false
        isInitialized = false
        guard let executable = executableOverride ?? Self.executable() else { state(ClientError.missingBinary.localizedDescription); return }
        do {
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let child = Process()
            child.executableURL = executable
            child.arguments = ["app-server", "--listen", "stdio://"]
            var environment = ProcessInfo.processInfo.environment
            // Do not let environment-based API credentials silently select a different identity.
            for key in ["CODEX_HOME", "OPENAI_API_KEY", "CODEX_API_KEY", "CHATGPT_AUTH_TOKEN", "OPENAI_ACCESS_TOKEN"] {
                environment.removeValue(forKey: key)
            }
            environment["CODEX_HOME"] = home.path
            child.environment = environment
            let stdin = Pipe()
            let stdout = Pipe()
            child.standardInput = stdin
            child.standardOutput = stdout
            child.standardError = FileHandle.nullDevice
            try child.run()
            process = child
            input = stdin.fileHandleForWriting
            running = true
            state(AppL10n.text("Codex App Serverに接続中…"))
            let output = stdout.fileHandleForReading
            DispatchQueue.global(qos: .utility).async { [weak self] in
                while true {
                    let chunk = output.availableData
                    if chunk.isEmpty { break }
                    self?.queue.async { [weak self] in self?.consume(chunk) }
                }
                self?.queue.async { [weak self] in self?.connectionClosed() }
            }
            request("initialize", params: ["clientInfo": ["name": "ai_checker", "title": "AI Checker", "version": "1.3.0"]]) { [weak self] reply in
                guard let self = self else { return }
                switch reply {
                case .failure: self.state(AppL10n.text("初期化に失敗しました")); self.stopInternal()
                case .success:
                    self.isInitialized = true
                    self.notify("initialized", params: [:])
                    self.readAccount()
                    if self.loginRequested { self.beginLoginInternal() }
                }
            }
        } catch {
            state(AppL10n.format("Codex App Serverを起動できません: %@", error.localizedDescription))
            stopInternal()
        }
    }

    private func send(_ json: [String: Any]) {
        guard running, let data = try? JSONSerialization.data(withJSONObject: json), var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        if let bytes = line.data(using: .utf8) { input?.write(bytes) }
    }

    private func notify(_ method: String, params: [String: Any]) {
        send(["method": method, "params": params])
    }

    private func request(_ method: String, params: [String: Any]? = nil,
                         callback: @escaping (Result<[String: Any], Error>) -> Void) {
        guard running else { callback(.failure(ClientError.transportClosed)); return }
        let id = nextID; nextID += 1
        pending[id] = callback
        var request: [String: Any] = ["id": id, "method": method]
        if let params = params { request["params"] = params }
        send(request)
        queue.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self, let callback = self.pending.removeValue(forKey: id) else { return }
            callback(.failure(ClientError.failed(AppL10n.text("Codex応答がタイムアウトしました"))))
        }
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        // Prevent unbounded memory if another executable writes unlimited text.
        if buffer.count > 2_000_000 { state(AppL10n.text("Codex応答が大きすぎます")); stopInternal(); return }
        while let newLine = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newLine])
            buffer.removeSubrange(...newLine)
            guard let msg = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { continue }
            if let id = (msg["id"] as? NSNumber)?.intValue,
               let callback = pending.removeValue(forKey: id) {
                if let error = msg["error"] as? [String: Any] {
                    // Avoid leaking server error contents that might include URLs or account identifiers.
                    let code = (error["code"] as? NSNumber)?.intValue ?? -1
                    callback(.failure(ClientError.failed("Codex RPC error \(code)")))
                } else if let result = msg["result"] as? [String: Any] {
                    callback(.success(result))
                } else { callback(.failure(ClientError.invalidOutput)) }
            } else if let method = msg["method"] as? String {
                if method == "account/login/completed" {
                    if let info = msg["params"] as? [String: Any], info["success"] as? Bool == true {
                        isLoggingIn = false
                        readAccount()
                    } else {
                        isLoggingIn = false
                        state(AppL10n.text("ログインが完了しませんでした。再試行できます。"))
                    }
                } else if method == "account/updated" && !isLoggingIn {
                    readAccount()
                }
            }
        }
    }

    private func connectionClosed() {
        if stopRequested { return }
        state(AppL10n.text("Codex App Serverが終了しました。次の操作で再接続してください。"))
        stopInternal()
    }

    private func readAccount() {
        request("account/read", params: ["refreshToken": false]) { [weak self] reply in
            guard let self = self else { return }
            switch reply {
            case .failure:
                self.authenticated = false
                self.failure(.init(.networkUnavailable))
                self.state(AppL10n.text("認証状態を確認できません"))
            case .success(let result):
                guard let account = result["account"] as? [String: Any], account["type"] as? String == "chatgpt" else {
                    self.authenticated = false
                    self.snapshot(nil)
                    self.failure(.init(.authenticationRequired))
                    self.state(AppL10n.text("未接続：このプロフィールでChatGPTログインしてください"))
                    return
                }
                self.authenticated = true
                let email = (account["email"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let verified = email.isEmpty ? "" : " / \(String(email.prefix(64)))"
                self.state(AppL10n.format("ChatGPT接続済み（%@）%@", self.profile.label, verified))
                self.readLimits()
            }
        }
    }

    func readLimits() {
        queue.async { [weak self] in
            guard let self = self, self.running, self.authenticated else { return }
            self.request("account/rateLimits/read") { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure:
                    self.failure(.init(.networkUnavailable))
                    self.state(AppL10n.text("利用制限を取得できません。次回再試行します。"))
                case .success(let reply):
                    if let valid = CodexAppServerQuotaDecoder.decodeResult(reply) {
                        self.snapshot(valid)
                    } else {
                        // Preserve last successful reading until freshness TTL;
                        // absence of a quota is not a logout or a zero percent.
                        self.failure(.init(.invalidResponse))
                        self.state(AppL10n.text("利用制限が返されませんでした（前回値は期限付き保持）"))
                    }
                }
            }
        }
    }

    func login() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.loginRequested = true
            if !self.running { self.startInternal() }
            else if self.isInitialized { self.beginLoginInternal() }
        }
    }

    private func beginLoginInternal() {
        guard running, isInitialized, !isLoggingIn else { return }
        loginRequested = false
        isLoggingIn = true
        request("account/login/start", params: ["type": "chatgpt"]) { [weak self] reply in
                guard let self = self else { return }
                switch reply {
                case .failure:
                    self.isLoggingIn = false
                    self.state(AppL10n.text("ブラウザ認証を開始できませんでした"))
                case .success(let result):
                    guard let raw = result["authUrl"] as? String,
                          let url = URL(string: raw), url.scheme == "https",
                          let host = url.host?.lowercased(),
                          ["chatgpt.com", "auth.openai.com", "login.openai.com", "accounts.openai.com", "openai.com"].contains(host) else {
                        self.isLoggingIn = false
                        self.state(AppL10n.text("Codexが有効な認証URLを返しませんでした"))
                        return
                    }
                    self.state(AppL10n.text("ブラウザでChatGPTログインを完了してください"))
                    DispatchQueue.main.async { [weak self] in self?.onOpenBrowser?(url) }
                }
            }
    }

    func logout() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.running else { self.state(AppL10n.text("Codex App Server未起動です。先に接続してください。")) ; return }
            self.request("account/logout") { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure: self.state(AppL10n.text("ログアウトに失敗しました"))
                case .success:
                    self.authenticated = false
                    self.snapshot(nil)
                    self.state(AppL10n.format("切断済み（%@）", self.profile.label))
                }
            }
        }
    }

    func stopAndWait() { queue.sync { stopInternal() } }

    private func stopInternal() {
        stopRequested = true
        isInitialized = false
        loginRequested = false
        authenticated = false
        isLoggingIn = false
        running = false
        let outstanding = pending
        pending.removeAll()
        for callback in outstanding.values { callback(.failure(ClientError.transportClosed)) }
        input?.closeFile()
        input = nil
        if let proc = process, proc.isRunning { proc.terminate() }
        process = nil
        buffer.removeAll()
    }
}
