import XCTest
@testable import AICheckerCore

final class UsageVisualPolicyTests: XCTestCase {
    func testExactPaletteThresholdsAndBothSides() {
        for (value, band): (Double, RemainingQuotaBand) in [
            (100, .lime), (70, .lime), (69, .orange), (40, .orange),
            (39, .yellow), (20, .yellow), (19, .red), (0, .red)
        ] {
            XCTAssertEqual(RemainingQuotaBand.forRemaining(value), band)
        }
    }

    func testDisplayedRoundedPercentMatchesPalette() {
        XCTAssertEqual(RemainingQuotaBand.forRemaining(69.49), .orange)
        XCTAssertEqual(RemainingQuotaBand.forRemaining(69.50), .lime)
        XCTAssertEqual(RemainingQuotaBand.forRemaining(39.50), .orange)
        XCTAssertEqual(RemainingQuotaBand.forRemaining(19.50), .yellow)
        XCTAssertEqual(RemainingQuotaBand.forRemaining(99.7), .lime)
    }

    func testRejectsInvalidUnknownNumbers() {
        XCTAssertNil(RemainingQuotaBand.forRemaining(nil))
        XCTAssertNil(RemainingQuotaBand.forRemaining(.nan))
        XCTAssertNil(RemainingQuotaBand.forRemaining(.infinity))
        XCTAssertNil(RemainingQuotaBand.forRemaining(-0.1))
        XCTAssertNil(RemainingQuotaBand.forRemaining(100.1))
    }

    func testNaturalEnglishCountdowns() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(3 * 3600 + 30 * 60), now: now), "3 hours 30 minutes")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(3 * 86400 + 3 * 3600 + 30 * 60), now: now), "3 days 3 hours 30 minutes")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(86400 + 3600 + 60), now: now), "1 day 1 hour 1 minute")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(7 * 86400), now: now), "7 days")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(3600), now: now), "1 hour")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(1), now: now), "1 minute")
    }

    func testExpiredMissingAndStaleNeverInventCountdown() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(ResetCountdown.format(until: nil, now: now), "Unknown")
        XCTAssertEqual(ResetCountdown.format(until: now, now: now), "Awaiting update")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(-1), now: now), "Awaiting update")
        XCTAssertEqual(ResetCountdown.format(until: now.addingTimeInterval(3600), now: now, fresh: false), "Awaiting update")
    }
}
