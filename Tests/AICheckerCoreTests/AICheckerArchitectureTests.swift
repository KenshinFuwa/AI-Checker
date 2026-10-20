import XCTest
@testable import AICheckerCore

final class AICheckerArchitectureTests: XCTestCase {
    func testNoArtificialLeadingSpace() {
        XCTAssertEqual(CompactLayout.imageLeftPadding, 0)
        XCTAssertEqual(CompactLayout.width(segments: [100, 100]), 203)
        XCTAssertEqual(CompactLayout.width(segments: [100, 100], gap: 0), 200)
    }
    func testCatalogDedupeAndSourceID() {
        let a = AIProviderDescriptor(id: "example", name: "Example", shortName: "Ex", sourceID: "custom")
        XCTAssertEqual(AIProviderRegistry.ordered([a, a]).count, 1)
        XCTAssertEqual(AIProviderRegistry.builtins.map(\.sourceID), ["official-codex-app-server", "claude-web-experimental-or-statusline"])
    }
    func testMigratesBothAndCustomizations() {
        var legacy = DisplayPreferences()
        legacy.selection = .claude
        legacy.metricStyle = .percentOnly
        legacy.claudeTint = .violet
        let p = AICheckerSettings.migrated(from: legacy)
        XCTAssertEqual(p.visibleProviderIDs, ["claude"])
        XCTAssertEqual(p.metricStyle, .percentOnly)
        XCTAssertEqual(p.tints["claude"], .violet)
    }
    func testVisibleProvidersUseRegistryOrder() {
        let catalog = AIProviderRegistry.builtins + [AIProviderDescriptor(id: "other", name: "Other", shortName: "Ot", sourceID: "other")]
        let p = AICheckerSettings(visibleProviderIDs: ["other", "claude"])
        XCTAssertEqual(p.visibleProviders(in: catalog).map(\.id), ["claude", "other"])
    }
    func testSettingsStorageAndGapClamping() throws {
        var p = AICheckerSettings()
        p.setVisible("codex", false)
        p.setVisible("other", true)
        p.setGap(-10)
        XCTAssertEqual(p.providerGap, 0)
        p.setGap(100)
        XCTAssertEqual(p.providerGap, 12)
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(AICheckerSettings.self, from: data), p)
    }
    func testMissingDataIsNotZero() {
        let snapshot = AIQuotaSnapshot(providerID: "sample", fiveHour: QuotaWindow(remainingPercent: nil, resetsAt: nil), weekly: QuotaWindow(remainingPercent: 0, resetsAt: nil), updatedAt: nil, source: nil)
        XCTAssertNil(snapshot.fiveHour.remainingPercent)
        XCTAssertEqual(snapshot.weekly.remainingPercent, 0)
        XCTAssertNil(ProviderMerge.merge([["other": snapshot]])["other"])
        XCTAssertEqual(ProviderMerge.merge([["sample": snapshot]])["sample"]?.weekly.remainingPercent, 0)
    }
}
