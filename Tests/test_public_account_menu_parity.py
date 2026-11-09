#!/usr/bin/env python3
"""Exact public account menu parity and public Claude API safety regressions."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Sources/AIChecker/main.swift").read_text()
PANEL = (ROOT / "Sources/AIChecker/PersistentAccountsPanel.swift").read_text()
WEB = (ROOT / "Sources/AIChecker/ClaudeWebSession.swift").read_text()
LABELS = ["アカウントを追加…", "接続を設定…", "接続を解除…",
          "名前を変更…", "選択中アカウントを削除…", "詳細設定…"]


class PublicAccountMenuParity(unittest.TestCase):
    def test_six_identical_rows_on_both_surfaces(self):
        for source, marker in [(MAIN, "private func addAccountsSubmenu("),
                               (PANEL, "private func makeLines(")]:
            body = source.split(marker, 1)[1].split("case .copilot:", 1)[0]
            codex = body.split("case .codex:", 1)[1].split("case .claude:", 1)[0]
            claude = body.split("case .claude:", 1)[1]
            for region in (codex, claude):
                self.assertEqual(re.findall(r'(?:command\(|\.command\()"([^"\n]+)"\s*,', region), LABELS)
                self.assertNotIn('"残量を更新"', region)
                self.assertNotIn('"接続を修復"', region)

    def test_actions_are_connected_and_claude_logout_is_honest(self):
        self.assertIn('case .advancedCodex: showAccountAdvancedDetails(codex: true)', MAIN)
        self.assertIn('case .advancedClaude: showAccountAdvancedDetails(codex: false)', MAIN)
        self.assertIn('case .disconnectClaudeCode: requestClaudeCodeLogout()', MAIN)
        self.assertIn('Claude Codeで /logout を実行してください', MAIN)
        self.assertIn('case .loginClaudeCode: openClaudeCode()', MAIN)
        self.assertNotIn('case .disconnectClaudeCode: removeClaude()', MAIN)

    def test_global_refresh_only(self):
        self.assertIn('addStayOpenRow("残量を更新", to: menu', MAIN)
        self.assertNotIn('command("残量を更新", .refreshQuotas)', MAIN)
        self.assertNotIn('"今すぐ使用量を取得"', MAIN + PANEL)
        self.assertNotIn('addStayOpenRow("今すぐ取得"', MAIN)
        self.assertNotIn('"今すぐ取得"', PANEL)

    def test_public_claude_web_endpoint_stays_disabled(self):
        self.assertIn('func poll(force: Bool = false) { /* Deliberately no network requests. */ }', WEB)
        self.assertNotIn('callAsyncJavaScript', WEB)
        guard = MAIN.split('private func claudeWebEnabled(', 1)[1].split(
            'private func configureClaudeWebSession()', 1)[0]
        self.assertIn('return false', guard)


if __name__ == "__main__":
    unittest.main()
