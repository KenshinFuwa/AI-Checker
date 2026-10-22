#!/usr/bin/env python3
"""Source-level safety contract; interactive Spotlight recognition requires macOS."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Sources/AIChecker/main.swift").read_text()
INSTALL = (ROOT / "scripts/install-local.sh").read_text()

class SpotlightReopenContracts(unittest.TestCase):
    def test_reopen_brings_quick_panel_to_front(self):
        handler = MAIN.split("func applicationShouldHandleReopen(", 1)[1].split("// Accessory/menu-bar-only", 1)[0]
        self.assertIn("self?.showQuickPanel()", handler)
        self.assertIn("DispatchQueue.main.async", handler)
        self.assertIn("return false", handler)
    def test_quick_panel_is_not_new_process(self):
        self.assertIn("@objc private func showQuickPanel()", MAIN)
        self.assertIn("quickPanel.present(", MAIN)
    def test_bundle_is_searchable_app_not_dock_icon(self):
        for part in ['CFBundleIdentifier', 'CFBundleDisplayName', 'AI Checker.app', 'CFBundleIconFile', '<key>LSUIElement</key><true/>']:
            self.assertIn(part, INSTALL)
    def test_install_registers_only_staged_app_after_install(self):
        self.assertIn('repair-spotlight.sh" "$DEST"', INSTALL)
        self.assertGreater(INSTALL.index('repair-spotlight.sh" "$DEST"'), INSTALL.index('if ! mv "$STAGE" "$DEST"; then'))
        self.assertNotIn('sudo ', INSTALL.split('if $SYSTEM_INSTALL; then')[0])
        helper = (ROOT / "scripts/repair-spotlight.sh").read_text()
        self.assertIn('lsregister', helper)
        self.assertIn('"$LSREGISTER" -f "$APP"', helper)
        self.assertIn('dev.aichecker.localapp', helper)
        self.assertNotIn('mdutil -E', helper)
        self.assertNotIn(' -kill ', helper)
        self.assertNotIn('sudo ', helper)
        self.assertNotIn('rm -rf', helper)

    def test_existing_app_is_signed_and_replaced_safely(self):
        self.assertIn('codesign --verify --strict', INSTALL)
        self.assertIn('OLD_REQ', INSTALL)
        self.assertIn('NEW_REQ', INSTALL)

if __name__ == "__main__":
    unittest.main()
