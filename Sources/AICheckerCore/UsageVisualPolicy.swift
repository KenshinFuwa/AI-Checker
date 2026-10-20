import Foundation

/// Common presentation rules for all quota sources. Colors describe remaining
/// allowance, not provider identity. The displayed rounded number determines
/// its band, so "70%" can never be drawn using the 69% color.
public enum RemainingQuotaBand: String, Equatable, Sendable {
    case lime, orange, yellow, red

    public static func forRemaining(_ percentage: Double?) -> RemainingQuotaBand? {
        guard let percentage = percentage, percentage.isFinite,
              (0...100).contains(percentage) else { return nil }
        let displayed = Int(percentage.rounded())
        if displayed >= 70 { return .lime }
        if displayed >= 40 { return .orange }
        if displayed >= 20 { return .yellow }
        return .red
    }
}

/// English reset countdown, rounded *up* to the nearest minute. No device
/// clock/date parsing or network calls; callers inject time for deterministic tests.
public enum ResetCountdown {
    public static func format(until deadline: Date?, now: Date = Date(),
                              fresh: Bool = true) -> String {
        guard fresh else { return "Awaiting update" }
        guard let deadline = deadline else { return "Unknown" }
        let seconds = deadline.timeIntervalSince(now)
        guard seconds.isFinite else { return "Unknown" }
        guard seconds > 0 else { return "Awaiting update" }
        let total = Int(ceil(seconds / 60))
        let days = total / 1440
        let hours = total % 1440 / 60
        let minutes = total % 60
        var components: [String] = []
        if days > 0 { components.append(unit(days, "day")) }
        if hours > 0 { components.append(unit(hours, "hour")) }
        if minutes > 0 || components.isEmpty { components.append(unit(minutes, "minute")) }
        return components.joined(separator: " ")
    }

    private static func unit(_ number: Int, _ singular: String) -> String {
        "\(number) \(singular)\(number == 1 ? "" : "s")"
    }
}
