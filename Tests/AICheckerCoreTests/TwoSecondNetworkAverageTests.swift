import XCTest
@testable import AICheckerCore

final class TwoSecondNetworkAverageTests: XCTestCase {
    private func sample(_ down: Double, _ up: Double = 0,
                        iface: String = "en0") -> TwoSecondNetworkAverage.Sample {
        .init(interface: iface, downBitsPerSecond: down, upBitsPerSecond: up)
    }

    func testPublishesOnlyAfterTwoIntervalsAndRestartsWindow() {
        var mean = TwoSecondNetworkAverage()
        XCTAssertNil(mean.append(sample(100), elapsed: 1))
        switch mean.append(sample(300), elapsed: 1) {
        case .average(let r): XCTAssertEqual(r.downBitsPerSecond, 200, accuracy: 0.001)
        default: XCTFail("Expected average after second sample")
        }
        XCTAssertNil(mean.append(sample(90), elapsed: 1))
        switch mean.append(sample(150), elapsed: 1) {
        case .average(let r): XCTAssertEqual(r.downBitsPerSecond, 120, accuracy: 0.001)
        default: XCTFail("Expected independent second window")
        }
    }

    func testElapsedWeightedAverageUsesRealSeconds() {
        var mean = TwoSecondNetworkAverage()
        XCTAssertNil(mean.append(sample(100, 50), elapsed: 0.9))
        switch mean.append(sample(200, 100), elapsed: 1.1) {
        case .average(let r):
            XCTAssertEqual(r.downBitsPerSecond, (90 + 220) / 2, accuracy: 0.001)
            XCTAssertEqual(r.upBitsPerSecond, (45 + 110) / 2, accuracy: 0.001)
        default: XCTFail("Expected weighted average")
        }
    }

    func testMissingOrInvalidIntervalNeverProducesFabricatedNumber() {
        var mean = TwoSecondNetworkAverage()
        XCTAssertNil(mean.append(sample(100), elapsed: 1))
        if case .unavailable? = mean.append(nil, elapsed: 1) {} else {
            XCTFail("Missing interval must invalidate the average")
        }
        XCTAssertNil(mean.append(sample(100), elapsed: 1))
        if case .unavailable? = mean.append(sample(300), elapsed: 5) {} else {
            XCTFail("Invalid elapsed interval must invalidate the average")
        }
    }

    func testInterfaceChangeInvalidatesWindow() {
        var mean = TwoSecondNetworkAverage()
        XCTAssertNil(mean.append(sample(100), elapsed: 1))
        if case .unavailable? = mean.append(sample(200, iface: "utun0"), elapsed: 1) {} else {
            XCTFail("Do not combine traffic across different interfaces")
        }
    }
}
