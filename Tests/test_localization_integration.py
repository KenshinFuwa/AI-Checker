#!/usr/bin/env python3
"""Validate macOS en/ja localization resources without requiring a GUI."""
from pathlib import Path
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PAIR = re.compile(r'^"((?:\\.|[^"\\])*)" = "((?:\\.|[^"\\])*)";$')
JAPANESE = re.compile(r'[\u3040-\u30ff\u3400-\u9fff]')


def entries(path):
    result = {}
    for line_number, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith('/*') or line.startswith('//'):
            continue
        match = PAIR.fullmatch(line)
        if match is None:
            raise AssertionError(f'{path}:{line_number}: malformed .strings entry')
        key, value = match.groups()
        if key in result:
            raise AssertionError(f'{path}:{line_number}: duplicate key: {key}')
        result[key] = value
    return result


class LocalizationContracts(unittest.TestCase):
    def test_parallel_translation_catalogs_and_english_fallback(self):
        english = entries(ROOT / 'Localization/en.lproj/Localizable.strings')
        japanese = entries(ROOT / 'Localization/ja.lproj/Localizable.strings')
        self.assertGreaterEqual(len(english), 100)
        self.assertEqual(set(english), set(japanese))
        for key, value in english.items():
            self.assertEqual(japanese[key], key)
            self.assertFalse(JAPANESE.search(value), f'English translation missing: {key}')
            self.assertNotEqual(value, '', f'empty translation: {key}')
        for key in ('今すぐ更新', 'ChatGPTでかんたん接続…',
                    'アカウントを追加…', '表示設定', '完了'):
            self.assertIn(key, english)
        info = plistlib.loads((ROOT / 'scripts/release/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleDevelopmentRegion'], 'en')
        self.assertEqual(info['CFBundleLocalizations'], ['en', 'ja'])

    def test_native_bundled_lookup_and_primary_navigation(self):
        app = (ROOT / 'Sources/AIChecker/AppLocalization.swift').read_text()
        main = (ROOT / 'Sources/AIChecker/main.swift').read_text()
        row = (ROOT / 'Sources/AIChecker/StayOpenMenuRow.swift').read_text()
        heading = (ROOT / 'Sources/AIChecker/MenuVisualStyle.swift').read_text()
        self.assertIn('Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")', app)
        self.assertIn('AppL10n.apply(to: menu)', main)
        self.assertIn('self.caption = AppL10n.text(caption)', row)
        self.assertIn('setAccessibilityLabel(self.caption)', row)
        self.assertIn('AppL10n.text(title)', heading)
        for filename in ('PersistentAccountsPanel.swift', 'PersistentSettingsPanel.swift', 'UsageQuickPanel.swift'):
            source = (ROOT / 'Sources/AIChecker' / filename).read_text()
            self.assertIn('AppL10n.text(', source, filename)

    def test_localized_codex_and_notification_status(self):
        en = entries(ROOT / 'Localization/en.lproj/Localizable.strings')
        codex = (ROOT / 'Sources/AIChecker/CodexAccountClient.swift').read_text()
        notification = (ROOT / 'Sources/AIChecker/QuotaNotificationCenter.swift').read_text()
        for key in ('Codex App Serverに接続中…', 'ブラウザでChatGPTログインを完了してください',
                    'ChatGPT接続済み（%@）%@', '切断済み（%@）',
                    '%@の制限がリセットされました（残り%d%%）',
                    '%@の利用可能枠を使い切りました',
                    '通知の準備ができました。残量の変化は実データから判定します。'):
            self.assertIn(key, en)
        self.assertIn('AppL10n.format("ChatGPT接続済み（%@）%@", self.profile.label, verified)', codex)
        self.assertIn('AppL10n.format("%@の制限がリセットされました（残り%d%%）"', notification)

    def test_offline_codex_bridge_includes_portable_localizer(self):
        helper = (ROOT / 'Sources/AIChecker/AppLocalization.swift').read_text()
        bridge = (ROOT / 'scripts/test-codex-bridge.sh').read_text()
        self.assertIn('#if canImport(AppKit)', helper)
        self.assertIn('Sources/AIChecker/AppLocalization.swift', bridge)

    def test_all_distribution_paths_ship_localized_resources(self):
        stage = (ROOT / 'scripts/stage-release-app.sh').read_text()
        local = (ROOT / 'scripts/install-local.sh').read_text()
        audit = (ROOT / 'scripts/audit-release-dmg.sh').read_text()
        for path, script in [('stage', stage), ('local', local), ('audit', audit)]:
            self.assertIn('for LANGUAGE in en ja; do', script, path)
            self.assertIn('Localizable.strings', script, path)
            self.assertIn('plutil -lint "$RESOURCE"', script, path)
            self.assertIn('cmp ', script, path)
        self.assertLess(local.index('Localizable.strings'), local.index('codesign --force --sign'))
        self.assertIn("'CFBundleLocalizations':['en','ja']", audit)
        self.assertIn('python3 Tests/test_localization_integration.py',
                      (ROOT / 'scripts/check.sh').read_text())


if __name__ == '__main__':
    unittest.main(verbosity=2)
