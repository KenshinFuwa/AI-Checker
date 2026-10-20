import Foundation

/// Personal GitHub Copilot *billed premium requests*, not a percentage of a
/// plan allowance and not ChatGPT/Codex's five-hour or weekly quota.
public struct CopilotPremiumUsage: Equatable, Sendable {
    public let username: String
    public let year: Int
    public let month: Int
    public let grossRequests: Double
    public let observedAt: Date

    public init(username: String, year: Int, month: Int,
                grossRequests: Double, observedAt: Date) {
        self.username = username
        self.year = year
        self.month = month
        self.grossRequests = grossRequests
        self.observedAt = observedAt
    }
}

public enum CopilotBillingError: Error, Equatable {
    case invalidAccount, malformedResponse, invalidQuantity
}

public enum CopilotBillingDecoder {
    /// Only GitHub handles may enter the API URL path. We do not support
    /// organization data in this personal-account adapter.
    public static func validUser(_ username: String) -> Bool {
        let s = Array(username.utf8)
        guard !s.isEmpty, s.count <= 39, s.first != 45, s.last != 45 else { return false }
        return s.allSatisfy { ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) ||
            ($0 >= 48 && $0 <= 57) || $0 == 45 }
    }

    /// Avoid accidental ingestion of unrelated API billables or fees.
    /// Missing usageItems is an error, while a valid empty list means zero
    /// billed premium requests in the explicitly queried month.
    public static func decode(_ data: Data, username: String, year: Int, month: Int,
                              observedAt: Date) throws -> CopilotPremiumUsage {
        guard validUser(username) else { throw CopilotBillingError.invalidAccount }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["usageItems"] as? [[String: Any]] else {
            throw CopilotBillingError.malformedResponse
        }
        var gross = 0.0
        for item in items {
            guard (item["product"] as? String)?.lowercased() == "copilot",
                  (item["sku"] as? String)?.lowercased() == "copilot premium request",
                  (item["unitType"] as? String)?.lowercased() == "requests" else { continue }
            guard let quantity = item["grossQuantity"] as? NSNumber,
                  quantity.doubleValue.isFinite, quantity.doubleValue >= 0 else {
                throw CopilotBillingError.invalidQuantity
            }
            gross += quantity.doubleValue
            guard gross.isFinite else { throw CopilotBillingError.invalidQuantity }
        }
        return CopilotPremiumUsage(username: username, year: year, month: month,
                                   grossRequests: gross, observedAt: observedAt)
    }
}


/// Non-sensitive summaries of GitHub API outcomes.
/// Never expose authorization headers, token contents or GitHub response bodies.
public enum CopilotHTTPDiagnostic {
    public static func failure(status: Int, rateLimitRemaining: String?, retryAfter: TimeInterval?) -> ProviderFailure {
        let exhausted = rateLimitRemaining?.trimmingCharacters(in: .whitespacesAndNewlines) == "0"
        if (status == 403 && exhausted) || status == 429 {
            return .init(.rateLimited, retryAfter: retryAfter)
        }
        return ProviderFailure.http(status, retryAfter: retryAfter)
    }

    public static func message(status: Int, rateLimitRemaining: String?) -> String {
        let exhausted = rateLimitRemaining?.trimmingCharacters(in: .whitespacesAndNewlines) == "0"
        switch status {
        case 401:
            return "GitHub HTTP 401: トークンが無効か失効しています"
        case 403 where exhausted:
            return "GitHub HTTP 403: API呼び出し制限中（自動再試行）"
        case 403:
            return "GitHub HTTP 403: 権限不足／個人請求の対象外の可能性"
        case 404:
            return "GitHub HTTP 404: 個人向け請求情報が見つかりません"
        case 429:
            return "GitHub HTTP 429: 取得制限中（自動再試行）"
        case 400:
            return "GitHub HTTP 400: APIリクエストが無効です"
        case 500...599:
            return "GitHub HTTP \(status): GitHub側の一時エラー。後で再試行します。"
        default:
            return "GitHub HTTP \(status): 使用量の取得に失敗しました。"
        }
    }
}
