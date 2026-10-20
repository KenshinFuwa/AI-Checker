import XCTest
@testable import AICheckerCore

final class ExternalAPIUsageTests: XCTestCase {
    private let observed = Date(timeIntervalSince1970: 1_799_000_000)
    private func decode(_ body: String, _ kind: ExternalAPIKind) throws -> ExternalAPIReport {
        try ExternalAPIUsage.decode(Data(body.utf8), kind: kind,
                                    observedAt: observed, periodStart: ExternalAPIUsage.startOfUTCMonth(observed))
    }
    func testOpenAICostsAggregateAndNoQuota() throws {
        let r = try decode(#"{"has_more":false,"data":[{"results":[{"amount":{"value":1.75,"currency":"usd"}},{"amount":{"value":2.25,"currency":"usd"}}]},{"results":[]}]}"#, .openaiAPI)
        XCTAssertEqual(r.value, 4)
        XCTAssertEqual(r.unit, "USD")
        XCTAssertThrowsError(try decode(#"{"has_more":true,"data":[]}"#, .openaiAPI))
        XCTAssertThrowsError(try decode(#"{"has_more":false,"data":[{"results":[{"amount":{"value":1,"currency":"eur"}}]}]}"#, .openaiAPI))
    }
    func testCursorTeamRequestCount() throws {
        let r = try decode(#"{"data":[{"agentRequests":2,"chatRequests":3},{"agentRequests":5}]}"#, .cursorTeam)
        XCTAssertEqual(r.value, 7)
        XCTAssertThrowsError(try decode(#"{"data":[{"chatRequests":3}]}"#, .cursorTeam))
        XCTAssertThrowsError(try decode(#"{"data":[{"agentRequests":-1}]}"#, .cursorTeam))
    }
    func testXAIUsageAndIncompleteResults() throws {
        let r = try decode(#"{"limitReached":false,"timeSeries":[{"dataPoints":[{"values":[0.6]},{"values":[0.4]}]},{"dataPoints":[{"values":[2.0]}]}]}"#, .xaiAPI)
        XCTAssertEqual(r.value, 3.0, accuracy: 1e-10)
        XCTAssertThrowsError(try decode(#"{"limitReached":true,"timeSeries":[]}"#, .xaiAPI))
        XCTAssertThrowsError(try decode(#"{"limitReached":false,"timeSeries":[{"dataPoints":[{"values":[1,2]}]}]}"#, .xaiAPI))
    }
    func testRejectsInvalidBodiesAndTeamIDs() {
        XCTAssertTrue(ExternalAPIUsage.validTeamID("65c1e471-205f-4566-9c5a-07198bcdf4ce"))
        for bad in ["", "../secret", "1234?token=x", "other/account"] { XCTAssertFalse(ExternalAPIUsage.validTeamID(bad)) }
        XCTAssertThrowsError(try decode(#"{"data":{}}"#, .cursorTeam))
        XCTAssertThrowsError(try decode(#"{}"#, .openaiAPI))
    }
    func testUTCMonthStart() {
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(utc.component(.day, from: ExternalAPIUsage.startOfUTCMonth(date)), 1)
        XCTAssertEqual(utc.component(.hour, from: ExternalAPIUsage.startOfUTCMonth(date)), 0)
    }
    func testKindScopesAreNotSubscriptionQuotas() {
        for kind in ExternalAPIKind.allCases {
            XCTAssertFalse(kind.scope.contains("5h"))
            XCTAssertFalse(kind.scope.contains("remaining"))
        }
    }
}
