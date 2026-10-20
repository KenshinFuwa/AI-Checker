import Foundation

/// Parses provider-supplied usage telemetry. No cookies, passwords, OAuth tokens,
/// browser databases, or third-party command-line tools are involved.
public enum NativeQuotaDecoder {
    private static func object(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let result = number.doubleValue
        return result.isFinite ? result : nil
    }

    private static func date(_ value: Any?) -> Date? {
        if let seconds = number(value), seconds > 0 { return Date(timeIntervalSince1970: seconds) }
        guard let text = value as? String else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let result = parser.date(from: text) { return result }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: text)
    }

    private static func codexWindow(_ raw: [String: Any]?, expectedMinutes: Double,
                                    observedAt: Date, now: Date) -> QuotaWindow {
        // Codex has reported minute-rounded durations (e.g. 299 and 10079).
        // Do not infer a window from primary/secondary position alone.
        guard let raw = raw, let minutes = number(raw["window_minutes"]),
              abs(minutes - expectedMinutes) <= 2 else {
            return QuotaWindow(remainingPercent: nil, resetsAt: nil)
        }
        let reset = date(raw["resets_at"]) ?? {
            guard let seconds = number(raw["resets_in_seconds"]), seconds >= 0 else { return nil }
            return observedAt.addingTimeInterval(seconds)
        }()
        let value = number(raw["used_percent"])
        // Without a reset time, the event cannot validate a whole window forever.
        let noResetStale = reset == nil && now.timeIntervalSince(observedAt) > minutes * 60
        guard let value = value, (0...100).contains(value), !noResetStale,
              reset == nil || reset! > now else {
            return QuotaWindow(remainingPercent: nil, resetsAt: reset)
        }
        return QuotaWindow(remainingPercent: 100 - value, resetsAt: reset)
    }

    private static func window(_ dictionary: [String: Any]?, percentKey: String,
                               resetKey: String, now: Date) -> QuotaWindow {
        let reset = date(dictionary?[resetKey])
        guard let used = number(dictionary?[percentKey]), (0...100).contains(used),
              reset == nil || reset! > now else {
            return QuotaWindow(remainingPercent: nil, resetsAt: reset)
        }
        return QuotaWindow(remainingPercent: 100 - used, resetsAt: reset)
    }

    /// Codex writes `event_msg / token_count / rate_limits` records into its own
    /// rollout JSONL logs. These are observations from Codex's last interaction;
    /// reading them does NOT obtain a fresh server-side quota snapshot.
    public static func codexRolloutEvent(_ line: Data, now: Date = Date()) -> AIQuotaSnapshot? {
        guard let root = object(line), root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        if let id = limits["limit_id"] as? String, id != "codex" { return nil }
        guard let timestamp = date(root["timestamp"]), timestamp <= now.addingTimeInterval(60) else { return nil }
        let rawWindows = [limits["primary"], limits["secondary"]].compactMap { $0 as? [String: Any] }
        func matching(_ expected: Double) -> [String: Any]? {
            rawWindows.first {
                guard let minutes = number($0["window_minutes"]) else { return false }
                return abs(minutes - expected) <= 2
            }
        }
        let five = codexWindow(matching(300), expectedMinutes: 300, observedAt: timestamp, now: now)
        let week = codexWindow(matching(10080), expectedMinutes: 10080, observedAt: timestamp, now: now)
        guard five.remainingPercent != nil || week.remainingPercent != nil else { return nil }
        return AIQuotaSnapshot(providerID: "codex", fiveHour: five, weekly: week,
                               updatedAt: timestamp, source: "Codex local session (read only)")
    }

    /// Claude Code's DOCUMENTED statusLine JSON (when a first-party session
    /// supplies its optional rate_limits fields). No use of subscription OAuth.
    public static func claudeStatusLine(_ data: Data, now: Date = Date()) -> AIQuotaSnapshot? {
        guard let root = object(data), let limits = root["rate_limits"] as? [String: Any] else { return nil }
        let five = window(limits["five_hour"] as? [String: Any], percentKey: "used_percentage",
                          resetKey: "resets_at", now: now)
        let week = window(limits["seven_day"] as? [String: Any], percentKey: "used_percentage",
                          resetKey: "resets_at", now: now)
        guard five.remainingPercent != nil || week.remainingPercent != nil else { return nil }
        return AIQuotaSnapshot(providerID: "claude", fiveHour: five, weekly: week,
                               updatedAt: now, source: "Claude Code statusLine (first-party)")
    }
}

/// Disk format contains ONLY quota measurements; never store original statusLine
/// JSON because it may contain private prompts, file paths and session IDs.
public struct SanitizedClaudeQuota: Codable, Equatable {
    public let schema: Int
    public let capturedAt: Double
    public let fiveHourRemaining: Double?
    public let weeklyRemaining: Double?
    public let fiveHourReset: Double?
    public let weeklyReset: Double?

    public init(_ snapshot: AIQuotaSnapshot) {
        schema = 1
        capturedAt = snapshot.updatedAt?.timeIntervalSince1970 ?? 0
        fiveHourRemaining = snapshot.fiveHour.remainingPercent
        weeklyRemaining = snapshot.weekly.remainingPercent
        fiveHourReset = snapshot.fiveHour.resetsAt?.timeIntervalSince1970
        weeklyReset = snapshot.weekly.resetsAt?.timeIntervalSince1970
    }

    public func snapshot(now: Date = Date()) -> AIQuotaSnapshot? {
        guard schema == 1, capturedAt > 0, capturedAt <= now.timeIntervalSince1970 + 60,
              now.timeIntervalSince1970 - capturedAt < 7 * 24 * 3600 else { return nil }
        func normalized(_ remaining: Double?, _ reset: Double?) -> QuotaWindow {
            let date = reset.map { Date(timeIntervalSince1970: $0) }
            let pct = date == nil || date! > now ? remaining : nil
            return QuotaWindow(remainingPercent: pct, resetsAt: date)
        }
        let five = normalized(fiveHourRemaining, fiveHourReset)
        let week = normalized(weeklyRemaining, weeklyReset)
        guard five.remainingPercent != nil || week.remainingPercent != nil else { return nil }
        return AIQuotaSnapshot(providerID: "claude", fiveHour: five, weekly: week,
                               updatedAt: Date(timeIntervalSince1970: capturedAt), source: "Claude Code statusLine (first-party)")
    }
}
