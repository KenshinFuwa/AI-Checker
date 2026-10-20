import Foundation

/// Official first-party destination for manual inspection. This catalog is NOT a
/// consumer-quota API and opening a site never establishes quota connectivity.
public struct ConsumerWebDestination: Equatable, Sendable {
    public let id: String
    public let name: String
    public let urlString: String
    public let instructions: String

    public init(id: String, name: String, urlString: String, instructions: String) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.instructions = instructions
    }

    public var menuHint: String {
        switch id {
        case "chatgpt": return "モデルメニュー・設定から確認"
        case "gemini": return "設定 → Usage limits（5時間・週）"
        case "perplexity": return "プロフィール・プランから確認"
        case "cursor": return "Dashboard → Usage"
        case "grok": return "Dashboard → 使用量・契約"
        default: return "公式サイトから確認"
        }
    }

    public var url: URL? {
        guard let url = URL(string: urlString), url.scheme == "https",
              let host = url.host, !host.isEmpty, url.user == nil,
              url.password == nil else { return nil }
        return url
    }
}

public enum ConsumerWebAccess {
    public static let destinations: [ConsumerWebDestination] = [
        .init(id: "chatgpt", name: "ChatGPT", urlString: "https://chatgpt.com/",
              instructions: "モデルメニューや設定に表示される利用上限・リセット時刻を確認してください。Codexとは別枠です。"),
        .init(id: "gemini", name: "Gemini", urlString: "https://gemini.google.com/",
              instructions: "設定 → Usage limits（使用量）から5時間／週の利用制限を確認してください。"),
        .init(id: "perplexity", name: "Perplexity", urlString: "https://www.perplexity.ai/",
              instructions: "プロフィール・プランの利用状況を確認してください。使用可能な指標は契約によって異なります。"),
        .init(id: "cursor", name: "Cursor", urlString: "https://cursor.com/dashboard",
              instructions: "Dashboard → Usage で個人向け使用量を確認してください。Team Admin APIとは別です。"),
        .init(id: "grok", name: "Grok", urlString: "https://grok.com/dashboard",
              instructions: "Dashboardの契約・使用量を確認してください。xAI APIの請求額とは別です。")
    ]

    public static func destination(for id: String) -> ConsumerWebDestination? {
        destinations.first { $0.id == id }
    }
}

/// User-transcribed note only. Not a verified source and never fed into the
/// automated percent bars or remaining-quota calculations.
public struct ConsumerUsageNote: Codable, Equatable, Sendable {
    public let providerID: String
    public let text: String
    public let recordedAt: Date

    public init?(providerID: String, text: String, recordedAt: Date) {
        guard ConsumerWebAccess.destination(for: providerID) != nil,
              recordedAt.timeIntervalSince1970.isFinite else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 120,
              !trimmed.contains("\n"), !trimmed.contains("\r") else { return nil }
        let lower = trimmed.lowercased()
        // Fail closed on obvious secrets; UI also expressly forbids them.
        guard !["bearer ", "password", "cookie=", "session_key", "sk-", "ghp_", "ghu_"].contains(where: lower.contains) else { return nil }
        self.providerID = providerID
        self.text = trimmed
        self.recordedAt = recordedAt
    }

    /// Notes are shown only as user observations, never as live quotas.
    public func isRecent(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(recordedAt) >= 0 && date.timeIntervalSince(recordedAt) <= 3600
    }
}
