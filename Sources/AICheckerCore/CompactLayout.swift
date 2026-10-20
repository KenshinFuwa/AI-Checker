import Foundation

/// Pure spacing contract tested without AppKit. Text widths are measured with
/// native fonts at render time; the bitmap has no built-in left padding.
public enum CompactLayout {
    public static let imageLeftPadding: Double = 0
    public static let imageRightPadding: Double = 0
    public static let labelToCadence: Double = 2
    public static let cadenceToBar: Double = 2
    public static let barToPercent: Double = 2
    public static let maxPercentLabel = "100%"
    public static let providerGap: Double = 3
    public static let statusButtonExtraWidth: Double = 0 // native NSStatusBarButton may add padding

    public static func width(segments: [Double], gap: Double = providerGap) -> Double {
        guard !segments.isEmpty else { return 0 }
        return imageLeftPadding + imageRightPadding + segments.reduce(0, +) +
               Double(segments.count - 1) * max(0, gap)
    }
}
