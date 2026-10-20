import XCTest
@testable import AICheckerCore

final class ClaudeWebUsageTests: XCTestCase {
    func testFiveHourAndWeeklyAndFractionalDates() {
        let json = #"{"five_hour":{"utilization":25.5,"resets_at":"2030-10-19T12:00:00.123+00:00"},"seven_day":{"utilization":62,"resets_at":"2030-10-25T12:00:00Z"}}"#
        let snap = ClaudeWebUsage.decode(Data(json.utf8), now: Date(timeIntervalSince1970: 1_900_000_000))
        XCTAssertEqual(snap?.fiveHour.remainingPercent, 74.5)
        XCTAssertEqual(snap?.weekly.remainingPercent, 38)
        XCTAssertNotNil(snap?.fiveHour.resetsAt)
    }

    func testPartialAndMissingAreNotInvented() {
        let data = Data(#"{"five_hour":null,"seven_day":{"utilization":13}}"#.utf8)
        let snap = ClaudeWebUsage.decode(data)
        XCTAssertNil(snap?.fiveHour.remainingPercent)
        XCTAssertEqual(snap?.weekly.remainingPercent, 87)
        XCTAssertNil(ClaudeWebUsage.decode(Data(#"{"five_hour":null,"seven_day":null}"#.utf8)))
    }

    func testMalformedAndExpiredAreRejected() {
        XCTAssertNil(ClaudeWebUsage.decode(Data(#"{"five_hour":{"utilization":"23"}}"#.utf8)))
        XCTAssertNil(ClaudeWebUsage.decode(Data(#"{"five_hour":{"utilization":14,"resets_at":"2020-01-01T00:00:00Z"}}"#.utf8)))
        XCTAssertNil(ClaudeWebUsage.decode(Data(#"{"five_hour":{"utilization":-1}}"#.utf8)))
    }

    func testOverLimitClampsRemainingWithoutGuessing() {
        let snap = ClaudeWebUsage.decode(Data(#"{"five_hour":{"utilization":105}}"#.utf8))
        XCTAssertEqual(snap?.fiveHour.remainingPercent, 0)
    }
}
