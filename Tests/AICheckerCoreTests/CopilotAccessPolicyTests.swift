import XCTest
@testable import AICheckerCore

final class CopilotAccessPolicyTests: XCTestCase {
    func testUpgradeWithOldPATNeverSilentlyEnablesBillingAPI() {
        XCTAssertEqual(CopilotAccessMode.restored(nil), .undetermined)
        XCTAssertEqual(CopilotAccessMode.restored("invalid-legacy-value"), .undetermined)
        XCTAssertFalse(CopilotAccessMode.restored(nil).permitsPersonalBillingAPI)
    }

    func testNoPersonalSubscriptionAndFreeNeverUseBillingAPI() {
        XCTAssertFalse(CopilotAccessMode.freeOrNotSubscribed.permitsPersonalBillingAPI)
        XCTAssertTrue(CopilotAccessMode.freeOrNotSubscribed.menuLabel.contains("Free"))
        XCTAssertTrue(CopilotAccessMode.freeOrNotSubscribed.informationalStatus.contains("使用しません"))
    }

    func testOrganizationPlanNotMistakenForPersonalBilling() {
        XCTAssertFalse(CopilotAccessMode.organizationBilled.permitsPersonalBillingAPI)
    }

    func testOnlyExplicitPersonalBillingOptInEnablesAPI() {
        XCTAssertEqual(CopilotAccessMode.allCases.filter { $0.permitsPersonalBillingAPI }, [.personallyBilled])
        XCTAssertTrue(CopilotAccessMode.personallyBilled.permitsPersonalBillingAPI)
    }

    func testPersistedModeRoundTripAndIndependentProviders() throws {
        for value in CopilotAccessMode.allCases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(CopilotAccessMode.self, from: data)
            XCTAssertEqual(value, decoded)
            XCTAssertEqual(CopilotAccessMode.restored(value.rawValue), value)
        }
        XCTAssertTrue(AIProviderRegistry.isImplemented("codex"))
        XCTAssertTrue(AIProviderRegistry.isImplemented("claude"))
    }
}
