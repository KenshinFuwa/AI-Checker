# AI Checker — 日本語ガイド

**macOS用メニューバー残量モニターのソース公開ベータ版（v1.10.1）。** [英語README](../README.md)

- Codexは公式App Serverから、Claudeは公式Claude Code statusLineが利用量フィールドを提供する場合に限り、5時間・週間の残量とリセット時間を表示。
- 表示形式：バー・数字・両方、名前表示、バー幅、AI間隔、配色をメニューから変更。枝分かれメニューを閉じずに操作可能。
- macOS通知：リセットを新しい観測値で確認した場合と、使い切った場合。利用者が明示的に有効化する設定。
- GitHub Copilot／OpenAI API／Cursor Team／xAI API：請求量・管理API利用量であり、個人向けチャット枠ではない。
- ChatGPT・Gemini・Perplexity・Cursor個人版・Grok個人版：公式サイトを既定ブラウザで開き、手動でメモできる。**残量自動取得ではない**。

このソース公開版には、再配布権が未確認のCodex・Claude公式ロゴ画像を含めません。コード内のベクター代替マークを利用します。2026年10月22日時点でv1.10.1のソースはGitHubの`main`に反映済みで、macOS・Linux・Universal 2とDMGレイアウトのCIが成功しています。ただし**Developer ID署名・Apple公証済みアプリや一般ユーザー向け正式DMGは未公開**です。年会費不要の[未公証テスト版の作成方法と注意](FREE_PREVIEW.ja.md)も参照できます。

## メニューバーがいっぱいになったとき

- 「省スペース・ショートカット → メニューバーの表示」で、通常／省スペース（数字のみ）／アイコンのみを切り替えられます。
- 既定の **⌃⌥⌘A**（Control + Option + Command + A）で、メニューバーに表示されていなくても利用状況パネルを開けます。競合する場合は **⌃⌥⌘U** に変更、またはOFFにできます。
- 「メニューバーの整理方法…」から、macOSの設定と他のアプリの設定変更を案内します。他アプリのアイコンは操作せず、アクセシビリティ権限も要求しません。
- 空きスペースの自動検出は行いません。初回導入時にも使い方が分かるよう、初回起動時にパネルを一度表示します。
- アプリアイコンは独自のゲージ＋チェックで、各AIサービスの公式ロゴを再配布しません。

## 開発環境

macOS 13以降、Swift 5.9以降、Xcode Command Line Tools。

```bash
./scripts/check.sh
swift build --jobs 2 -c release
```

手元の既存アプリを更新する `scripts/install-local.sh` は、元と同じ署名証明書がある人向けです。初回導入向け手順は [INSTALL.md](INSTALL.md) を参照してください。

Codex・Claudeアカウントはそれぞれ専用環境で扱い、APIキーはKeychainに保存します。GitHub公開ソース版はClaudeの非公開Web残量取得を搭載しません。Claude CodeのstatusLine連携のみ利用できます。

[セキュリティ](../SECURITY.md) · [公開前チェックリスト](../PUBLICATION_CHECKLIST.md) · [変更履歴](../CHANGELOG.md) · [配布QA](DISTRIBUTION.md)

## 著作権・ライセンス

Copyright © 2026 Kenshin Fuwa（不破憲伸）。[MIT License](../LICENSE) で公開しています。公開の可否については [公開前チェックリスト](../PUBLICATION_CHECKLIST.md) も確認してください。

## 公開版とローカル版の差分

公開版ではClaudeの非公開Web使用量APIへの自動アクセスを無効化しています。Claude CodeのstatusLineが提供する利用量データのみ取り込みます。ローカル実験版v1.9.2とは機能が異なります。

## Spotlightから開く（macOS）

開発用のローカルインストーラは通常 `~/Applications/AI Checker.app` を対象とします。一般配布用の署名・公証済みDMGはまだありません。既存の署名付きアプリを無断で置換しないでください。
⌘Spaceを押し、`AI Checker` と入力してアプリを選択してください。
すでに動作中のAI CheckerをSpotlightやFinderから再度開くと、利用状況パネルを表示します。
検索結果に表示されない場合は、Finderで `~/Applications` を開いてインストール先を確認するか、ターミナルから `open "$HOME/Applications/AI Checker.app"` を実行してください。
Spotlightのインデックス更新には時間がかかる場合があります。
Dockに常駐しないのはメニューバーアプリの仕様です。

## 通信速度とSpotlight

「AI CHECKER / USAGE」を開くと計測を自動開始し、約0.5秒後の初回結果以降は1秒ごとに更新します。閉じると停止します。速度テストではありません。Spotlight検索に表示されない場合は `bash scripts/diagnose-spotlight.sh` で診断し、必要に応じて `bash scripts/migrate-spotlight-app.sh` で署名を保持して `/Applications` に移行できます（管理者承認・明示的な確認が必要）。検索結果への表示はmacOSで最終確認してください。
