#!/usr/bin/env python3
"""Static safety/behavior contract: site access must not masquerade as automated quota."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class ConsumerWebTests(unittest.TestCase):
    def test_five_distinct_first_party_destinations(self):
        t=(ROOT/'Sources/AICheckerCore/ConsumerWebAccess.swift').read_text()
        for id_, url in [('chatgpt','https://chatgpt.com/'), ('gemini','https://gemini.google.com/'),
                        ('perplexity','https://www.perplexity.ai/'), ('cursor','https://cursor.com/dashboard'),
                        ('grok','https://grok.com/dashboard')]:
            self.assertIn(f'id: "{id_}"',t)
            self.assertIn(f'urlString: "{url}"',t)
        self.assertIn('url.scheme == "https"',t)
    def test_webkit_session_has_no_secret_reads_or_quota_injection(self):
        t=(ROOT/'Sources/AIChecker/ConsumerWebSession.swift').read_text()
        self.assertIn('WKWebsiteDataStore(forIdentifier: storeID)',t)
        self.assertIn('WKWebsiteDataStore.remove(forIdentifier: storeID',t)
        self.assertIn('websiteDataStore = .nonPersistent()',t)
        self.assertIn('destination.url',t)
        self.assertIn('scheme == "https" || scheme == "about"',t)
        for dangerous in ['evaluateJavaScript', 'callAsyncJavaScript', 'document.cookie',
                          'WKHTTPCookieStore.getAllCookies', 'URLSession', '/backend-api/',
                          'tokenValue', 'sessionKey']:
            self.assertNotIn(dangerous,t)
    def test_default_browser_is_only_exposed_browser_action(self):
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        catalog=main.split('case .catalog:',1)[1].split('item.submenu = menu',1)[0]
        self.assertIn('addConsumerProviderSubmenu(id, to: menu)', catalog)
        self.assertIn('addExternalAPIProviderSubmenu(kind, to: menu)', catalog)
        self.assertNotIn('addUnsupportedProviderSubmenu', catalog)
        consumer=main.split('private func addConsumerProviderSubmenu(',1)[1].split('// MARK: - Consumer web browsing',1)[0]
        self.assertIn('公式サイトを開く…',consumer)
        self.assertIn('openConsumerExternally(id)',consumer)
        self.assertIn('画面で確認した内容を手動記録…',consumer)
        self.assertIn('editConsumerNote(id)',consumer)
        self.assertIn('手動記録を削除',consumer)
        self.assertNotIn('openConsumerWeb(id)',consumer)
        self.assertNotIn('eraseConsumerWeb(id)',consumer)
        self.assertNotIn('未対応',consumer)
        self.assertEqual(consumer.count('公式サイトを開く…'),1)
        self.assertIn('NSWorkspace.shared.open(url)',main)

    def test_observations_stay_manual_and_never_become_quota_snapshots(self):
        main=(ROOT/'Sources/AIChecker/main.swift').read_text()
        body=main.split('private func editConsumerNote',1)[1].split('private func eraseConsumerWeb',1)[0]
        self.assertIn('consumerNotes[providerID] = note',body)
        self.assertIn('saveConsumerNotes()',body)
        self.assertNotIn('snapshots[providerID] =',body)
        self.assertIn('手動記録（自動取得ではありません）',main)
        self.assertIn('where AIProviderRegistry.isImplemented(provider.id)',main)
        self.assertIn('DispatchQueue.main.async',main)

    def test_version_and_docs_explicit(self):
        self.assertIn('<string>1.10.1</string>',(ROOT/'scripts/install-local.sh').read_text())
        for fn in ['docs/legacy/README_FIRST.md','docs/legacy/README_JA.md']:
            t=(ROOT/fn).read_text()
            self.assertIn('AI-Checker-v1.9.2.zip',t)
            self.assertIn('自動取得',t)

if __name__ == '__main__': unittest.main(verbosity=2)
