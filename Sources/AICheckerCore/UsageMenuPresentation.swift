import Foundation

/// Menu presentation policy: every provider gets an independent full-width
/// vertical row. Never squeeze two providers into side-by-side columns.
public enum UsageMenuPresentation {
    public static let providerCardWidth = 580.0
    public static let providerCardHeight = 120.0

    // Native menu geometry in points: one provider per full-width row.
    // Keep the proven 215pt quota meter; time is in a separate right column.
    public static let meterWidth = 215.0
    public static let labelX = 36.0
    public static let meterX = 136.0
    public static let percentX = 362.0
    public static let durationMinX = 409.0
    public static let durationRightX = 565.0
    // All header elements use one visual centerline, rather than independent
    // text baselines and image origins (which differ by font and artwork).
    public static let headerCenterY = 90.0
    public static let headerIconX = 26.0
    public static let headerIconSize = 25.0
    public static let headerTitleX = 62.0
    public static let dividerY = 73.0

    // The top label and every countdown share the same right-hand guide.
    // As these are durations, right alignment prevents a moving ragged edge.
    public static let resetCaptionRightX = durationRightX
    public static let fiveHourRowCenterY = 52.0
    public static let weekRowCenterY = 22.0

    public static let rowLabels = ["5 hours", "Week"]
    public static let resetCaption = "RESETS IN"

    public static func percentage(_ value: Double?) -> String {
        guard let value = value, value.isFinite, (0...100).contains(value) else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    public static func fillFraction(_ value: Double?) -> Double {
        guard let value = value, value.isFinite else { return 0 }
        return min(1, max(0, value / 100))
    }

    public static func stateLabel(hasSnapshot: Bool, hasFailure: Bool, isFresh: Bool) -> String {
        if hasFailure { return "要確認" }
        if !hasSnapshot { return "未取得" }
        return isFresh ? "更新済み" : "古い記録"
    }
}
