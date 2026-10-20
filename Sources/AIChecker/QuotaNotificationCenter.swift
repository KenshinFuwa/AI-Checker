import Foundation
import UserNotifications
import AICheckerCore

/// Native macOS notification delivery; no LaunchAgent, background helper or poller.
/// Uses notifications only after a user explicitly enables a notification option.
final class QuotaNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async { completion(granted && error == nil) }
        }
    }

    func deliver(_ event: QuotaNotificationEvent) {
        let provider = event.providerID == "codex" ? "Codex" : "Claude"
        let content = UNMutableNotificationContent()
        content.title = "AI Checker · \(provider)"
        switch event.kind {
        case .reset:
            content.body = "\(event.window.label)の制限がリセットされました（残り\(Int(event.remainingPercent.rounded()))%）"
        case .exhausted:
            content.body = "\(event.window.label)の利用可能枠を使い切りました"
        }
        content.sound = .default
        // Actual unique transitions are already deduplicated by the monitor.
        let request = UNNotificationRequest(identifier: "AIChecker.quota.\(UUID().uuidString)",
                                            content: content, trigger: nil)
        center.add(request) { error in
            if let error { NSLog("AI Checker: quota notification failed: %@", error.localizedDescription) }
        }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "AI Checker · 通知テスト"
        content.body = "通知の準備ができました。残量の変化は実データから判定します。"
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "AIChecker.test.\(UUID().uuidString)",
                                         content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
