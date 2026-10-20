import AppKit
import AICheckerCore

/// High-chroma, distinct status colors; never taken from the provider-name tint.
/// Deliberate separation of hue: lime 92°, orange 23°, yellow 54°, red 351°.
enum QuotaColorPalette {
    static func color(for remaining: Double?) -> NSColor? {
        guard let band = RemainingQuotaBand.forRemaining(remaining) else { return nil }
        switch band {
        case .lime:   return NSColor(calibratedRed: 0.61, green: 1.00, blue: 0.12, alpha: 1)
        case .orange: return NSColor(calibratedRed: 1.00, green: 0.39, blue: 0.06, alpha: 1)
        case .yellow: return NSColor(calibratedRed: 1.00, green: 0.91, blue: 0.00, alpha: 1)
        case .red:    return NSColor(calibratedRed: 1.00, green: 0.19, blue: 0.30, alpha: 1)
        }
    }
}
