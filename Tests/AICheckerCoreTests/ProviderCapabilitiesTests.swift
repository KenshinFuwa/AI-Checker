import XCTest
@testable import AICheckerCore

final class ProviderCapabilitiesTests: XCTestCase {
    func testCatalogMakesUnsupportedServicesExplicit() {
        XCTAssertEqual(AIProviderRegistry.capability(for: "codex"), .fiveHourAndWeekly)
        XCTAssertEqual(AIProviderRegistry.capability(for: "claude"), .fiveHourAndWeekly)
        XCTAssertEqual(AIProviderRegistry.capability(for: "copilot"), .billedMonthlyRequests)
        for id in ["cursor", "grok", "openai-api"] {
            XCTAssertEqual(AIProviderRegistry.capability(for: id), .apiUsageReport)
        }
        for id in ["chatgpt", "gemini", "perplexity"] {
            XCTAssertEqual(AIProviderRegistry.capability(for: id), .notAvailable)
            XCTAssertFalse(AIProviderRegistry.isImplemented(id))
        }
    }

    func testNoInventedRemainingPercentForUnpublishedLimit() {
        let requestCount = ProviderMeter(providerID: "copilot", label: "Premium Requests", used: 100, limit: nil, unit: "requests")
        XCTAssertNotNil(requestCount)
        XCTAssertNil(requestCount?.remainingPercent)
        XCTAssertEqual(ProviderMeter(providerID: "codex", label: "5h", used: 25, limit: 100, unit: "%")?.remainingPercent, 75)
    }

    func testInvalidMetersFailClosed() {
        XCTAssertNil(ProviderMeter(providerID: "copilot", label: "monthly", used: -1, limit: nil, unit: "requests"))
        XCTAssertNil(ProviderMeter(providerID: "copilot", label: "monthly", used: .nan, limit: nil, unit: "requests"))
        XCTAssertNil(ProviderMeter(providerID: "copilot", label: "monthly", used: 1, limit: 0, unit: "requests"))
    }
}
