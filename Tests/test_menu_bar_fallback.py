#!/usr/bin/env python3
"""Static integration requirements for accessibility-free overflow recovery."""
from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
M=(R/'Sources/AIChecker/main.swift').read_text()
H=(R/'Sources/AIChecker/GlobalUsageHotkey.swift').read_text()
P=(R/'Sources/AIChecker/UsageQuickPanel.swift').read_text()
A=(R/'Sources/AIChecker/StatusArtwork.swift').read_text()

class MenuBarFallback(unittest.TestCase):
    def test_density_options(self):
        self.assertIn('case standard, compact, iconOnly', (R/'Sources/AIChecker/MenuBarPresentation.swift').read_text())
        self.assertIn('settings.metricStyle = .percentOnly', M)
        self.assertIn('settings.nameStyle = .icon', M)
        self.assertIn('StatusArtwork.renderLauncherIcon()', M)
        self.assertIn('statusItem(withLength: NSStatusItem.variableLength)', M)
    def test_fallback_is_real_window_not_fake_click(self):
        self.assertIn('NSPanel(', P)
        self.assertIn('panel.makeKeyAndOrderFront(nil)', P)
        self.assertIn('UsageDashboardMenuView(provider:', P)
        self.assertIn('GlobalUsageHotkey()', M)
        self.assertIn('--selftest-quick-access-layout', M)
        self.assertIn('GetApplicationEventTarget()', H)
        self.assertIn('RegisterEventHotKey(', H)
        self.assertNotIn('CGEvent',H)
        self.assertNotIn('AXIsProcessTrusted',M+H+P)
    def test_carbon_hotkey_uses_native_size_type_and_clean_sources(self):
        # Apple's macOS Swift import declares GetEventParameter's buffer size
        # parameter as Int. UInt32 here fails the *native* compiler even if
        # the same file passes Linux parser-only checks.
        self.assertIn('MemoryLayout<EventHotKeyID>.size, nil, &received)', H)
        self.assertNotIn('UInt32(MemoryLayout<EventHotKeyID>.size)', H)
        self.assertNotIn('UInt32(MemoryLayout<EventHotKeyID>.size)',
                         (R/'Sources/AIChecker/GlobalUsageHotkey.swift').read_text())
        junk=[p.relative_to(R).as_posix() for p in (R/'Sources').rglob('*')
              if p.is_file() and p.suffix.lower() in {'.orig','.bak','.swp','.tmp'}]
        self.assertEqual(junk, [], 'SwiftPM must not find stray editor backup files')
    def test_hotkey_can_disable_and_change(self):
        self.assertIn('globalHotkey.unregister()', M)
        self.assertIn('if enabled { globalHotkey.register(preset) }', M)
        self.assertIn('shortcutEnabledKey', M)
        self.assertIn('alternativeShortcut', H)
    def test_original_app_icon_in_bundle(self):
        self.assertTrue((R/'Design/AppIcon.icns').stat().st_size > 50000)
        self.assertTrue((R/'Design/AppIcon.png').stat().st_size > 10000)
        inst=(R/'scripts/install-local.sh').read_text()
        self.assertIn('<key>CFBundleIconFile</key><string>AppIcon.icns</string>', inst)
        self.assertIn('Design/AppIcon.icns', inst)
    def test_public_source_preserves_legacy_privacy(self):
        self.assertIn('return false', M.split('private func claudeWebEnabled(',1)[1].split('private func configureClaudeWebSession()',1)[0])
        self.assertIn('addQuotaNotificationMenu(to: menu)', M)
        self.assertIn('connectSelectedAccount()', M)
if __name__=='__main__': unittest.main(verbosity=2)
