# Apple Developer Program不要：AI Checker未公証プレビュー（テスト専用）

**このDMGは正式版ではありません。** Developer ID署名もApple公証も受けておらず、Gatekeeperによって起動が制限される可能性があります。利用者が安全性を確認できない場合は起動しないでください。Appleの警告を無効にするコマンドは提供しません。

- Apple Developer Programの年会費を支払わなくても、Universal 2（Apple Silicon + Intel）の**テスト用DMGを生成**できます。
- 現在インストール済みのAI Checker、Codex/Claudeアカウント、Keychain、通知設定、ログイン項目は変更しません。
- テスト用DMGには`Applications`へのショートカットがありますが、**既存のAI Checker.appを上書きしないでください**。クリーンなテスト用Macまたは隔離環境での検証が前提です。
- 公開ソース版ではClaudeの非公開Web API取得は無効です。公式Claude Code statusLine対応のみです。

## GitHub ActionsでテストDMGを作る（手動・7日間保管）

1. [GitHubの手動プレビューWorkflow](https://github.com/KenshinFuwa/AI-Checker/actions/workflows/unnotarized-preview.yml) を開く。
2. `Run workflow` で `main` を選び、入力欄に **`UNNOTARIZED_TEST_ONLY`** と正確に入力して実行する。
3. 実行が成功した場合のみ、該当Runの`Artifacts`に、名前が`UNNOTARIZED`を含む**一時的なテスト成果物**が現れる。内容は `.dmg`、`.sha256`、警告文書。
4. SHA-256検証後に、**テスト専用Mac**で安全性・動作を確認する。macOSがブロックした場合はAppleのセキュリティ警告を尊重し、配布者やアプリの真正性を確認する。

このWorkflowは自動実行しません。GitHub Releasesへの正式版公開も行いません。GitHub Actionsの実行は利用枠を消費する場合があります。

## Macでローカル作成する場合

リポジトリのルートで `bash scripts/build-free-preview-dmg.sh --acknowledge-unnotarized-preview` を実行します。テスト用成果物は`dist/`内に作成され、同名ファイルが既存の場合は上書きせず停止します。`/Applications`にも触れません。署名は開発者本人を証明できない**アドホック署名**であり、Apple公証には使用できません。

## 本番配布との区別

Apple Developer IDの正式署名・公証は、別の `scripts/build-notarized-dmg.sh` に限定しています。現在その工程は証明書がないためHOLDです。Appleの公式説明：[安全にアプリを開く](https://support.apple.com/ja-jp/102445)・[Developer ID](https://developer.apple.com/jp/developer-id/)。

## GitHub macOSでの起動ブートストラップ検査

通常CIには、DMGを読み取り専用でマウントし、その中の実行ファイルから
`--selftest-packaged-bootstrap` を呼ぶ検査を追加しています。AppKit初期化、
アプリアイコン、メニューバー項目・メニューを検証します。アカウント情報の
読込み、ネットワーク接続、ログイン項目登録、通知許可、通常イベントループは
意図的に実行しません。**ユーザーのMacでの通常起動、Gatekeeperの判断、
通知表示、Intel Macでの実行成功を証明する検査ではありません。**
