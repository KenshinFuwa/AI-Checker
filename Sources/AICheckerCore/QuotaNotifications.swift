import Foundation

/// Notification preferences are opt-in, separately from display settings.
/// Only *observed* quota transitions trigger notifications: a countdown
/// reaching zero is never evidence by itself that the server reset the quota.
public struct QuotaNotificationPreferences: Codable, Equatable, Sendable {
    public var notifyOnReset: Bool
    public var notifyOnExhaustion: Bool

    public init(notifyOnReset: Bool = false, notifyOnExhaustion: Bool = false) {
        self.notifyOnReset = notifyOnReset
        self.notifyOnExhaustion = notifyOnExhaustion
    }
}

public enum QuotaNotificationWindow: String, Codable, Sendable {
    case fiveHours
    case week

    public var label: String {
        switch self {
        case .fiveHours: return "5時間"
        case .week: return "週間"
        }
    }

    /// Filter corrections to a reset ETA from actual transitions into the next epoch.
    var minimumEpochAdvance: TimeInterval {
        switch self {
        case .fiveHours: return 30 * 60
        case .week: return 24 * 60 * 60
        }
    }
}

public enum QuotaNotificationKind: String, Codable, Sendable {
    case reset
    case exhausted
}

public struct QuotaNotificationEvent: Equatable, Sendable {
    public let providerID: String
    public let window: QuotaNotificationWindow
    public let kind: QuotaNotificationKind
    public let remainingPercent: Double

    public init(providerID: String, window: QuotaNotificationWindow,
                kind: QuotaNotificationKind, remainingPercent: Double) {
        self.providerID = providerID
        self.window = window
        self.kind = kind
        self.remainingPercent = remainingPercent
    }
}

/// Only sanitized numbers, reset dates, and account IDs are stored here.
/// No tokens, browser sessions, personal content, or provider secrets.
public struct QuotaNotificationMonitor: Codable, Sendable {
    public struct Observation: Codable, Sendable {
        public var remainingPercent: Double
        public var resetsAt: Date?
        public var observedAt: Date
    }

    private var observations: [String: Observation] = [:]
    private static let exhaustedBoundary = 0.5  // visually displayed as 0%

    public init() {}

    /// Always establish/update a baseline, even if both alerts are disabled.
    /// Consequently enabling alerts does not announce an old exhausted quota.
    /// Only fresh, newer server observations count; periodic redraws do not.
    public mutating func ingest(accountID: UUID, snapshot: AIQuotaSnapshot,
                                settings: QuotaNotificationPreferences,
                                now: Date = Date()) -> [QuotaNotificationEvent] {
        guard TelemetryFreshness.isRecent(snapshot, now: now),
              let observedAt = snapshot.updatedAt,
              (snapshot.providerID == "codex" || snapshot.providerID == "claude") else { return [] }

        var events: [QuotaNotificationEvent] = []
        let windows: [(QuotaNotificationWindow, QuotaWindow)] = [
            (.fiveHours, snapshot.fiveHour), (.week, snapshot.weekly)
        ]
        for (window, quota) in windows {
            guard let remaining = quota.remainingPercent, remaining.isFinite,
                  (0...100).contains(remaining) else { continue }
            let key = "\(snapshot.providerID):\(accountID.uuidString):\(window.rawValue)"
            let new = Observation(remainingPercent: remaining, resetsAt: quota.resetsAt,
                                  observedAt: observedAt)
            if let old = observations[key] {
                // Equal/replayed or out-of-order samples are not new events.
                guard observedAt > old.observedAt else { continue }
                let elapsed = observedAt.timeIntervalSince(old.observedAt)
                // After very long telemetry gaps, begin a new baseline.
                if elapsed <= 15 * 24 * 3600 {
                    let resetConfirmed: Bool = {
                        guard let before = old.resetsAt, let after = quota.resetsAt else { return false }
                        // Old reset must have actually become due. Merely revising
                        // the reset estimate into the future is not a reset.
                        guard before <= observedAt.addingTimeInterval(60),
                              before >= old.observedAt.addingTimeInterval(-60),
                              after.timeIntervalSince(before) >= window.minimumEpochAdvance else { return false }
                        return true
                    }()
                    if resetConfirmed {
                        if settings.notifyOnReset {
                            events.append(.init(providerID: snapshot.providerID, window: window,
                                                kind: .reset, remainingPercent: remaining))
                        }
                    } else {
                        let sameEpoch: Bool = {
                            switch (old.resetsAt, quota.resetsAt) {
                            case (nil, nil): return true
                            case let (a?, b?): return abs(a.timeIntervalSince(b)) <= 120
                            default: return false
                            }
                        }()
                        if sameEpoch && old.remainingPercent > Self.exhaustedBoundary &&
                            remaining <= Self.exhaustedBoundary && settings.notifyOnExhaustion {
                            events.append(.init(providerID: snapshot.providerID, window: window,
                                                kind: .exhausted, remainingPercent: remaining))
                        }
                    }
                }
            }
            observations[key] = new
        }
        // Prevent indefinite state growth across account additions/removals.
        if observations.count > 120 {
            let ordered = observations.sorted { $0.value.observedAt > $1.value.observedAt }
            observations = Dictionary(uniqueKeysWithValues: ordered.prefix(80).map { ($0.key, $0.value) })
        }
        return events
    }
}
