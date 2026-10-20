import XCTest
@testable import AICheckerCore

final class CopilotBillingTests: XCTestCase {
    func testGitHubHTTPDiagnosticsDistinguishAuthBillingAndRateLimits() {
        XCTAssertEqual(CopilotHTTPDiagnostic.failure(status: 401, rateLimitRemaining: nil, retryAfter: nil).kind, .authenticationRequired)
        XCTAssertEqual(CopilotHTTPDiagnostic.failure(status: 403, rateLimitRemaining: "42", retryAfter: nil).kind, .permissionDenied)
        XCTAssertEqual(CopilotHTTPDiagnostic.failure(status: 403, rateLimitRemaining: "0", retryAfter: 120).kind, .rateLimited)
        XCTAssertEqual(CopilotHTTPDiagnostic.failure(status: 403, rateLimitRemaining: "0", retryAfter: 120).retryAfter, 120)
        XCTAssertEqual(CopilotHTTPDiagnostic.failure(status: 404, rateLimitRemaining: nil, retryAfter: nil).kind, .resourceUnavailable)
        XCTAssertEqual(CopilotHTTPDiagnostic.failure(status: 429, rateLimitRemaining: nil, retryAfter: 30).kind, .rateLimited)
        XCTAssertTrue(CopilotHTTPDiagnostic.message(status: 403, rateLimitRemaining: nil).contains("権限不足"))
        XCTAssertFalse(CopilotHTTPDiagnostic.message(status: 403, rateLimitRemaining: nil).contains("トークンが無効"))
        XCTAssertTrue(CopilotHTTPDiagnostic.message(status: 401, rateLimitRemaining: nil).contains("トークン"))
    }

    func testOfficialResponseAggregatesOnlyCopilotRequests() throws {
        let json = #"{"usageItems":[{"product":"Copilot","sku":"Copilot Premium Request","unitType":"requests","grossQuantity":123.5,"netQuantity":120},{"product":"Copilot","sku":"Copilot Premium Request","unitType":"requests","grossQuantity":20},{"product":"Actions","sku":"Actions Linux","unitType":"minutes","grossQuantity":9999},{"product":"Copilot","sku":"AI Credit","unitType":"ai-credits","grossQuantity":9999}]}"#
        let time = Date(timeIntervalSince1970: 2000)
        let result = try CopilotBillingDecoder.decode(Data(json.utf8), username: "octocat", year: 2026, month: 10, observedAt: time)
        XCTAssertEqual(result.grossRequests, 143.5)
        XCTAssertEqual(result.observedAt, time)
        XCTAssertEqual(result.username, "octocat")
    }

    func testEmptyValidReportIsZeroButMissingKeyErrors() throws {
        let valid = try CopilotBillingDecoder.decode(Data(#"{"usageItems":[]}"#.utf8), username: "octocat", year: 2026, month: 10, observedAt: .now)
        XCTAssertEqual(valid.grossRequests, 0)
        XCTAssertThrowsError(try CopilotBillingDecoder.decode(Data(#"{"message":"Bad credentials"}"#.utf8), username: "octocat", year: 2026, month: 10, observedAt: .now))
    }

    func testNeverConvertsUsageIntoFiveHourPercentage() {
        XCTAssertTrue(CopilotBillingDecoder.validUser("my-user42"))
        for invalid in ["", "../admin", "two names", "_token", "-name", "name-", "abcdefghijabcdefghijabcdefghijabcdefghij"] {
            XCTAssertFalse(CopilotBillingDecoder.validUser(invalid), invalid)
        }
    }

    func testInvalidOrNegativeQuantityRejected() {
        let negative = Data(#"{"usageItems":[{"product":"Copilot","sku":"Copilot Premium Request","unitType":"requests","grossQuantity":-1}]}"#.utf8)
        XCTAssertThrowsError(try CopilotBillingDecoder.decode(negative, username: "octocat", year: 2026, month: 10, observedAt: .now))
        let missing = Data(#"{"usageItems":[{"product":"Copilot","sku":"Copilot Premium Request","unitType":"requests","netQuantity":1}]}"#.utf8)
        XCTAssertThrowsError(try CopilotBillingDecoder.decode(missing, username: "octocat", year: 2026, month: 10, observedAt: .now))
    }
}
