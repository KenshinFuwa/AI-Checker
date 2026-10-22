#!/usr/bin/env python3
"""Notification settings and 2-second on-demand speed contracts."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class NotificationAndSpeedContracts(unittest.TestCase):
    def test_menu_exposes_system_and_app_notification_diagnostics(self):
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        impl=(ROOT/'Sources/AIChecker/QuotaNotificationCenter.swift').read_text()
        self.assertIn('通知状態を確認…', main)
        self.assertIn('describeSystemSettings', main)
        self.assertIn('getNotificationSettings', impl)
        self.assertIn('settings.alertStyle', impl)
        self.assertIn('settings.soundSetting', impl)
        self.assertIn('settings.notificationCenterSetting', impl)
        self.assertIn('sendTestNotification(completion:', impl)
        self.assertIn('error.localizedDescription', main)
        self.assertIn('self.quotaNotificationSettings.notifyOnReset', main)
        self.assertIn('self.quotaNotificationSettings.notifyOnExhaustion', main)

    def test_two_second_weighted_average_only_with_menu_open(self):
        sampler=(ROOT/'Sources/AIChecker/OnDemandNetworkSpeed.swift').read_text()
        core=(ROOT/'Sources/AICheckerCore/TwoSecondNetworkAverage.swift').read_text()
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        self.assertIn('.milliseconds(500)',sampler)
        self.assertIn('repeating: .seconds(1)',sampler)
        self.assertIn('guard sampleCount == 2 else { return nil }',core)
        self.assertIn('downBitTotal / totalSeconds',core)
        self.assertIn('startMenuNetworkSpeed()',main)
        self.assertIn('networkSpeed.stop()',main)
        self.assertNotIn('ThreeSecondNetworkAverage',sampler)

if __name__=='__main__': unittest.main(verbosity=2)
