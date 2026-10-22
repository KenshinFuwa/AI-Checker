import Foundation

/// A two-interval throughput average. Samples are supplied only while the
/// root USAGE menu is open; this type never schedules work itself.
public struct TwoSecondNetworkAverage {
    public struct Sample: Equatable {
        public let interface: String
        public let downBitsPerSecond: Double
        public let upBitsPerSecond: Double

        public init(interface: String, downBitsPerSecond: Double, upBitsPerSecond: Double) {
            self.interface = interface
            self.downBitsPerSecond = downBitsPerSecond
            self.upBitsPerSecond = upBitsPerSecond
        }
    }

    public enum Result {
        case average(Sample)
        case unavailable
    }

    private var sampleCount = 0
    private var interface: String?
    private var totalSeconds = 0.0
    private var downBitTotal = 0.0
    private var upBitTotal = 0.0
    private var invalid = false

    public init() {}

    /// Pass a single measured interval each second. Exactly every second
    /// interval produces a result (weighted by actual elapsed time).
    /// A missing interval or interface change invalidates that window rather
    /// than fabricating a rate. Invalid elapsed values also fail closed.
    public mutating func append(_ sample: Sample?, elapsed: TimeInterval) -> Result? {
        sampleCount += 1
        if let sample,
           !sample.interface.isEmpty,
           sample.downBitsPerSecond.isFinite, sample.downBitsPerSecond >= 0,
           sample.upBitsPerSecond.isFinite, sample.upBitsPerSecond >= 0,
           elapsed.isFinite, (0.35...2.0).contains(elapsed) {
            if let existing = interface, existing != sample.interface {
                invalid = true
            }
            interface = sample.interface
            downBitTotal += sample.downBitsPerSecond * elapsed
            upBitTotal += sample.upBitsPerSecond * elapsed
            totalSeconds += elapsed
        } else {
            invalid = true
        }
        guard sampleCount == 2 else { return nil }
        let result: Result
        if !invalid, let interface, totalSeconds > 0 {
            result = .average(Sample(interface: interface,
                                     downBitsPerSecond: downBitTotal / totalSeconds,
                                     upBitsPerSecond: upBitTotal / totalSeconds))
        } else {
            result = .unavailable
        }
        self = TwoSecondNetworkAverage()
        return result
    }
}
