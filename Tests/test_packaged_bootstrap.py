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

    def test_syntax(self):
        subprocess.run(['bash', '-n', str(ROOT / "scripts/audit-release-dmg.sh")], check=True)

if __name__ == '__main__':
    unittest.main(verbosity=2)
