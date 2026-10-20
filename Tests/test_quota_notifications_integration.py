#!/usr/bin/env python3
"""Static macOS UI / notification wiring contracts; no user state or network access."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text()


class QuotaNotificationIntegration(unittest.TestCase):
    def test_settings_stay_in_native_nested_menu(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('addQuotaNotificationMenu(to: menu)', main)
        settings = main.split('private func addQuotaNotificationMenu(', 1)[1].split('private func addDisplaySettingsMenu(', 1)[0]
        self.assertIn('NSMenu(title: "通知設定")', settings)
        self.assertIn('addStayOpenRow("5時間・週間のリセット時に通知"', settings)
        self.assertIn('addStayOpenRow("5時間・週間の残量を使い切ったら通知"', settings)
        self.assertIn('テスト通知を送る', settings)
        self.assertNotIn('NSWindow(', settings)

    def test_two_public_quota_ingest_paths(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('self.observeQuota(sample, accountID: profile.id)', main)
        self.assertNotIn('self.observeQuota(snapshot, accountID: profile.id)', main)
        self.assertIn('self.observeQuota(fresh, accountID: accountID)', main)
        self.assertNotIn('observeQuota(note', main)

    def test_permissions_opt_in_and_native_notifications_only(self):
        main = source('Sources/AIChecker/main.swift')
        native = source('Sources/AIChecker/QuotaNotificationCenter.swift')
        core = source('Sources/AICheckerCore/QuotaNotifications.swift')
        self.assertIn('private var quotaNotificationSettings = QuotaNotificationPreferences()', main)
        self.assertIn('if permitted {', main)
        self.assertIn('requestAuthorization(options: [.alert, .sound])', native)
        self.assertIn('UNMutableNotificationContent()', native)
        self.assertIn('UNUserNotificationCenterDelegate', native)
        self.assertIn('TelemetryFreshness.isRecent', core)
        self.assertIn('observedAt > old.observedAt', core)
        self.assertNotIn('Timer(', native + core)
        self.assertNotIn('URLSession', native + core)

    def test_changed_feature_does_not_touch_original_account_or_usage_paths(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('ClaudeStatusLineSource(profileID: profileID)', main)
        self.assertIn('connectSelectedAccount()', main)
        self.assertIn('Codexアカウント管理', main)
        self.assertIn('AIサービスを追加…', main)
        self.assertNotIn('notifyOnReset = true\n    private', main)


if __name__ == '__main__':
    unittest.main(verbosity=2)
