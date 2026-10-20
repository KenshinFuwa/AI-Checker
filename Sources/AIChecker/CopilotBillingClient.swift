import Foundation
import Security
import AICheckerCore

/// Personal-account premium requests from GitHub's published billing endpoint.
/// Token remains solely in the user's login Keychain, never in UserDefaults or logs.
/// An organization-paid Copilot plan is not supported by the personal endpoint.
final class CopilotBillingClient: LiveProviderAdapter {
    let providerID = "copilot"
    static let accountKey = "AIChecker.v16.copilot.username"
    private static let keychainService = "dev.aichecker.localapp.github-copilot-billing"
    var onReport: ((CopilotPremiumUsage) -> Void)?
    var onFailure: ((ProviderFailure) -> Void)?
    var onState: ((String) -> Void)?
    private var task: URLSessionDataTask?
    private var lastRequest: Date?
    /// Explicit privacy boundary: old Keychain credentials never enable
    /// network requests automatically after an upgrade.
    var allowBillingRequests = false
    private var stopped = false
    private var generation = 0

    var username: String? {
        let value = UserDefaults.standard.string(forKey: Self.accountKey) ?? ""
        return CopilotBillingDecoder.validUser(value) ? value : nil
    }
    var configured: Bool { username != nil && Self.getSecret() != nil }

    func configure(username: String, token: String) -> Bool {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CopilotBillingDecoder.validUser(normalized), !secret.isEmpty else { return false }
        guard Self.putSecret(secret) else { return false }
        UserDefaults.standard.set(normalized, forKey: Self.accountKey)
        generation += 1
        lastRequest = nil
        stopped = false
        onState?("接続設定済み（GitHub使用量、まだ未検証）")
        return true
    }

    func disconnect() {
        stop()
        Self.deleteSecret()
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        lastRequest = nil
        stopped = false
        onState?("未接続")
    }

    func stop() {
        generation += 1
        stopped = true
        task?.cancel()
        task = nil
    }

    func resume() { if allowBillingRequests { stopped = false } }

    func requestUsage(force: Bool) {
        guard allowBillingRequests, !stopped, task == nil else { return }
        // GitHub's billing report is not a real-time 5h quota. Avoid 1440
        // unnecessary API calls per day even though our UI ticks every minute.
        if !force, let lastRequest = lastRequest,
           Date().timeIntervalSince(lastRequest) < 900 { return }
        guard let name = username, let secret = Self.getSecret() else {
            onState?("未接続（ユーザー名とトークンを登録してください）")
            return
        }
        let month = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: Date())
        guard let year = month.year, let number = month.month,
              let url = URL(string: "https://api.github.com/users/\(name)/settings/billing/premium_request/usage?year=\(year)&month=\(number)") else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("AI-Checker/1.6", forHTTPHeaderField: "User-Agent")
        lastRequest = Date()
        let attemptGeneration = generation
        onState?("GitHub使用量を取得中…")
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.stopped,
                      self.generation == attemptGeneration else { return }
                self.task = nil
                if let error = error as NSError? {
                    let failure: ProviderFailure = error.code == NSURLErrorTimedOut
                        ? .init(.timedOut) : .init(.networkUnavailable)
                    self.onFailure?(failure)
                    self.onState?(failure.displayMessage)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    self.onFailure?(.init(.invalidResponse))
                    return
                }
                guard response.statusCode == 200 else {
                    let seconds = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "")
                    // HTTP 403 is not always an expired token: it can mean
                    // missing Plan: Read, a non-personal billing plan, or rate limits.
                    // Only safe metadata is used; no response body or secret is logged.
                    let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
                    let failure = CopilotHTTPDiagnostic.failure(
                        status: response.statusCode,
                        rateLimitRemaining: remaining,
                        retryAfter: seconds)
                    self.onFailure?(failure)
                    self.onState?(CopilotHTTPDiagnostic.message(
                        status: response.statusCode,
                        rateLimitRemaining: remaining))
                    return
                }
                do {
                    let report = try CopilotBillingDecoder.decode(data ?? Data(), username: name,
                        year: year, month: number, observedAt: Date())
                    self.onReport?(report)
                    self.onState?("接続済み（当月の使用量を取得）")
                } catch {
                    let failure = ProviderFailure(.invalidResponse)
                    self.onFailure?(failure)
                    self.onState?("GitHub HTTP 200: 返された使用量データを解釈できません。")
                }
            }
        }
        task?.resume()
    }

    private static func getSecret() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: keychainService,
             kSecAttrAccount as String: "personal",
             kSecReturnData as String: true,
             kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let bytes = value as? Data else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    private static func putSecret(_ token: String) -> Bool {
        guard let bytes = token.data(using: .utf8) else { return false }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "personal"]
        let updateStatus = SecItemUpdate(query as CFDictionary,
            [kSecValueData as String: bytes] as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }
        var inserted = query
        inserted[kSecValueData as String] = bytes
        return SecItemAdd(inserted as CFDictionary, nil) == errSecSuccess
    }

    private static func deleteSecret() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "personal"]
        _ = SecItemDelete(query as CFDictionary)
    }
}
