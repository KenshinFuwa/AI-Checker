import XCTest
@testable import AICheckerCore

final class RefreshPolicyTests: XCTestCase {
    private let providers = AIProviderRegistry.builtins

    private func sample(_ pct: Double, at: Date = Date(timeIntervalSince1970: 1)) -> [String: AIQuotaSnapshot] {
        ["codex": AIQuotaSnapshot(providerID: "codex",
                                  fiveHour: .init(remainingPercent: pct, resetsAt: nil),
                                  weekly: .init(remainingPercent: 60, resetsAt: nil),
                                  updatedAt: at, source: "test")]
    }

    func testSixtySecondCadenceAndTolerance() {
        XCTAssertEqual(RefreshPolicy.interval, 60)
        XCTAssertGreaterThan(RefreshPolicy.timerTolerance, 0)
        XCTAssertLessThanOrEqual(RefreshPolicy.timerTolerance, 10)
    }

    func testIdenticalQuotaIgnoresFetchTimestamp() {
        let first = RefreshPolicy.DisplayKey(snapshots: sample(90), visibleProviders: providers, stale: false, demo: false)
        let again = RefreshPolicy.DisplayKey(snapshots: sample(90, at: Date(timeIntervalSince1970: 20)), visibleProviders: providers, stale: false, demo: false)
        XCTAssertEqual(first, again)
    }

    func testChangeToQuotaOrStaleRedraws() {
        let a = RefreshPolicy.DisplayKey(snapshots: sample(90), visibleProviders: providers, stale: false, demo: false)
        let b = RefreshPolicy.DisplayKey(snapshots: sample(89), visibleProviders: providers, stale: false, demo: false)
        let c = RefreshPolicy.DisplayKey(snapshots: sample(90), visibleProviders: providers, stale: true, demo: false)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testHiddenProvidersCannotForceRedraw() {
        let onlyCodex = [providers[0]]
        var one = sample(90)
        var two = sample(90)
        let claude = AIQuotaSnapshot(providerID: "claude", fiveHour: .init(remainingPercent: 12, resetsAt: nil), weekly: .init(remainingPercent: 80, resetsAt: nil), updatedAt: nil, source: "test")
        one["claude"] = claude
        two["claude"] = AIQuotaSnapshot(providerID: "claude", fiveHour: .init(remainingPercent: 9, resetsAt: nil), weekly: .init(remainingPercent: 80, resetsAt: nil), updatedAt: nil, source: "test")
        XCTAssertEqual(RefreshPolicy.DisplayKey(snapshots: one, visibleProviders: onlyCodex, stale: false, demo: false),
                       RefreshPolicy.DisplayKey(snapshots: two, visibleProviders: onlyCodex, stale: false, demo: false))
    }

    func testNilDoesNotBecomeZero() {
        let key = RefreshPolicy.DisplayKey(snapshots: [:], visibleProviders: providers, stale: true, demo: false)
        XCTAssertNil(key.values[0].fiveHour)
        XCTAssertNil(key.values[1].weekly)
    }
}
