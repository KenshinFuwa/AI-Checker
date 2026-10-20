import XCTest
@testable import AICheckerCore

private struct FakeAdapter: UsageProviderAdapter {
    let providerID: String
    let result: ProviderRefreshResult
    func refresh(force: Bool) async -> ProviderRefreshResult { result }
}

final class ProviderRuntimeTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 10000)

    func testUnsupportedAndReauthDoNotAutoPoll() {
        var engine = ProviderRefreshCoordinator()
        engine.setAuth("chatgpt", .unsupported)
        XCTAssertFalse(engine.begin("chatgpt", now: base, forced: true))
        engine.setAuth("codex", .reauthenticationRequired)
        XCTAssertFalse(engine.begin("codex", now: base))
        XCTAssertTrue(engine.begin("codex", now: base, forced: true))
    }

    func testProviderCatalogDistinguishesChatGPTAndCodex() {
        let catalog = AIProviderRegistry.catalog
        XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
        XCTAssertTrue(AIProviderRegistry.isImplemented("codex"))
        XCTAssertTrue(AIProviderRegistry.isImplemented("claude"))
        XCTAssertFalse(AIProviderRegistry.isImplemented("chatgpt"))
        XCTAssertEqual(catalog.first(where: { $0.id == "chatgpt" })?.name, "ChatGPT")
        XCTAssertEqual(AIProviderRegistry.planned.count, 7)
    }

    func testClockInjectionWithFakeTime() {
        struct FakeClock: ProviderClock {
            let instant: Date
            func now() -> Date { instant }
        }
        let clock = FakeClock(instant: base)
        var engine = ProviderRefreshCoordinator()
        XCTAssertTrue(engine.begin("codex", now: clock.now()))
        XCTAssertFalse(engine.begin("codex", now: clock.now()))
    }

    func testFailureDoesNotDestroySuccessfulObservation() {
        var engine = ProviderRefreshCoordinator()
        engine.succeed("claude", now: base)
        engine.fail("claude", failure: .init(.networkUnavailable), now: base.addingTimeInterval(62))
        XCTAssertEqual(engine.states["claude"]?.lastSuccess, base)
        XCTAssertNotNil(engine.states["claude"]?.lastFailure)
    }

    func testMockAdapterContractAndAbsentValues() async {
        let adapter = FakeAdapter(providerID: "chatgpt", result: .init(providerID: "chatgpt", authState: .unsupported, failure: .init(.unsupported)))
        let result = await adapter.refresh(force: true)
        XCTAssertNil(result.snapshot)
        XCTAssertEqual(result.failure?.kind, .unsupported)
    }

    func testHTTPClassification() {
        XCTAssertEqual(ProviderFailure.http(401).kind, .authenticationRequired)
        XCTAssertEqual(ProviderFailure.http(403).kind, .permissionDenied)
        XCTAssertEqual(ProviderFailure.http(404).kind, .resourceUnavailable)
        XCTAssertEqual(ProviderFailure.http(429, retryAfter: 180).retryAfter, 180)
        XCTAssertEqual(ProviderFailure.http(500).kind, .serverUnavailable)
        XCTAssertEqual(ProviderFailure.http(408).kind, .timedOut)
        XCTAssertEqual(ProviderFailure.http(200).kind, .invalidResponse)
    }

    func testPermissionDeniedDoesNotPretendTokenExpired() {
        var engine = ProviderRefreshCoordinator()
        engine.fail("copilot", failure: .http(403), now: base)
        XCTAssertNotEqual(engine.states["copilot"]?.auth, .reauthenticationRequired)
        XCTAssertEqual(engine.states["copilot"]?.lastFailure?.kind, .permissionDenied)
    }

    func testSixtySecondsAndNoExcessPolling() {
        var engine = ProviderRefreshCoordinator()
        XCTAssertTrue(engine.begin("codex", now: base))
        XCTAssertFalse(engine.begin("codex", now: base.addingTimeInterval(59)))
        XCTAssertTrue(engine.begin("codex", now: base.addingTimeInterval(60)))
    }

    func testSleepWakeAndImmediateRefresh() {
        var engine = ProviderRefreshCoordinator()
        XCTAssertTrue(engine.begin("claude", now: base))
        engine.succeed("claude", now: base)
        engine.sleep()
        XCTAssertFalse(engine.begin("claude", now: base.addingTimeInterval(3600), forced: true))
        engine.wake()
        XCTAssertTrue(engine.begin("claude", now: base.addingTimeInterval(30)))
    }

    func testBackoffAndOtherProviderUnaffected() {
        var engine = ProviderRefreshCoordinator()
        for idx in 0..<4 {
            let t = base.addingTimeInterval(Double(idx) * 900)
            engine.fail("claude", failure: .init(.serverUnavailable), now: t)
            XCTAssertEqual(engine.states["claude"]?.nextEligibleAt.timeIntervalSince(t), [60,120,300,600][idx])
        }
        XCTAssertTrue(engine.begin("codex", now: base))
    }

    func test429RespectsRetryAfterEvenWhenForcedAndAfterWake() {
        var engine = ProviderRefreshCoordinator()
        engine.fail("claude", failure: .http(429, retryAfter: 600), now: base)
        XCTAssertFalse(engine.begin("claude", now: base.addingTimeInterval(60), forced: true))
        engine.sleep(); engine.wake()
        XCTAssertFalse(engine.begin("claude", now: base.addingTimeInterval(90), forced: true))
        XCTAssertTrue(engine.begin("claude", now: base.addingTimeInterval(600)))
    }

    func testManualRefreshBypassesNetworkBackoff() {
        var engine = ProviderRefreshCoordinator()
        engine.fail("codex", failure: .init(.networkUnavailable), now: base)
        XCTAssertFalse(engine.begin("codex", now: base.addingTimeInterval(10)))
        XCTAssertTrue(engine.begin("codex", now: base.addingTimeInterval(10), forced: true))
    }

    func testSuccessClearsErrorsAndStaleness() {
        var engine = ProviderRefreshCoordinator()
        engine.fail("codex", failure: .http(401), now: base)
        XCTAssertEqual(engine.states["codex"]?.auth, .reauthenticationRequired)
        engine.succeed("codex", now: base)
        XCTAssertNil(engine.states["codex"]?.lastFailure)
        XCTAssertEqual(engine.states["codex"]?.auth, .connected)
        XCTAssertTrue(engine.isFresh("codex", now: base.addingTimeInterval(179)))
        XCTAssertFalse(engine.isFresh("codex", now: base.addingTimeInterval(181)))
    }

    func testSwitchingProfileResetsOnlyOneProvider() {
        var engine = ProviderRefreshCoordinator()
        engine.succeed("codex", now: base)
        engine.succeed("claude", now: base)
        engine.reset("codex")
        XCTAssertNil(engine.states["codex"])
        XCTAssertNotNil(engine.states["claude"])
    }
}
