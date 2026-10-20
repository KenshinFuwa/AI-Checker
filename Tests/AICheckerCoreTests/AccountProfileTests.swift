import XCTest
@testable import AICheckerCore

final class AccountProfileTests: XCTestCase {
    func testDistinctCodexAccountsAndSwitch() throws {
        var cfg = AccountConfiguration()
        let personal = try XCTUnwrap(cfg.addCodex(label: " Personal "))
        let lab = try XCTUnwrap(cfg.addCodex(label: "Lab"))
        XCTAssertEqual(cfg.activeCodex?.id, personal.id)
        XCTAssertTrue(cfg.selectCodex(lab.id))
        XCTAssertEqual(cfg.activeCodex?.label, "Lab")
        let decoded = try XCTUnwrap(AccountConfiguration.decodeSafely(JSONEncoder().encode(cfg)))
        XCTAssertEqual(decoded, cfg)
        XCTAssertTrue(cfg.remove(lab.id))
        XCTAssertEqual(cfg.activeCodex?.id, personal.id)
    }
    func testUnknownSelectionAndProfileLimit() {
        var cfg = AccountConfiguration()
        XCTAssertFalse(cfg.selectCodex(UUID()))
        for i in 0..<8 { XCTAssertNotNil(cfg.addCodex(label: "Profile \(i)")) }
        XCTAssertNil(cfg.addCodex(label: "Ninth"))
        XCTAssertFalse(cfg.rename(UUID(), to: "Other"))
    }
    func testAppServerRateLimitsRejectAmbiguousAndExpired() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        func window(_ used: Int, _ minutes: Int, _ reset: Double) -> [String: Any] {
            ["usedPercent": used, "windowDurationMins": minutes, "resetsAt": reset]
        }
        let valid = ["rateLimits": ["limitId": "codex", "primary": window(33, 300, 2_000_010_000), "secondary": window(15, 10080, 2_000_050_000)]]
        let snap = CodexAppServerQuotaDecoder.decodeResult(valid, now: now)
        XCTAssertEqual(snap?.fiveHour.remainingPercent, 67)
        XCTAssertEqual(snap?.weekly.remainingPercent, 85)
        XCTAssertNil(CodexAppServerQuotaDecoder.decodeResult(["rateLimits": ["limitId": "other", "primary": window(1, 300, 2_000_010_000)]], now: now))
        XCTAssertNil(CodexAppServerQuotaDecoder.decodeResult(["rateLimitsByLimitId": ["other": ["primary": window(1, 300, 2_000_010_000)]], "rateLimits": valid["rateLimits"]!], now: now))
        XCTAssertNil(CodexAppServerQuotaDecoder.decodeResult(["rateLimits": ["primary": window(10, 300, 1_999_999_999)]], now: now))
    }
    func testWeeklyOnlyNeverInventsFiveHours() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let result: [String: Any] = ["rateLimitsByLimitId": ["codex": ["secondary": ["usedPercent": 67, "windowDurationMins": 10080, "resetsAt": 2_000_050_000]]]]
        let snap = CodexAppServerQuotaDecoder.decodeResult(result, now: now)
        XCTAssertNil(snap?.fiveHour.remainingPercent)
        XCTAssertEqual(snap?.weekly.remainingPercent, 33)
    }
}

extension AccountProfileTests {
    func testClaudeProfilesAreIndependentAndSelectable() throws {
        var cfg = AccountConfiguration()
        let lab = try XCTUnwrap(cfg.addCodex(label: "lab"))
        let personal = try XCTUnwrap(cfg.addClaude(label: " personal "))
        let other = try XCTUnwrap(cfg.addClaude(label: "other"))
        XCTAssertEqual(cfg.activeCodexID, lab.id)
        XCTAssertEqual(cfg.activeClaudeID, personal.id)
        XCTAssertFalse(cfg.selectCodex(other.id))
        XCTAssertFalse(cfg.selectClaude(lab.id))
        XCTAssertTrue(cfg.selectClaude(other.id))
        XCTAssertEqual(cfg.activeClaude?.label, "other")
        XCTAssertEqual(cfg.activeCodex?.label, "lab")
        let restored = try XCTUnwrap(AccountConfiguration.decodeSafely(JSONEncoder().encode(cfg)))
        XCTAssertEqual(restored, cfg)
        XCTAssertTrue(cfg.remove(other.id))
        XCTAssertEqual(cfg.activeClaudeID, personal.id)
        XCTAssertEqual(cfg.activeCodexID, lab.id)
    }
    func testV13ConfigMigrationWithoutClaudeField() throws {
        let id = UUID().uuidString
        let data = Data("""
        {"version":1,"accounts":[{"id":"\(id)","providerID":"codex","label":"personal"}],"activeCodexID":"\(id)"}
        """.utf8)
        var restored = try XCTUnwrap(AccountConfiguration.decodeSafely(data))
        XCTAssertNotNil(restored.activeCodex)
        XCTAssertNil(restored.activeClaudeID)
        XCTAssertNotNil(restored.addClaudeIfPossibleForTest())
    }
    func testProfilesHaveIndependentEightAccountLimits() {
        var cfg = AccountConfiguration()
        for i in 0..<8 {
            XCTAssertNotNil(cfg.addCodex(label: "c\(i)"))
            XCTAssertNotNil(cfg.addClaude(label: "a\(i)"))
        }
        XCTAssertNil(cfg.addCodex(label: "ninth"))
        XCTAssertNil(cfg.addClaude(label: "ninth"))
        XCTAssertNotNil(AccountConfiguration.decodeSafely(try! JSONEncoder().encode(cfg)))
    }
    func testDecoderRejectsCrossProviderActiveIds() throws {
        var cfg = AccountConfiguration()
        let claude = try XCTUnwrap(cfg.addClaude(label: "Claude"))
        let codex = try XCTUnwrap(cfg.addCodex(label: "Codex"))
        let data = try JSONEncoder().encode(cfg)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["activeClaudeID"] = codex.id.uuidString
        json["activeCodexID"] = claude.id.uuidString
        XCTAssertNil(AccountConfiguration.decodeSafely(try JSONSerialization.data(withJSONObject: json)))
    }
}

private extension AccountConfiguration {
    mutating func addClaudeIfPossibleForTest() -> AICheckerAccount? { addClaude(label: "first") }
}
