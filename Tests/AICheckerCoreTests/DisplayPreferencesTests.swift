import XCTest
@testable import AICheckerCore

final class DisplayPreferencesTests: XCTestCase {
    func testDefaultIsBackwardsCompatible() {
        let prefs = DisplayPreferences()
        XCTAssertEqual(prefs.selection, .both)
        XCTAssertEqual(prefs.nameStyle, .full)
        XCTAssertEqual(prefs.barSize, .standard)
        XCTAssertEqual(prefs.metricStyle, .barsAndPercent)
        XCTAssertEqual(prefs.codexTint, .original)
        XCTAssertEqual(prefs.claudeTint, .original)
    }

    func testProviderVisibility() {
        XCTAssertEqual(ProviderSelection.both.providers, [.codex, .claude])
        XCTAssertEqual(ProviderSelection.codex.providers, [.codex])
        XCTAssertEqual(ProviderSelection.claude.providers, [.claude])
    }

    func testBarWidths() {
        XCTAssertEqual(BarSize.compact.width, 45)
        XCTAssertEqual(BarSize.standard.width, 66)
        XCTAssertEqual(BarSize.wide.width, 90)
    }

    func testMetricStyles() {
        XCTAssertTrue(MetricStyle.barsAndPercent.showBars)
        XCTAssertTrue(MetricStyle.barsAndPercent.showPercent)
        XCTAssertFalse(MetricStyle.barsOnly.showPercent)
        XCTAssertFalse(MetricStyle.percentOnly.showBars)
    }

    func testSettingsSerializationRoundTrip() throws {
        var prefs = DisplayPreferences()
        prefs.selection = .claude
        prefs.barSize = .wide
        prefs.nameStyle = .short
        prefs.metricStyle = .barsOnly
        prefs.codexTint = .gold
        prefs.claudeTint = .violet
        let bytes = try JSONEncoder().encode(prefs)
        XCTAssertEqual(try JSONDecoder().decode(DisplayPreferences.self, from: bytes), prefs)
    }

    func testIconModePersistsAndLegacyPreferenceStillDecodes() throws {
        var settings = AICheckerSettings()
        settings.nameStyle = .icon
        settings.setGap(0)
        let bytes = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AICheckerSettings.self, from: bytes)
        XCTAssertEqual(decoded.nameStyle, .icon)
        XCTAssertEqual(decoded.providerGap, 0)
        let old = #"{"visibleProviderIDs":["codex","claude"],"nameStyle":"short","barSize":"standard","metricStyle":"barsAndPercent","tints":{},"providerGap":3}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(AICheckerSettings.self, from: old).nameStyle, .short)
    }

    func testPlannedServicesNotShownByDefault() {
        let settings = AICheckerSettings()
        XCTAssertEqual(settings.visibleProviders(in: AIProviderRegistry.catalog).map(\.id), ["codex", "claude"])
    }

    func testInvalidRawValueDoesNotMapToValidColor() {
        XCTAssertNil(TintStyle(rawValue: "not-a-color"))
        XCTAssertNil(ProviderSelection(rawValue: "other"))
    }
}
