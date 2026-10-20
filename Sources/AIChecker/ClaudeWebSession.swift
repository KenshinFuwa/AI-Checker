import Foundation
import WebKit
import AICheckerCore

/// Public-source compatibility type. Claude's undocumented website quota
/// endpoint is NOT accessed or implemented in this distribution.
/// The source-only public beta uses Claude Code's user-enabled statusLine.
final class ClaudeWebSession: NSObject {
    let profileID: UUID
    var onSnapshot: ((AIQuotaSnapshot) -> Void)?
    var onState: ((String) -> Void)?
    var onFailure: ((ProviderFailure) -> Void)?
    var canPoll: (() -> Bool)?
    init(profileID: UUID) { self.profileID = profileID }
    func begin() { onState?("Public beta: Claude Code statusLine only") }
    func showLoginWindow() { onState?("Public beta: Claude Code statusLine only") }
    func poll(force: Bool = false) { /* Deliberately no network requests. */ }
    func stop() {}
    static func eraseProfile(_ profileID: UUID, completion: @escaping (Error?) -> Void) {
        if #available(macOS 14.0, *) {
            WKWebsiteDataStore.remove(forIdentifier: profileID, completionHandler: completion)
        } else { completion(nil) }
    }
}
