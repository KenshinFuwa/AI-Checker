import XCTest
import Foundation
@testable import AICheckerCore

final class QuotaTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNativeCodexReadsFiveHourAndWeeklyWithoutExternalCLI() {
        let json = #"{"timestamp":"2027-01-15T08:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":24,"window_minutes":300,"resets_at":1800001000},"secondary":{"used_percent":57.5,"window_minutes":10080,"resets_at":1800002000}}}}"#
        // use a controllable `now` safely after the event time
        let sampleNow = Date(timeIntervalSince1970: 1_801_000_000)
        let template = json.replacingOccurrences(of: "1800001000", with: "1801001000")
            .replacingOccurrences(of: "1800002000", with: "1801002000")
        let parsed = NativeQuotaDecoder.codexRolloutEvent(Data(template.utf8), now: sampleNow)
        XCTAssertEqual(parsed?.fiveHour.remainingPercent, 76)
        XCTAssertEqual(parsed?.weekly.remainingPercent, 42.5)
    }

    func testCodexMinuteRoundingAndRelativeReset() throws {
        // Some Codex rollout versions report 299/10079 rather than 300/10080
        // and a reset countdown instead of an absolute timestamp.
        let stamp = "2026-10-19T05:30:00Z"
        let formatter = ISO8601DateFormatter()
        let observedAt = try XCTUnwrap(formatter.date(from: stamp))
        let now = observedAt.addingTimeInterval(60)
        let json = #"{"timestamp":"2026-10-19T05:30:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":26,"window_minutes":299,"resets_in_seconds":18000},"secondary":{"used_percent":33,"window_minutes":10079,"resets_in_seconds":604800}}}}"#
        let parsed = try XCTUnwrap(NativeQuotaDecoder.codexRolloutEvent(Data(json.utf8), now: now))
        XCTAssertEqual(parsed.fiveHour.remainingPercent, 74)
        XCTAssertEqual(parsed.weekly.remainingPercent, 67)
        XCTAssertEqual(parsed.fiveHour.resetsAt?.timeIntervalSince1970,
                       observedAt.addingTimeInterval(18000).timeIntervalSince1970)
    }

    func testCodexDoesNotGuessWindowFromPrimaryPosition() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let json = #"{"timestamp":"2026-10-19T05:30:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":33,"window_minutes":10080,"resets_at":1800001000}}}}"#
        let parsed = NativeQuotaDecoder.codexRolloutEvent(Data(json.utf8), now: now)
        XCTAssertNil(parsed?.fiveHour.remainingPercent)
        XCTAssertEqual(parsed?.weekly.remainingPercent, 67)
    }

    func testCodexMissingResetCannotRemainValidIndefinitely() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let json = #"{"timestamp":"2026-10-19T05:30:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":26,"window_minutes":300}}}}"#
        XCTAssertNil(NativeQuotaDecoder.codexRolloutEvent(Data(json.utf8), now: now))
    }

    func testCodexRefusesInvalidAndUnrelatedEvents() {
        let other = #"{"timestamp":"2026-10-19T00:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex_spark","primary":{"used_percent":50,"window_minutes":300}}}}"#
        XCTAssertNil(NativeQuotaDecoder.codexRolloutEvent(Data(other.utf8), now: Date(timeIntervalSince1970: 1_800_000_000)))
        let invalid = #"{"timestamp":"2026-10-19T00:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":150,"window_minutes":300}}}}"#
        XCTAssertNil(NativeQuotaDecoder.codexRolloutEvent(Data(invalid.utf8), now: Date(timeIntervalSince1970: 1_800_000_000)))
    }

    func testClaudeOfficialStatusLineAndPrivacyPreservingStorage() throws {
        let json = #"{"session_id":"secret-identifer","cwd":"/private/myproject","rate_limits":{"five_hour":{"used_percentage":55,"resets_at":1800001000},"seven_day":{"used_percentage":12.25,"resets_at":1800002000}}}"#
        let snapshot = try XCTUnwrap(NativeQuotaDecoder.claudeStatusLine(Data(json.utf8), now: now))
        XCTAssertEqual(snapshot.fiveHour.remainingPercent, 45)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 87.75)
        let bytes = try JSONEncoder().encode(SanitizedClaudeQuota(snapshot))
        let saved = try XCTUnwrap(String(data: bytes, encoding: .utf8))
        XCTAssertFalse(saved.contains("secret-identifer"))
        XCTAssertFalse(saved.contains("/private/myproject"))
        let roundTrip = try JSONDecoder().decode(SanitizedClaudeQuota.self, from: bytes)
        XCTAssertEqual(roundTrip.snapshot(now: now)?.fiveHour.remainingPercent, 45)
    }

    func testMissingUsageNeverBecomes100PercentRemaining() {
        let json = #"{"session_id":"abc","context_window":{"used_percentage":50}}"#
        XCTAssertNil(NativeQuotaDecoder.claudeStatusLine(Data(json.utf8), now: now))
    }

    func testZeroUsageAndExpiredWindow() {
        let data = Data(#"{"rate_limits":{"five_hour":{"used_percentage":0,"resets_at":1800001000},"seven_day":{"used_percentage":100,"resets_at":1799999000}}}"#.utf8)
        let snapshot = NativeQuotaDecoder.claudeStatusLine(data, now: now)
        XCTAssertEqual(snapshot?.fiveHour.remainingPercent, 100)
        XCTAssertNil(snapshot?.weekly.remainingPercent)
    }

    func testExpiredCachedSampleNeverGuessesNewReset() throws {
        let data = Data(#"{"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":1800001000}}}"#.utf8)
        let snapshot = try XCTUnwrap(NativeQuotaDecoder.claudeStatusLine(data, now: now))
        let record = SanitizedClaudeQuota(snapshot)
        XCTAssertNil(record.snapshot(now: Date(timeIntervalSince1970: 1_800_001_001)))
    }
}
