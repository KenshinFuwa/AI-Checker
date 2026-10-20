import XCTest
@testable import AICheckerCore

final class TelemetryFreshnessTests: XCTestCase {
    private func sample(age: TimeInterval, now: Date) -> AIQuotaSnapshot {
        AIQuotaSnapshot(providerID: "claude",
                        fiveHour: QuotaWindow(remainingPercent: 52, resetsAt: nil),
                        weekly: QuotaWindow(remainingPercent: 60, resetsAt: nil),
                        updatedAt: now.addingTimeInterval(-age), source: "Claude Code")
    }
    func testOnlyRecentStatusLineDataCanBeDisplayedAsLive() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertTrue(TelemetryFreshness.isRecent(sample(age: 0, now: now), now: now))
        XCTAssertTrue(TelemetryFreshness.isRecent(sample(age: 180, now: now), now: now))
        XCTAssertFalse(TelemetryFreshness.isRecent(sample(age: 181, now: now), now: now))
        XCTAssertFalse(TelemetryFreshness.isRecent(sample(age: -61, now: now), now: now))
        XCTAssertFalse(TelemetryFreshness.isRecent(nil, now: now))
    }
}
