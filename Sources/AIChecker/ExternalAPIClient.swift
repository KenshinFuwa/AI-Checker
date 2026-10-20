import Foundation
import Security
import AICheckerCore

/// No redirected admin credentials may be forwarded to another host.
private final class NoAPIRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Official, opt-in, read-only API billing / team analytics clients.
/// Credentials never go in UserDefaults, requests are made only to fixed hostnames.
final class ExternalAPIClient {
    let kind: ExternalAPIKind
    var onState: ((String) -> Void)?
    var onReport: ((ExternalAPIReport) -> Void)?
    var onFailure: ((ProviderFailure) -> Void)?
    private let redirectDelegate = NoAPIRedirectDelegate()
    private lazy var apiSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config, delegate: redirectDelegate, delegateQueue: nil)
    }()
    private var task: URLSessionDataTask?
    private var generation = 0
    private var stopped = false
    private var lastRequest: Date?
    private let defaults = UserDefaults.standard
    private var service: String { "dev.aichecker.localapp.external-" + kind.rawValue }
    private var enabledKey: String { "AIChecker.external.v1.enabled." + kind.rawValue }
    private var teamIDKey: String { "AIChecker.external.v1.team." + kind.rawValue }
    var enabled: Bool { defaults.bool(forKey: enabledKey) }
    var teamID: String? { defaults.string(forKey: teamIDKey) }
    var configured: Bool { enabled && (!kind.requiresTeamID || (teamID.map(ExternalAPIUsage.validTeamID) ?? false)) }

    init(kind: ExternalAPIKind) { self.kind = kind }

    func configure(secret: String, teamID: String?) -> Bool {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 8192,
              !trimmed.contains("\n"), !trimmed.contains("\r"),
              (!kind.requiresTeamID || ExternalAPIUsage.validTeamID(teamID ?? "")) else { return false }
        stop()
        guard storeKey(trimmed) else { return false }
        if kind.requiresTeamID { defaults.set(teamID!, forKey: teamIDKey) }
        defaults.set(true, forKey: enabledKey) // opt-in after successful Keychain write
        stopped = false
        lastRequest = nil
        onState?("保存済み・未取得")
        return true
    }

    func disconnect() {
        stop()
        deleteKey()
        defaults.removeObject(forKey: enabledKey)
        defaults.removeObject(forKey: teamIDKey)
        lastRequest = nil
        onState?("未接続")
    }
    func stop() { generation += 1; stopped = true; task?.cancel(); task = nil }
    func resume() { if enabled { stopped = false } }

    func shouldPoll(now: Date, force: Bool) -> Bool {
        guard configured && !stopped && task == nil else { return false }
        return force || lastRequest.map { now.timeIntervalSince($0) >= 900 } ?? true
    }

    func requestUsage(force: Bool) {
        guard !stopped, configured, task == nil else { return }
        // Dashboard billing/usage is slow-changing; never poll once per UI tick.
        if !force, let lastRequest = lastRequest,
           Date().timeIntervalSince(lastRequest) < 900 { return }
        guard let secret = readKey(), let request = buildRequest(secret: secret, now: Date()) else {
            onState?("接続情報不足（Keychainを確認）")
            onFailure?(.init(.authenticationRequired))
            return
        }
        let attempt = generation
        lastRequest = Date()
        onState?("公式APIから取得中…")
        task = apiSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.stopped, self.generation == attempt else { return }
                self.task = nil
                if let error = error as NSError? {
                    let failure: ProviderFailure = error.code == NSURLErrorTimedOut
                        ? .init(.timedOut) : .init(.networkUnavailable)
                    self.onFailure?(failure)
                    self.onState?(failure.displayMessage)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    self.onFailure?(.init(.invalidResponse)); self.onState?("HTTP応答が不正です")
                    return
                }
                guard http.statusCode == 200 else {
                    let retry = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "")
                    let failure = ProviderFailure.http(http.statusCode, retryAfter: retry)
                    self.onFailure?(failure)
                    self.onState?("HTTP \(http.statusCode): \(failure.displayMessage)")
                    return
                }
                do {
                    let now = Date()
                    let result = try ExternalAPIUsage.decode(data ?? Data(), kind: self.kind,
                         observedAt: now, periodStart: ExternalAPIUsage.startOfUTCMonth(now))
                    self.onReport?(result)
                    self.onState?("接続済み・当月レポート取得")
                } catch {
                    self.onFailure?(.init(.invalidResponse))
                    self.onState?("公式APIのレスポンスが不完全・未対応の形式です")
                }
            }
        }
        task?.resume()
    }

    private func buildRequest(secret: String, now: Date) -> URLRequest? {
        let start = ExternalAPIUsage.startOfUTCMonth(now)
        let endpoint: String
        switch kind {
        case .openaiAPI:
            endpoint = "https://api.openai.com/v1/organization/costs?start_time=\(Int(start.timeIntervalSince1970))&end_time=\(Int(now.timeIntervalSince1970))&limit=31"
        case .cursorTeam:
            endpoint = "https://api.cursor.com/teams/daily-usage-data"
        case .xaiAPI:
            guard let teamID = teamID, ExternalAPIUsage.validTeamID(teamID) else { return nil }
            endpoint = "https://management-api.x.ai/v1/billing/teams/\(teamID)/usage"
        }
        guard let url = URL(string: endpoint) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = kind == .openaiAPI ? "GET" : "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AI-Checker/1.9.2", forHTTPHeaderField: "User-Agent")
        switch kind {
        case .openaiAPI:
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        case .cursorTeam:
            guard let raw = (secret + ":").data(using: .utf8) else { return nil }
            request.setValue("Basic \(raw.base64EncodedString())", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Int64] = ["startDate": Int64(start.timeIntervalSince1970 * 1000),
                                             "endDate": Int64(now.timeIntervalSince1970 * 1000)]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        case .xaiAPI:
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let payload: [String: Any] = ["analyticsRequest": [
                "timeRange": ["startTime": formatter.string(from: start),
                               "endTime": formatter.string(from: now), "timezone": "Etc/GMT"],
                "timeUnit": "TIME_UNIT_DAY",
                "values": [["name": "usd", "aggregation": "AGGREGATION_SUM"]],
                "groupBy": ["description"], "filters": []
            ]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        }
        return request
    }

    private func readKey() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "readonly",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var found: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func storeKey(_ key: String) -> Bool {
        guard let bytes = key.data(using: .utf8) else { return false }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "readonly"]
        let status = SecItemUpdate(query as CFDictionary,
                                    [kSecValueData as String: bytes] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var fields = query
        fields[kSecValueData as String] = bytes
        return SecItemAdd(fields as CFDictionary, nil) == errSecSuccess
    }
    private func deleteKey() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "readonly"]
        _ = SecItemDelete(query as CFDictionary)
    }
}
