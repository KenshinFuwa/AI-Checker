import Foundation
import Darwin
import AICheckerCore

/// Menu-scoped, interface-local throughput sampler. Idle between menu opens.
/// First reading uses roughly 0.5 s, then samples every second and
/// displays a weighted two-second average every two further samples.
/// These are traffic counters, NOT a bandwidth or Speedtest measurement.
struct NetworkSpeedReading {
    let interface: String
    let downBitsPerSecond: Double
    let upBitsPerSecond: Double

    static func format(_ bitsPerSecond: Double) -> String {
        guard bitsPerSecond.isFinite, bitsPerSecond >= 0 else { return "—" }
        let units = ["bps", "Kbps", "Mbps", "Gbps"]
        var number = bitsPerSecond
        var unit = 0
        while number >= 1000 && unit < units.count - 1 {
            number /= 1000
            unit += 1
        }
        return String(format: number >= 100 ? "%.0f %@" : number >= 10 ? "%.1f %@" : "%.2f %@",
                      number, units[unit])
    }
}

enum NetworkSpeedOutcome {
    case reading(NetworkSpeedReading)
    case unavailable
}

final class OnDemandNetworkSpeed {
    private struct Counters {
        let receive: UInt32
        let transmit: UInt32
    }

    // Kept exclusively on the sampler queue; no cross-thread baseline reads.
    private final class Baseline {
        var counters: [String: Counters]?
        var uptime: TimeInterval = 0
        var firstReadingComplete = false
        var average = TwoSecondNetworkAverage()
    }

    private let queue = DispatchQueue(label: "AI Checker.network.menu", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var generation: UInt64 = 0

    /// Call only when the *root* USAGE menu becomes visible. Does nothing if
    /// tracking is already active, so submenus cannot create extra samplers.
    /// All callbacks are on the main thread.
    func start(completion: @escaping (NetworkSpeedOutcome) -> Void) {
        assert(Thread.isMainThread)
        guard timer == nil else { return }
        generation &+= 1
        let token = generation
        let baseline = Baseline()

        // The first read precedes the first 0.5-second timer event on the
        // serial sampling queue. Subsequent samples are one second apart.
        queue.async {
            baseline.counters = Self.read()
            baseline.uptime = ProcessInfo.processInfo.systemUptime
        }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + .milliseconds(500),
                        repeating: .seconds(1), leeway: .milliseconds(60))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let latest = Self.read()
            let uptime = ProcessInfo.processInfo.systemUptime
            let elapsed = uptime - baseline.uptime
            let interval: NetworkSpeedOutcome
            if let old = baseline.counters, let latest {
                interval = Self.calculate(start: old, finish: latest, elapsed: elapsed)
            } else {
                interval = .unavailable
            }
            baseline.counters = latest
            baseline.uptime = uptime

            // Initial sample: show immediately after the 0.5-second sample.
            // Later samples: continue reading at 1 Hz, only publish the
            // weighted average after each TWO full one-second intervals.
            let publish: NetworkSpeedOutcome?
            if !baseline.firstReadingComplete {
                baseline.firstReadingComplete = true
                publish = interval
            } else {
                let input: TwoSecondNetworkAverage.Sample?
                switch interval {
                case .reading(let value):
                    input = .init(interface: value.interface,
                                  downBitsPerSecond: value.downBitsPerSecond,
                                  upBitsPerSecond: value.upBitsPerSecond)
                case .unavailable:
                    input = nil
                }
                if let completed = baseline.average.append(input, elapsed: elapsed) {
                    switch completed {
                    case .average(let value):
                        publish = .reading(NetworkSpeedReading(interface: value.interface,
                            downBitsPerSecond: value.downBitsPerSecond,
                            upBitsPerSecond: value.upBitsPerSecond))
                    case .unavailable:
                        publish = .unavailable
                    }
                } else {
                    publish = nil
                }
            }
            guard let publish else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.timer != nil, self.generation == token else { return }
                completion(publish)
            }
        }
        timer = source
        source.resume()
    }

    /// Cancels future ticks when the menu closes or the Mac sleeps. In-flight
    /// callbacks are invalidated by the generation token and never touch UI.
    func stop() {
        assert(Thread.isMainThread)
        generation &+= 1
        timer?.cancel()
        timer = nil
    }

    private static func read() -> [String: Counters]? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return nil }
        defer { if let head { freeifaddrs(head) } }
        var result: [String: Counters] = [:]
        var p = head
        while let current = p {
            let entry = current.pointee
            defer { p = entry.ifa_next }
            guard let namePointer = entry.ifa_name,
                  let address = entry.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_LINK,
                  entry.ifa_flags & UInt32(IFF_UP) != 0,
                  let raw = entry.ifa_data else { continue }
            let name = String(cString: namePointer)
            // One physical interface is preferred over virtual/VPN interfaces.
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") ||
                  name.hasPrefix("utun") || name.hasPrefix("ppp") else { continue }
            let data = UnsafeRawPointer(raw).assumingMemoryBound(to: if_data.self).pointee
            result[name] = Counters(receive: UInt32(data.ifi_ibytes),
                                    transmit: UInt32(data.ifi_obytes))
        }
        return result
    }

    private static func calculate(start: [String: Counters], finish: [String: Counters],
                                  elapsed: TimeInterval) -> NetworkSpeedOutcome {
        guard elapsed >= 0.35 && elapsed <= 2 else { return .unavailable }
        var readings: [NetworkSpeedReading] = []
        for (name, current) in finish {
            guard let previous = start[name] else { continue }
            let incoming = Double(current.receive &- previous.receive) / elapsed
            let outgoing = Double(current.transmit &- previous.transmit) / elapsed
            // Avoid reporting a reset of the 32-bit counters as real throughput.
            guard incoming <= 2_000_000_000, outgoing <= 2_000_000_000 else { continue }
            readings.append(NetworkSpeedReading(interface: name,
                         downBitsPerSecond: incoming * 8,
                         upBitsPerSecond: outgoing * 8))
        }
        // Do not sum en0 + utun0 (the same packets may traverse both).
        let physical = readings.filter { $0.interface.hasPrefix("en") || $0.interface.hasPrefix("pdp_ip") }
        let candidates = physical.isEmpty ? readings : physical
        guard let chosen = candidates.max(by: {
            $0.downBitsPerSecond + $0.upBitsPerSecond < $1.downBitsPerSecond + $1.upBitsPerSecond
        }) else { return .unavailable }
        return .reading(chosen)
    }
}
