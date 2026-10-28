#!/usr/bin/env python3
"""Verify the opt-in, no-account packaged AppKit bootstrap test wiring."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class PackagedBootstrapContracts(unittest.TestCase):
    def test_explicit_selftest_precedes_normal_app_loop(self):
        app = (ROOT / "Sources/AIChecker/main.swift").read_text()
        start = app.index('} else if CommandLine.arguments.contains("--selftest-packaged-bootstrap") {')
        end = app.index('} else if CommandLine.arguments.contains("--selftest-status-layout") {', start)
        smoke = app[start:end]
        self.assertIn('NSApplication.shared', smoke)
        self.assertIn('NSStatusBar.system.statusItem', smoke)
        self.assertIn('NSStatusBar.system.removeStatusItem', smoke)
        self.assertIn('Bundle.main.bundleIdentifier', smoke)
        self.assertIn('url(forResource: "AppIcon", withExtension: "icns")', smoke)
        self.assertIn('application.applicationIconImage = appIcon', smoke)
        self.assertIn('statusItem.menu = smokeMenu', smoke)
        for forbidden in ('app.run()', 'loadAccounts()', 'connectSelectedAccount()',
                          'configureLaunchAtLogin()', 'UNUserNotificationCenter',
                          'requestPermission(', 'refresh(force:', 'UserDefaults.standard'):
            self.assertNotIn(forbidden, smoke)

    def test_mount_and_smoke_are_opt_in(self):
        audit = (ROOT / "scripts/audit-release-dmg.sh").read_text()
        wf = (ROOT / ".github/workflows/mac-validation.yml").read_text()
        self.assertIn('AI_CHECKER_CI_BOOTSTRAP:-0', audit)
        self.assertIn('"$EXE" --selftest-packaged-bootstrap', audit)
        self.assertIn('[[ "$MODE" == --unsigned-preflight ]]', audit)
        self.assertIn('AI_CHECKER_CI_BOOTSTRAP=1 bash scripts/check-universal-build.sh', wf)
        self.assertNotIn('AI_CHECKER_CI_BOOTSTRAP=1', (ROOT / "scripts/build-free-preview-dmg.sh").read_text())
        self.assertNotIn('AI_CHECKER_CI_BOOTSTRAP=1', (ROOT / "scripts/build-notarized-dmg.sh").read_text())

    def test_packaged_localizations_are_process_scoped_and_account_free(self):
        app = (ROOT / "Sources/AIChecker/main.swift").read_text()
        audit = (ROOT / "scripts/audit-release-dmg.sh").read_text()
        section = app.split('} else if CommandLine.arguments.contains("--selftest-packaged-bootstrap") {', 1)[1].split(
            '} else if CommandLine.arguments.contains("--selftest-status-layout") {', 1)[0]
        self.assertIn('CommandLine.arguments.firstIndex(of: "--selftest-language")', section)
        self.assertIn('Bundle.main.preferredLocalizations.first == language', section)
        self.assertIn('AppL10n.text("今すぐ更新")', section)
        self.assertIn('AppL10n.format("割り当てに失敗: %@", "TEST")', section)
        self.assertIn('AppL10n.apply(to: localizedMenu)', section)
        self.assertIn('AppL10n.text("Claude: 公式statusLineから使用率が届いていません（Claude Code連携は任意）。")', section)
        self.assertIn('NSStatusBar.system.removeStatusItem(statusItem)', section)
        self.assertIn('TEST_SCOPE: no user data, no network', section)
        for language in ('en', 'ja'):
            self.assertIn(f'"$EXE" -AppleLanguages "({language})" --selftest-packaged-bootstrap --selftest-language {language}', audit)
        self.assertIn('[[ "$MODE" == --unsigned-preflight ]]', audit)
        for unsafe in ('defaults write', 'tccutil', 'security ', 'xcrun notarytool', 'app.run()', 'loadAccounts()', 'UserDefaults.standard'):
            self.assertNotIn(unsafe, section)
        for unsafe in ('defaults write ', 'open -a ', 'installer -pkg', 'cp -R "$APP" /Applications'):
            self.assertNotIn(unsafe, audit)

    def test_syntax(self):
        subprocess.run(['bash', '-n', str(ROOT / "scripts/audit-release-dmg.sh")], check=True)

if __name__ == '__main__':
    unittest.main(verbosity=2)
