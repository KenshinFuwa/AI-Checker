import Foundation

/// A small, UI-independent policy for the status-bar bitmap. The backend can
/// refresh every minute while an unchanged bitmap is not regenerated.
public enum RefreshPolicy {
    public static let interval: TimeInterval = 60
    public static let timerTolerance: TimeInterval = 5

    public struct VisibleValue: Equatable, Sendable {
        public let providerID: String
        public let fiveHour: Double?
        public let weekly: Double?

        public init(providerID: String, fiveHour: Double?, weekly: Double?) {
            self.providerID = providerID
            self.fiveHour = fiveHour
            self.weekly = weekly
        }
    }

    public struct DisplayKey: Equatable, Sendable {
        public let values: [VisibleValue]
        public let stale: Bool
        public let demo: Bool

        public init(snapshots: [String: AIQuotaSnapshot],
                    visibleProviders: [AIProviderDescriptor], stale: Bool, demo: Bool) {
            self.values = visibleProviders.map { provider in
                let item = snapshots[provider.id]
                return VisibleValue(providerID: provider.id,
                                    fiveHour: item?.fiveHour.remainingPercent,
                                    weekly: item?.weekly.remainingPercent)
            }
            self.stale = stale
            self.demo = demo
        }
    }
}
