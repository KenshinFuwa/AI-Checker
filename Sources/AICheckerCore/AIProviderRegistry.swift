import Foundation

/// Descriptors contain no account secrets. A new provider needs a descriptor and
/// a source adapter; the status-bar renderer does not require another special case.
public struct AIProviderDescriptor: Equatable, Sendable {
    public let id: String
    public let name: String
    public let shortName: String
    public let sourceID: String

    public init(id: String, name: String, shortName: String, sourceID: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.sourceID = sourceID
    }
}

/// A provider only becomes displayable after its *specific* meter has a real
/// authorized source. A developer API credit is not a consumer-chat quota.
public enum ProviderUsageCapability: String, Codable, Equatable, Sendable {
    case fiveHourAndWeekly
    case billedMonthlyRequests
    case apiUsageReport
    case notAvailable
}

public struct ProviderMeter: Equatable, Sendable {
    public let providerID: String
    public let label: String
    public let used: Double
    public let limit: Double?
    public let unit: String

    public init?(providerID: String, label: String, used: Double,
                 limit: Double?, unit: String) {
        guard !providerID.isEmpty, !label.isEmpty, !unit.isEmpty,
              used.isFinite, used >= 0 else { return nil }
        if let limit = limit, (!limit.isFinite || limit <= 0) { return nil }
        self.providerID = providerID
        self.label = label
        self.used = used
        self.limit = limit
        self.unit = unit
    }

    public var remainingPercent: Double? {
        guard let limit = limit else { return nil }
        return max(0, min(100, (1 - used / limit) * 100))
    }
}

public enum AIProviderRegistry {
    public static let builtins: [AIProviderDescriptor] = [
        AIProviderDescriptor(id: "codex", name: "Codex", shortName: "Co", sourceID: "official-codex-app-server"),
        AIProviderDescriptor(id: "claude", name: "Claude", shortName: "Cl", sourceID: "claude-first-party-statusline")
    ]

    /// Catalog-only entries do not have an authorized quota reader. They are
    /// NEVER silently polled or enabled as a replacement for an API meter.
    public static let planned: [AIProviderDescriptor] = [
        .init(id: "chatgpt", name: "ChatGPT", shortName: "GPT", sourceID: "not-available-chat-consumer-quota"),
        .init(id: "gemini", name: "Gemini", shortName: "Ge", sourceID: "not-connected"),
        .init(id: "perplexity", name: "Perplexity", shortName: "Px", sourceID: "not-connected"),
        .init(id: "cursor", name: "Cursor", shortName: "Cu", sourceID: "team-admin-usage-report-only"),
        .init(id: "copilot", name: "GitHub Copilot", shortName: "GH", sourceID: "opt-in-personally-billed-github-usage-only"),
        .init(id: "grok", name: "Grok", shortName: "Gr", sourceID: "xai-management-api-billing-only"),
        .init(id: "openai-api", name: "OpenAI API", shortName: "OA", sourceID: "organization-admin-costs-only")
    ]
    /// Copilot is a real API usage report, *not* a 5h/weekly quota source.
    public static func supportsUsageReport(_ id: String) -> Bool {
        id == "copilot" || supportsExternalAPIReport(id)
    }
    public static func supportsExternalAPIReport(_ id: String) -> Bool {
        ["cursor", "grok", "openai-api"].contains(id)
    }
    public static func capability(for id: String) -> ProviderUsageCapability {
        if isImplemented(id) { return .fiveHourAndWeekly }
        if id == "copilot" { return .billedMonthlyRequests }
        if supportsExternalAPIReport(id) { return .apiUsageReport }
        return .notAvailable
    }
    public static var catalog: [AIProviderDescriptor] { ordered(builtins + planned) }
    public static func isImplemented(_ id: String) -> Bool { builtins.contains(where: { $0.id == id }) }

    public static func ordered(_ descriptors: [AIProviderDescriptor]) -> [AIProviderDescriptor] {
        var seen = Set<String>()
        return descriptors.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
    }
}

/// Provider-independent view model for future source adapters.
public struct AIQuotaSnapshot: Equatable, Sendable {
    public let providerID: String
    public let fiveHour: QuotaWindow
    public let weekly: QuotaWindow
    public let updatedAt: Date?
    public let source: String?

    public init(providerID: String, fiveHour: QuotaWindow, weekly: QuotaWindow,
                updatedAt: Date?, source: String?) {
        self.providerID = providerID
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.updatedAt = updatedAt
        self.source = source
    }

    public init(from legacy: ProviderSnapshot) {
        self.init(providerID: legacy.provider.rawValue, fiveHour: legacy.fiveHour,
                  weekly: legacy.weekly, updatedAt: legacy.updatedAt, source: legacy.source)
    }
}

public enum ProviderMerge {
    /// Never substitute synthetic zero values; latest valid record wins by provider ID.
    public static func merge(_ batches: [[String: AIQuotaSnapshot]]) -> [String: AIQuotaSnapshot] {
        var result: [String: AIQuotaSnapshot] = [:]
        for batch in batches { for (key, value) in batch where !key.isEmpty && key == value.providerID {
            result[key] = value
        }}
        return result
    }
}
