import Foundation
import AICheckerCore

@main
struct MockIntegration {
    static func main() {
        guard let fixture = ProcessInfo.processInfo.environment["MOCK_CODEX"] else { fatalError("Missing MOCK_CODEX") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aichecker-bridge-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = CodexAccountClient(profile: AICheckerAccount(providerID: "codex", label: "Sandbox"),
                                       executableOverride: URL(fileURLWithPath: fixture),
                                       homeOverride: root.appendingPathComponent("AI Checker/CodexAccounts/mock"))
        var openedURL = false
        var gotQuota = false
        var quotaEvents = 0
        client.onState = { message in
            print("STATE: \(message)")
        }
        client.onOpenBrowser = { url in
            assert(url.host == "chatgpt.com")
            openedURL = true
        }
        client.onSnapshot = { snapshot in
            if snapshot?.fiveHour.remainingPercent == 90 && snapshot?.weekly.remainingPercent == 80 {
                gotQuota = true
                quotaEvents += 1
            }
        }
        client.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { client.login() }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && !(gotQuota && openedURL) {
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        guard gotQuota && openedURL else { fatalError("RPC integration did not complete: URL=\(openedURL) quota=\(gotQuota)") }

        // A forced refresh restarts the connection and reuses mock-only login.
        client.refreshUsage(force: true)
        let forcedDeadline = Date().addingTimeInterval(6)
        while Date() < forcedDeadline && quotaEvents < 2 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        guard quotaEvents >= 2 else { fatalError("Manual refresh did not recover Codex RPC") }

        // A regular timer refresh must also recover a stopped transport.
        client.stopAndWait()
        client.refreshUsage(force: false)
        let periodicDeadline = Date().addingTimeInterval(6)
        while Date() < periodicDeadline && quotaEvents < 3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        client.stopAndWait()
        guard quotaEvents >= 3 else { fatalError("Periodic refresh did not recover stopped RPC") }
        print("PASS: isolated official Codex app-server handshake, login and quotas")
        print("PASS: manual and periodic refresh recover isolated Codex RPC without new login")
    }
}
