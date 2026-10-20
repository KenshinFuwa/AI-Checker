import XCTest
@testable import AICheckerCore

final class ConsumerWebAccessTests: XCTestCase {
    func testFiveOfficialDestinationsHaveStableUniqueHTTPSOrigins() {
        let entries = ConsumerWebAccess.destinations
        XCTAssertEqual(entries.map(\.id), ["chatgpt", "gemini", "perplexity", "cursor", "grok"])
        XCTAssertEqual(Set(entries.map(\.id)).count, 5)
        for site in entries {
            XCTAssertEqual(site.url?.scheme, "https")
            XCTAssertNotNil(site.url?.host)
            XCTAssertFalse(site.instructions.isEmpty)
            XCTAssertEqual(ConsumerWebAccess.destination(for: site.id), site)
        }
        XCTAssertNil(ConsumerWebAccess.destination(for: "unknown"))
    }

    func testManualNotesNeverAcceptTokensOrUnsupportedSources() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertNil(ConsumerUsageNote(providerID: "api", text: "42%", recordedAt: now))
        XCTAssertNil(ConsumerUsageNote(providerID: "cursor", text: "", recordedAt: now))
        XCTAssertNil(ConsumerUsageNote(providerID: "cursor", text: "Bearer secret", recordedAt: now))
        XCTAssertNil(ConsumerUsageNote(providerID: "cursor", text: "sk-hidden", recordedAt: now))
        XCTAssertNil(ConsumerUsageNote(providerID: "cursor", text: "line1\nline2", recordedAt: now))
        XCTAssertNil(ConsumerUsageNote(providerID: "cursor", text: String(repeating: "A", count: 121), recordedAt: now))
        XCTAssertEqual(ConsumerUsageNote(providerID: "gemini", text: " 5h 64% ", recordedAt: now)?.text, "5h 64%")
    }

    func testManualObservationIsNotLiveQuota() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let note = try XCTUnwrap(ConsumerUsageNote(providerID: "chatgpt", text: "Pro resets tomorrow", recordedAt: now))
        XCTAssertTrue(note.isRecent(at: now.addingTimeInterval(3500)))
        XCTAssertFalse(note.isRecent(at: now.addingTimeInterval(3601)))
        XCTAssertFalse(note.isRecent(at: now.addingTimeInterval(-1)))
        let roundtrip = try JSONDecoder().decode(ConsumerUsageNote.self, from: JSONEncoder().encode(note))
        XCTAssertEqual(roundtrip, note)
    }
}
