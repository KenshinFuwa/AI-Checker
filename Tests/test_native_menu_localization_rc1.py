#!/usr/bin/env python3
"""Read-only regression for production native menu localization."""
from pathlib import Path
import re, unittest
ROOT=Path(__file__).resolve().parents[1]

def catalog(language):
    s=(ROOT/'Localization'/f'{language}.lproj'/'Localizable.strings').read_text()
    return dict(re.findall(r'^"((?:\\.|[^"\\])*)" = "((?:\\.|[^"\\])*)";',s,re.M))

class ProductionLocalization(unittest.TestCase):
    def test_translation_catalog_parity(self):
        en,ja=catalog('en'),catalog('ja')
        self.assertEqual(set(en),set(ja))
        self.assertEqual(en['%@ Details'],'%@ Details')
        self.assertEqual(ja['%@ Details'],'%@ の詳細')
        self.assertEqual(en['最終同期: %@%@'],'Last Sync: %@%@')
        self.assertEqual(ja['最終同期: %@%@'],'最終同期: %@%@')
        for key in ('5h残量: %@','週残量: %@','5h更新: %@','週更新: %@',
                    '記録時刻: %@','情報源: %@','状態: %@','最終同期: %@%@'):
            self.assertEqual(en[key].count('%@'),key.count('%@'))
            self.assertEqual(ja[key].count('%@'),key.count('%@'))

    def test_native_menu_does_not_interpolate_early(self):
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        self.assertIn('AppL10n.format("%@ Details", provider.name)',main)
        self.assertIn('AppL10n.format("最終同期: %@%@", dateText(lastSuccess)',main)
        self.assertNotIn('title: "  \\(provider.name) の詳細"',main)
        self.assertNotIn('title: "最終同期: \\(dateText(lastSuccess))',main)
        self.assertIn('let failure = providerHealth.states[provider.id]?.lastFailure',main)
        self.assertIn('private let demo = ProcessInfo.processInfo.environment["AI_CHECKER_DEMO"] == "1"',main)
        self.assertNotIn('OFFLINE SAMPLE — NOT LIVE',main)
        self.assertNotIn('SAMPLE DATA · OFFLINE',main)
        self.assertNotIn('SAMPLE PREVIEW',main)
        self.assertIn('self?.refreshNow()',main)

    def test_native_card_labels_and_countdown(self):
        card=(ROOT/'Sources/AIChecker/UsageDashboardMenuView.swift').read_text()
        self.assertIn('AppL10n.text(UsageMenuPresentation.resetCaption)',card)
        self.assertIn('AppL10n.text(UsageMenuPresentation.rowLabels[0])',card)
        self.assertIn('localizedCountdown(countdown)',card)
        self.assertIn('TelemetryFreshness.isRecent(snapshot, now: now)',card)
        self.assertIn('QuotaColorPalette.color(for: percent)',card)
        self.assertIn('UsageMenuPresentation.fillFraction',card)

    def test_scope_is_display_only(self):
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        self.assertEqual(main.count('Timer(timeInterval: RefreshPolicy.interval'),1)
        self.assertIn('Codexアカウント管理',main)
        self.assertIn('Claudeアカウント管理',main)
        self.assertNotIn('private let demo = true',main)

if __name__=='__main__':unittest.main()
