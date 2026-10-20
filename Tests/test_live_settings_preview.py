#!/usr/bin/env python3
"""Contract checks for variable-width native menu-bar artwork."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Sources/AIChecker/main.swift").read_text()
ART = (ROOT / "Sources/AIChecker/StatusArtwork.swift").read_text()
SETTINGS = (ROOT / "Sources/AICheckerCore/DisplayPreferences.swift").read_text()

class LiveSizingContracts(unittest.TestCase):
    def test_variable_length_status_item(self):
        self.assertIn('statusItem(withLength: NSStatusItem.variableLength)', MAIN)
        self.assertNotIn('item.length =', MAIN)
        self.assertNotIn('statusItem(withLength: max(', MAIN)

    def test_natural_artwork_immediately_replaces_status_button_image(self):
        render = MAIN.split('private func renderUI() {', 1)[1].split('if menuIsTracking {', 1)[0]
        for part in ['item.button?.image = image',
                     'item.button?.invalidateIntrinsicContentSize()',
                     'item.button?.displayIfNeeded()',
                     'lastDisplayKey = currentKey']:
            self.assertIn(part, render)
        self.assertNotIn('StatusArtwork.livePreview', MAIN)
        self.assertNotIn('livePreview(', ART)

    def test_geometry_tracks_rendered_metric_and_bar_styles(self):
        layout = ART.split('static func layout(', 1)[1].split('static func render(', 1)[0]
        self.assertIn('preferences.metricStyle.showBars', layout)
        self.assertIn('preferences.metricStyle.showPercent', layout)
        self.assertIn('preferences.barSize.width', layout)
        self.assertIn('let gap =', layout)
        self.assertIn('cursor = right', layout)
        self.assertIn('return (ceil(cursor), slots)', layout)
        self.assertIn('case percentOnly', SETTINGS)
        self.assertIn('case barsAndPercent', SETTINGS)

    def test_keep_native_branches_open_during_redraw(self):
        self.assertIn('if menuIsTracking {', MAIN)
        self.assertIn('pendingMenuRefresh = true', MAIN)
        self.assertIn('row.displayIfNeeded()', MAIN)
        self.assertIn('savePreferences()   // menu remains tracked', MAIN)
        self.assertIn('addDisplaySettingsMenu(to: menu)', MAIN)

    def test_notifications_and_account_connections_preserved(self):
        for part in ['addQuotaNotificationMenu(to: menu)',
                     'private func observeQuota(',
                     'connectSelectedAccount()',
                     'configureClaudeWebSession()']:
            self.assertIn(part, MAIN)

    def test_native_layout_smoke_test_present(self):
        self.assertIn('--selftest-status-layout', MAIN)
        self.assertIn('width(numeric) < width(bars)', MAIN)
        self.assertIn('width(bars) < width(combined)', MAIN)
        self.assertIn('width(narrowBars) < width(wideBars)', MAIN)

if __name__ == '__main__':
    unittest.main(verbosity=2)
