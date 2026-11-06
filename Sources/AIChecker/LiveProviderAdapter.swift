import Foundation

/// Live fetch boundary. New supported AI services implement this adapter and
/// register with the app's single scheduling loop. No per-service UI timer.
protocol LiveProviderAdapter: AnyObject {
    var providerID: String { get }
    func requestUsage(force: Bool)
}

extension CodexAccountClient: LiveProviderAdapter {
    var providerID: String { "codex" }
    func requestUsage(force: Bool) { refreshUsage(force: force) }
}

extension ClaudeWebSession: LiveProviderAdapter {
    var providerID: String { "claude" }
    func requestUsage(force: Bool) { poll(force: force) }
}
