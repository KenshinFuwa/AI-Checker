import Foundation

public enum QuotaProvider: String, CaseIterable, Codable, Sendable {
    case codex, claude
}

public struct QuotaWindow: Equatable, Sendable {
    public let remainingPercent: Double?
    public let resetsAt: Date?

    public init(remainingPercent: Double?, resetsAt: Date?) {
        guard let value = remainingPercent, value.isFinite, (0...100).contains(value) else {
            self.remainingPercent = nil
            self.resetsAt = resetsAt
            return
        }
        self.remainingPercent = value
        self.resetsAt = resetsAt
    }
}

public struct ProviderSnapshot: Equatable, Sendable {
    public let provider: QuotaProvider
    public let fiveHour: QuotaWindow
    public let weekly: QuotaWindow
    public let updatedAt: Date?
    public let source: String?

    public init(provider: QuotaProvider, fiveHour: QuotaWindow, weekly: QuotaWindow, updatedAt: Date?, source: String?) {
        self.provider = provider
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.updatedAt = updatedAt
        self.source = source
    }
}
