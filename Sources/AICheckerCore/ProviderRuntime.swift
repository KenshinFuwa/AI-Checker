import Foundation

// The monitor stores no tokens, cookies, or raw HTTP responses.
// All timestamps are injected so sleep/retry policies are deterministic under test.
public enum ProviderAuthState: String, Codable, Sendable {
    case disconnected, authenticating, connected, reauthenticationRequired, unsupported
}

public enum ProviderErrorKind: String, Codable, Sendable {
    case authenticationRequired, rateLimited, networkUnavailable, timedOut
    case invalidResponse, permissionDenied, resourceUnavailable, serverUnavailable, unsupported, unknown
}

public struct ProviderFailure: Equatable, Sendable {
    public let kind: ProviderErrorKind
    public let retryAfter: TimeInterval?

    public init(_ kind: ProviderErrorKind, retryAfter: TimeInterval? = nil) {
        self.kind = kind
        self.retryAfter = retryAfter.flatMap { $0.isFinite && $0 >= 0 ? min($0, 3600) : nil }
    }

    public static func http(_ status: Int, retryAfter: TimeInterval? = nil) -> ProviderFailure {
        switch status {
        case 401: return .init(.authenticationRequired)
        case 403: return .init(.permissionDenied)
        case 404: return .init(.resourceUnavailable)
        case 408, 504: return .init(.timedOut)
        case 429: return .init(.rateLimited, retryAfter: retryAfter)
        case 500...599: return .init(.serverUnavailable)
        default: return .init(.invalidResponse)
        }
    }

    public var displayMessage: String {
        switch kind {
        case .authenticationRequired: return "認証失敗（HTTP 401）：トークンを確認"
        case .permissionDenied: return "権限不足または利用対象外（HTTP 403）"
        case .resourceUnavailable: return "対象の利用状況が見つかりません（HTTP 404）"
        case .rateLimited: return "取得制限中（自動で再試行）"
        case .networkUnavailable: return "ネットワークに接続できません"
        case .timedOut: return "応答がタイムアウトしました"
        case .invalidResponse: return "使用率の形式を解釈できません"
        case .serverUnavailable: return "サービス側の一時的な障害"
        case .unsupported: return "使用率取得に未対応"
        case .unknown: return "利用状況の取得に失敗しました"
        }
    }
}

public struct ProviderRefreshResult: Equatable, Sendable {
    public let providerID: String
    public let authState: ProviderAuthState
    public let snapshot: AIQuotaSnapshot?
    public let failure: ProviderFailure?
    public init(providerID: String, authState: ProviderAuthState, snapshot: AIQuotaSnapshot? = nil,
                failure: ProviderFailure? = nil) {
        self.providerID = providerID
        self.authState = authState
        self.snapshot = snapshot
        self.failure = failure
    }
}

/// Adapter contract: mocks use this in tests; live bridges invoke the existing
/// Codex App Server / Claude WebKit clients without changing their credentials.
public protocol UsageProviderAdapter {
    var providerID: String { get }
    func refresh(force: Bool) async -> ProviderRefreshResult
}

public struct ProviderRuntime: Equatable, Sendable {
    public var auth: ProviderAuthState = .disconnected
    public var lastSuccess: Date?
    public var lastAttempt: Date?
    public var lastFailure: ProviderFailure?
    public var consecutiveFailures = 0
    public var nextEligibleAt: Date = .distantPast
    public init() {}
}

public protocol ProviderClock {
    func now() -> Date
}
public struct SystemProviderClock: ProviderClock {
    public init() {}
    public func now() -> Date { Date() }
}

public struct ProviderRefreshCoordinator: Sendable {
    public private(set) var sleeping = false
    public private(set) var states: [String: ProviderRuntime] = [:]
    public let interval: TimeInterval
    public let ttl: TimeInterval

    public init(interval: TimeInterval = 60, ttl: TimeInterval = 180) {
        self.interval = interval
        self.ttl = ttl
    }

    public mutating func reset(_ providerID: String) { states.removeValue(forKey: providerID) }
    public mutating func sleep() { sleeping = true }
    public mutating func wake() {
        sleeping = false
        // Wake triggers one immediate attempt, except when the server has
        // specifically imposed a 429 retry-after window.
        for key in states.keys {
            if states[key]?.lastFailure?.kind != .rateLimited {
                states[key]?.nextEligibleAt = .distantPast
                states[key]?.lastAttempt = nil
            }
        }
    }

    public mutating func begin(_ providerID: String, now: Date, forced: Bool = false) -> Bool {
        guard !sleeping else { return false }
        var state = states[providerID] ?? ProviderRuntime()
        if state.auth == .unsupported { return false }
        if state.auth == .reauthenticationRequired && !forced { return false }
        // A manual refresh can bypass exponential network retry, not an HTTP 429.
        let inCooldown = now < state.nextEligibleAt
        if inCooldown && (!forced || state.lastFailure?.kind == .rateLimited) { return false }
        if !forced, let last = state.lastAttempt, now.timeIntervalSince(last) < interval { return false }
        state.lastAttempt = now
        states[providerID] = state
        return true
    }

    public mutating func succeed(_ providerID: String, now: Date) {
        var state = states[providerID] ?? ProviderRuntime()
        state.auth = .connected
        state.lastSuccess = now
        state.lastAttempt = now
        state.lastFailure = nil
        state.consecutiveFailures = 0
        state.nextEligibleAt = now.addingTimeInterval(interval)
        states[providerID] = state
    }

    public mutating func fail(_ providerID: String, failure: ProviderFailure, now: Date) {
        var state = states[providerID] ?? ProviderRuntime()
        state.lastAttempt = now
        state.lastFailure = failure
        state.consecutiveFailures = min(state.consecutiveFailures + 1, 100)
        switch failure.kind {
        case .authenticationRequired: state.auth = .reauthenticationRequired
        case .unsupported: state.auth = .unsupported
        default: break
        }
        let delays: [TimeInterval] = [interval, 120, 300, 600]
        let backoff = delays[min(state.consecutiveFailures - 1, delays.count - 1)]
        let delay = max(backoff, failure.retryAfter ?? 0)
        state.nextEligibleAt = now.addingTimeInterval(delay)
        states[providerID] = state
    }

    public mutating func setAuth(_ providerID: String, _ auth: ProviderAuthState) {
        var state = states[providerID] ?? ProviderRuntime()
        state.auth = auth
        if auth == .reauthenticationRequired { state.lastFailure = .init(.authenticationRequired) }
        states[providerID] = state
    }

    public func isFresh(_ providerID: String, now: Date) -> Bool {
        guard let lastSuccess = states[providerID]?.lastSuccess else { return false }
        let age = now.timeIntervalSince(lastSuccess)
        return age >= -60 && age <= ttl
    }
}
