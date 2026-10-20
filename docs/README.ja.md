# AI Checker — 日本語ガイド

**macOS用メニューバー残量モニターのソース公開ベータ版（v1.9.2-beta.3）。** [英語README](../README.md)

- Codexは公式App Serverから、Claudeは公式Claude Code statusLineが利用量フィールドを提供する場合に限り、5時間・週間の残量とリセット時間を表示。
- 表示形式：バー・数字・両方、名前表示、バー幅、AI間隔、配色をメニューから変更。枝分かれメニューを閉じずに操作可能。
- macOS通知：リセットを新しい観測値で確認した場合と、使い切った場合。利用者が明示的に有効化する設定。
- GitHub Copilot／OpenAI API／Cursor Team／xAI API：請求量・管理API利用量であり、個人向けチャット枠ではない。
- ChatGPT・Gemini・Perplexity・Cursor個人版・Grok個人版：公式サイトを既定ブラウザで開き、手動でメモできる。**残量自動取得ではない**。

このソース公開版には、再配布権が未確認のCodex・Claude公式ロゴ画像を含めません。コード内のベクター代替マークを利用します。公開版は署名・公証済みアプリ配布ではありません。

## 開発環境

macOS 13以降、Swift 5.9以降、Xcode Command Line Tools。

```bash
./scripts/check.sh
swift build --jobs 2 -c release
```

手元の既存アプリを更新する `scripts/install-local.sh` は、元と同じ署名証明書がある人向けです。初回導入向け手順は [INSTALL.md](INSTALL.md) を参照してください。

Codex・Claudeアカウントはそれぞれ専用環境で扱い、APIキーはKeychainに保存します。GitHub公開ソース版はClaudeの非公開Web残量取得を搭載しません。Claude CodeのstatusLine連携のみ利用できます。

[セキュリティ](../SECURITY.md) · [公開前チェックリスト](../PUBLICATION_CHECKLIST.md) · [変更履歴](../CHANGELOG.md)

## 著作権・ライセンス

Copyright © 2026 Kenshin Fuwa（不破憲伸）。[MIT License](../LICENSE) で公開予定です。公開の可否については [公開前チェックリスト](../PUBLICATION_CHECKLIST.md) も確認してください。

## 公開版とローカル版の差分

公開版ではClaudeの非公開Web使用量APIへの自動アクセスを無効化しています。Claude CodeのstatusLineが提供する利用量データのみ取り込みます。ローカル実験版v1.9.2とは機能が異なります。
