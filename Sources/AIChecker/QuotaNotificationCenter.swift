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

    /// Read system authorization separately from AI Checker's own switches.
    /// Permission granted does NOT guarantee a visible banner: Focus, per-app
    /// banners, sounds, and notification summaries are controlled by macOS.
    func describeSystemSettings(completion: @escaping (String) -> Void) {
        center.getNotificationSettings { settings in
            let authorization: String
            switch settings.authorizationStatus {
            case .authorized: authorization = "許可済み"
            case .denied: authorization = "拒否されています"
            case .notDetermined: authorization = "未確認（許可を求めていません）"
            case .provisional: authorization = "仮許可（通知が静かに届く場合があります）"
            case .ephemeral: authorization = "一時的に許可"
            @unknown default: authorization = "不明"
            }
            let banner: String
            switch settings.alertStyle {
            case .banner: banner = "バナー"
            case .alert: banner = "通知パネル"
            case .none: banner = "画面表示なし"
            @unknown default: banner = "不明"
            }
            let sound = settings.soundSetting == .enabled ? "ON" : "OFF"
            let centerSetting = settings.notificationCenterSetting == .enabled ? "ON" : "OFF"
            let result = "macOS通知許可: \(authorization)\n表示形式: \(banner)\n通知センター: \(centerSetting)\n通知音: \(sound)\n\n集中モードや通知要約の設定により、許可済みでもバナーが表示されない場合があります。"
            DispatchQueue.main.async { completion(result) }
        }
    }

    func sendTestNotification(completion: @escaping (Error?) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "AI Checker · 通知テスト"
        content.body = "通知の準備ができました。残量の変化は実データから判定します。"
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "AIChecker.test.\(UUID().uuidString)",
                                         content: content, trigger: nil)) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
