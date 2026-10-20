import XCTest
@testable import AICheckerCore

final class UsageMenuPresentationTests: XCTestCase {
    func testOneFullWidthCardPerProvider() {
        XCTAssertEqual(UsageMenuPresentation.providerCardWidth, 580)
        XCTAssertEqual(UsageMenuPresentation.providerCardHeight, 120)
    }

    func testFullWidthSingleRowPerQuotaNoDuplicateLabels() {
        XCTAssertEqual(UsageMenuPresentation.meterWidth, 215)
        XCTAssertEqual(UsageMenuPresentation.rowLabels, ["5 hours", "Week"])
        XCTAssertEqual(UsageMenuPresentation.resetCaption, "RESETS IN")
        XCTAssertGreaterThan(UsageMenuPresentation.durationMinX,
                             UsageMenuPresentation.percentX + 40)
        XCTAssertLessThan(UsageMenuPresentation.meterX + UsageMenuPresentation.meterWidth,
                          UsageMenuPresentation.percentX)
        XCTAssertLessThan(UsageMenuPresentation.durationRightX,
                          UsageMenuPresentation.providerCardWidth - 10)
    }

    func testHeaderCaptionAndCountdownShareOneRightEdge() {
        XCTAssertEqual(UsageMenuPresentation.resetCaptionRightX,
                       UsageMenuPresentation.durationRightX)
        XCTAssertGreaterThan(UsageMenuPresentation.resetCaptionRightX,
                             UsageMenuPresentation.durationMinX)
        XCTAssertLessThan(UsageMenuPresentation.resetCaptionRightX,
                          UsageMenuPresentation.providerCardWidth - 10)
    }

    func testHeaderIconAndProviderNameShareCenterline() {
        // The custom native view centers BOTH text and image on headerCenterY.
        XCTAssertEqual(UsageMenuPresentation.headerCenterY, 90)
        XCTAssertGreaterThan(UsageMenuPresentation.headerTitleX,
                             UsageMenuPresentation.headerIconX + UsageMenuPresentation.headerIconSize)
        XCTAssertGreaterThan(UsageMenuPresentation.headerCenterY - UsageMenuPresentation.headerIconSize / 2,
                             UsageMenuPresentation.dividerY)
        XCTAssertLessThan(UsageMenuPresentation.headerCenterY + UsageMenuPresentation.headerIconSize / 2,
                          UsageMenuPresentation.providerCardHeight - 5)
    }

    func testRowsHaveCommonCenterlinesAndDoNotOverlapHeader() {
        XCTAssertGreaterThan(UsageMenuPresentation.dividerY,
                             UsageMenuPresentation.fiveHourRowCenterY + 4)
        XCTAssertGreaterThan(UsageMenuPresentation.fiveHourRowCenterY - 8,
                             UsageMenuPresentation.weekRowCenterY + 8)
        XCTAssertGreaterThan(UsageMenuPresentation.weekRowCenterY - 8, 5)
    }

    func testUnknownIsNotZeroOrHundredPercent() {
        XCTAssertEqual(UsageMenuPresentation.percentage(nil), "—")
        XCTAssertEqual(UsageMenuPresentation.percentage(Double.nan), "—")
        XCTAssertEqual(UsageMenuPresentation.percentage(101), "—")
        XCTAssertEqual(UsageMenuPresentation.percentage(-3), "—")
        XCTAssertEqual(UsageMenuPresentation.fillFraction(nil), 0)
    }

    func testValidFractions() {
        XCTAssertEqual(UsageMenuPresentation.percentage(16.3), "16%")
        XCTAssertEqual(UsageMenuPresentation.percentage(58.9), "59%")
        XCTAssertEqual(UsageMenuPresentation.fillFraction(50), 0.5)
        XCTAssertEqual(UsageMenuPresentation.fillFraction(100), 1)
    }

    func testFreshnessAndFailuresHaveDifferentLabels() {
        XCTAssertEqual(UsageMenuPresentation.stateLabel(hasSnapshot: false, hasFailure: false, isFresh: false), "未取得")
        XCTAssertEqual(UsageMenuPresentation.stateLabel(hasSnapshot: true, hasFailure: false, isFresh: true), "更新済み")
        XCTAssertEqual(UsageMenuPresentation.stateLabel(hasSnapshot: true, hasFailure: false, isFresh: false), "古い記録")
        XCTAssertEqual(UsageMenuPresentation.stateLabel(hasSnapshot: true, hasFailure: true, isFresh: true), "要確認")
    }
}
