import Foundation

/// Source observations are not live server reads just because AI Checker polls every minute.
public enum TelemetryFreshness {
    public static let displayTTL: TimeInterval = 180
    public static func isRecent(_ sample: AIQuotaSnapshot?, now: Date = Date()) -> Bool {
        guard let captured = sample?.updatedAt else { return false }
        let age = now.timeIntervalSince(captured)
        return age >= -60 && age <= displayTTL
    }
}
