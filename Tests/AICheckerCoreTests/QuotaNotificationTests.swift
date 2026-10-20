import XCTest
import Foundation
@testable import AICheckerCore

final class QuotaNotificationTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let otherAccount = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private let enabled = QuotaNotificationPreferences(notifyOnReset: true, notifyOnExhaustion: true)

    private func sample(_ provider: String = "codex", at offset: TimeInterval,
                        five: Double? = 40, week: Double? = 80,
                        fiveReset: TimeInterval? = 300,
                        weekReset: TimeInterval? = 900) -> AIQuotaSnapshot {
        .init(providerID: provider,
              fiveHour: QuotaWindow(remainingPercent: five,
                                    resetsAt: fiveReset.map { base.addingTimeInterval($0) }),
              weekly: QuotaWindow(remainingPercent: week,
                                  resetsAt: weekReset.map { base.addingTimeInterval($0) }),
              updatedAt: base.addingTimeInterval(offset), source: "TEST")
    }

    private func events(_ monitor: inout QuotaNotificationMonitor, _ snap: AIQuotaSnapshot,
                        id: UUID? = nil, preferences: QuotaNotificationPreferences? = nil) -> [QuotaNotificationEvent] {
        monitor.ingest(accountID: id ?? account, snapshot: snap,
                       settings: preferences ?? enabled, now: snap.updatedAt!)
    }

    func testFirstSampleDoesNotTriggerEvenIfAlreadyExhausted() {
        var monitor = QuotaNotificationMonitor()
        XCTAssertTrue(events(&monitor, sample(at: 0, five: 0, week: 0)).isEmpty)
        XCTAssertTrue(events(&monitor, sample(at: 60, five: 0, week: 0)).isEmpty)
    }

    func testExhaustionTriggersOnceForEachWindow() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 4, week: 1))
        let depleted = events(&monitor, sample(at: 60, five: 0, week: 0))
        XCTAssertEqual(depleted.count, 2)
        XCTAssertEqual(Set(depleted.map(\.window.rawValue)), Set(["fiveHours", "week"]))
        XCTAssertTrue(depleted.allSatisfy { $0.kind == .exhausted })
        XCTAssertTrue(events(&monitor, sample(at: 120, five: 0, week: 0)).isEmpty)
    }

    func testActualResetEpochChangeNotCountdownAlone() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 0, week: 10))
        XCTAssertTrue(events(&monitor, sample(at: 299, five: 0, week: 10)).isEmpty)
        // 5h reset is due (t=300), new future reset t=18300.
        let reset = events(&monitor, sample(at: 360, five: 98, week: 10,
                                            fiveReset: 18300))
        XCTAssertEqual(reset.count, 1)
        XCTAssertEqual(reset.first?.kind, .reset)
        XCTAssertEqual(reset.first?.window, .fiveHours)
        XCTAssertTrue(events(&monitor, sample(at: 420, five: 97, week: 10,
                                             fiveReset: 18300)).isEmpty)
    }

    func testBothResetWindowsAndOnlyAfterDue() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0))
        XCTAssertTrue(events(&monitor, sample(at: 100, five: 100, week: 100,
                                             fiveReset: 18300, weekReset: 605700)).isEmpty)
        // ETA corrections are not reset events. First new estimate is now baseline.
        let eventsAfterDue = events(&monitor, sample(at: 18400, five: 97, week: 99,
                                                     fiveReset: 36600, weekReset: 605700))
        XCTAssertEqual(eventsAfterDue.count, 1)
        XCTAssertEqual(eventsAfterDue.first?.window, .fiveHours)
    }

    func testWeeklyResetConfirmedByNewWeeklyEpoch() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, week: 0))
        let newWeek = events(&monitor, sample(at: 960, week: 100,
                                              weekReset: 605700))
        XCTAssertEqual(newWeek.count, 1)
        XCTAssertEqual(newWeek.first?.window, .week)
        XCTAssertEqual(newWeek.first?.kind, .reset)
        XCTAssertTrue(events(&monitor, sample(at: 1020, week: 99,
                                             weekReset: 605700)).isEmpty)
    }

    func testDisplayedZeroPercentRoundsUpToHalfPercent() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 1.5))
        XCTAssertEqual(events(&monitor, sample(at: 60, five: 0.49)).first?.kind, .exhausted)
    }

    func testWindowResetSuppressesFalseExhaustionAcrossEpochChange() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 20))
        let triggered = events(&monitor, sample(at: 360, five: 0, fiveReset: 18300))
        XCTAssertEqual(triggered.map(\.kind), [.reset])
    }

    func testNoOutOfOrderOrReplayedSnapshot() {
        var monitor = QuotaNotificationMonitor()
        let prior = sample(at: 0, five: 10)
        _ = events(&monitor, prior)
        XCTAssertTrue(events(&monitor, prior).isEmpty)
        XCTAssertTrue(events(&monitor, sample(at: -50, five: 0)).isEmpty)
        XCTAssertEqual(events(&monitor, sample(at: 60, five: 0)).count, 1)
    }

    func testStaleUntrustedOrUnknownValuesNeverTrigger() {
        var monitor = QuotaNotificationMonitor()
        let first = sample(at: 0, five: 12)
        _ = events(&monitor, first)
        let stale = sample(at: 60, five: 0)
        XCTAssertTrue(monitor.ingest(accountID: account, snapshot: stale,
                                     settings: enabled,
                                     now: base.addingTimeInterval(800)).isEmpty)
        XCTAssertTrue(events(&monitor, sample(at: 70, five: nil)).isEmpty)
        XCTAssertEqual(events(&monitor, sample(at: 80, five: 0)).count, 1)
    }

    func testDisabledModesAndReenableDoNotAnnounceOldEvent() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 5))
        let off = QuotaNotificationPreferences()
        XCTAssertTrue(events(&monitor, sample(at: 60, five: 0), preferences: off).isEmpty)
        XCTAssertTrue(events(&monitor, sample(at: 90, five: 0)).isEmpty)
    }

    func testMultipleAccountsDoNotShareAlertHistory() {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 2))
        _ = events(&monitor, sample(at: 0, five: 6), id: otherAccount)
        XCTAssertEqual(events(&monitor, sample(at: 60, five: 0), id: account).count, 1)
        XCTAssertEqual(events(&monitor, sample(at: 60, five: 0), id: otherAccount).count, 1)
        XCTAssertTrue(events(&monitor, sample(at: 70, five: 0), id: account).isEmpty)
    }

    func testPersistenceKeepsDeduplicationAcrossRestart() throws {
        var monitor = QuotaNotificationMonitor()
        _ = events(&monitor, sample(at: 0, five: 2))
        XCTAssertEqual(events(&monitor, sample(at: 60, five: 0)).count, 1)
        let bytes = try JSONEncoder().encode(monitor)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("TEST"))
        var restored = try JSONDecoder().decode(QuotaNotificationMonitor.self, from: bytes)
        XCTAssertTrue(events(&restored, sample(at: 120, five: 0)).isEmpty)
    }

    func testMissingObservationOrNewAccountDoesNotInventEvents() {
        var monitor = QuotaNotificationMonitor()
        let missing = AIQuotaSnapshot(providerID: "codex", fiveHour: .init(remainingPercent: 0, resetsAt: nil),
                                      weekly: .init(remainingPercent: nil, resetsAt: nil),
                                      updatedAt: nil, source: nil)
        XCTAssertTrue(monitor.ingest(accountID: account, snapshot: missing,
                                     settings: enabled, now: base).isEmpty)
        let unsupported = sample("chatgpt", at: 0, five: 0, week: 0)
        XCTAssertTrue(events(&monitor, unsupported).isEmpty)
    }
}
