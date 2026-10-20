import Foundation

/// Parser for an OPTIONAL, undocumented Claude website usage response.
/// Neither this parser nor AI Checker stores session cookies, OAuth tokens, or raw JSON.
/// This is not an official third-party API. Missing windows remain unavailable.
public enum ClaudeWebUsage {
    private static func date(_ raw: Any?) -> Date? {
        guard let text = raw as? String else { return nil }
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = format.date(from: text) { return parsed }
        format.formatOptions = [.withInternetDateTime]
        return format.date(from: text)
    }

    private static func window(_ raw: Any?, now: Date) -> QuotaWindow {
        guard let dictionary = raw as? [String: Any],
              let number = dictionary["utilization"] as? NSNumber else {
            return QuotaWindow(remainingPercent: nil, resetsAt: nil)
        }
        let used = number.doubleValue
        let reset = date(dictionary["resets_at"])
        guard used.isFinite, used >= 0, used <= 1000,
              reset == nil || reset! > now else {
            return QuotaWindow(remainingPercent: nil, resetsAt: reset)
        }
        return QuotaWindow(remainingPercent: max(0, 100 - used), resetsAt: reset)
    }

    public static func decode(_ json: Data, now: Date = Date()) -> AIQuotaSnapshot? {
        guard json.count <= 65536,
              let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return nil }
        let five = window(root["five_hour"], now: now)
        let weekly = window(root["seven_day"], now: now)
        guard five.remainingPercent != nil || weekly.remainingPercent != nil else { return nil }
        return AIQuotaSnapshot(providerID: "claude", fiveHour: five, weekly: weekly,
                               updatedAt: now, source: "Claude Web (experimental / unofficial)")
    }
}
