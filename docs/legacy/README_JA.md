# AI Checker v1.9.2 — メニューバーの領域を可変幅に

**変更点**：表示設定の「数字のみ」「バーのみ」「バーと数字」、バー幅、表示するAIの数、名称表示に応じてメニューバーの領域を自動調整します。固定幅の描画をやめて、macOS標準の `NSStatusItem.variableLength` を採用しました。これまでの枝分かれメニュー、通知、認証、設定保存は維持します。

**インストール（既存AI Checkerの手動終了は不要）**

```bash
cd ~/Downloads
unzip -oq AI-Checker-v1.9.2.zip
cd AI-Checker-v1.9.2
./scripts/check.sh && ./scripts/install-local.sh
```

**実機確認**：表示設定 → 表示形式で「数字のみ」を選び、メニューが開いたまま背景領域が短くなるか確認してください。「バーのみ」「バーと数字」、バー幅の短い／長いでも同様に確認してください。

**制約**：メニューバーの幅が変更されるとmacOSが位置を調整します。メニューを開いたままの位置調整時に枝分かれが閉じないかはmacOS実機で確認する必要があります。Linux上の静的検査とSwift Coreテストだけでは保証できません。

---

## 旧v1.9.1 — リセット・使い切り通知

## 新しく追加された通知設定

メニューバー → **通知設定** に以下の3項目を追加しました。

- **5時間・週間のリセット時に通知**：リセットが最新の残量データで確認できたときに通知。
- **5時間・週間の残量を使い切ったら通知**：残量が表示上0%になった変化を通知。
- **テスト通知を送る…**：macOSの通知設定を確認するテスト。

両通知とも初期設定はOFF。初めて有効にするときにmacOSの許可を求めます。
通知は各AI・各アカウント・5時間/週間の単位で重複を防止します。
残量データが古い、未取得、手動メモのみの場合は通知しません。
リセット予定時刻だけを根拠にした通知もしません。
アプリを終了すると監視は停止します。スリープ復帰後は新しい取得結果で判定します。
現在自動通知の対象となるのはCodexとClaudeの**選択中プロフィール**です。
ChatGPT本体/Gemini/Perplexity/Cursor個人版/Grokの手動記録は対象外です。

## インストール

```bash
cd ~/Downloads
unzip -oq AI-Checker-v1.9.1.zip
cd AI-Checker-v1.9.1
./scripts/check.sh && ./scripts/install-local.sh
```

既存のアカウント、Keychain、表示設定は維持します。インストール前にMacのネイティブビルドが必要です。

---

## 以前のv1.8.2の説明（履歴）

# AI Checker v1.9.1 — 5サービスの公式Web確認と手動メモ

v1.6.8 の視覚調整済み版をそのまま継承。既存 Codex・Claude アカウント、Cookie/Keychain、メニューバー表示、60秒更新、スリープ動作、自動アップデート、署名IDは維持します。

## インストール

ZIPをDownloadsに保存してから、起動中の AI Checker を手動終了せずに実行してください。

```bash
cd ~/Downloads
unzip -oq AI-Checker-v1.9.1.zip
cd AI-Checker-v1.9.1
./scripts/check.sh && ./scripts/install-local.sh
```

更新はまずビルド・署名検査を済ませ、その後に現在のインストール済みアプリだけを安全に終了・置換・再起動します。元アプリのバックアップは `~/Applications/AI Checker.previous.app` に残ります。

## 新機能：API使用量の独立レポート

メニューバーの AI Checker → **ACCOUNTS / 接続 → AIサービスを追加…** から、以下の3つを独立して接続できます。接続はオプトインで、APIキーはMacのKeychainにのみ保存します。設定後、適切な権限で公式APIが呼び出され、取得できた時だけ **API REPORTS / 公式API使用量** に表示します。

| メニュー項目 | 使用する公式API | レポート対象 | 必要なもの |
| --- | --- | --- | --- |
| OpenAI API | `GET /v1/organization/costs` | 当月組織API利用請求額（USD） | 組織所有者のAdmin API Key |
| Cursor Team | `POST /teams/daily-usage-data` | 当月のチームAgent Requests | チーム管理者のAdmin API Key／対応するチーム契約 |
| xAI API (Grok) | `POST /v1/billing/teams/{team_id}/usage` | 当月のチームAPI利用請求額（USD） | xAI Management API Key（読み取り権限）とTeam ID（UUID） |

**極めて重要：** これらは開発者/チームのAPI使用額・使用数であり、ChatGPT Plus/Pro、Cursor個人版、SuperGrok、Grokチャットなどの5h/Week消費制限ではありません。取得できない残量%やリセット時間は決して捏造しません。GitHub Copilot個人請求API・Codex・Claudeの既存機能は変更していません。

ChatGPTチャット本体、Geminiチャット個人枠、Perplexity個人枠、Cursor個人枠、Grokチャット用枠の公開・安定した読み取りAPIは確認できていないため、接続済みと偽りません。Gemini CLIではインタラクティブな`/stats model`などで利用情報を見ることができますが、AI Checkerからの機械取得にはまだ対応していません。

### セキュリティ・障害時の扱い

- トークンは `NSSecureTextField` に入力し、macOS Keychainに保存。ユーザーデフォルトには接続ON/OFFとxAIのTeam IDのみ保存します。
- API報告は通常最大15分に1度だけ照会。スリープ中は停止し、復帰後に再開。
- HTTP 401/403/429や不完全・ページ継続レスポンスでは数値表示に成功しません。
- API REPORTSは記録から1時間を超えるデータを古いデータとして表示せず、最新成功値に見せかけません。
- APIキーは管理者権限を伴うことがあります。他者と共有するMacでは登録しないでください。アプリから切断してもサービス側でのキー失効にはならないため、必要な場合は発行元で失効させてください。
- API使用量の取得のみで、推論要求や課金設定変更、キー作成は行いません。

## 検証上の限界

Swift coreのモックレスポンス・不完全データ検査およびLinux Swift syntax parseは実施しています。macOS AppKitの型チェック、実アカウント接続、APIキー権限と実データ仕様の検証はMac実機で実施する必要があります。実接続に必要な秘密情報はチャットに送らないでください。


## v1.9.1：接続メニュー統合とビルド修正

- メインの「追加APIアカウント管理」を削除し、**AIサービスを追加…** に一本化。
- API接続（OpenAI API / Cursor Team / xAI API）もCodex・Claude・Copilotと同じ枝分かれメニューに統合。
- ChatGPT / Gemini / Perplexity / Cursor個人版 / Grokは **公式サイトを開く…**（macOSの既定ブラウザー）／**手動記録**／**記録削除** のみを表示。
- 専用WebKitブラウザー選択や「未対応」説明行は表示しません。
- 手動記録は残量の自動取得ではありません。Codex・Claudeの使用率と混同しません。
- v1.8.1で旧関数名を参照していた回帰テストを更新し、新規APIメニューの `currentPeriod` 未定義スコープも修正。
- v1.8.0以前に作った個人向け専用ブラウザーのサイトデータは自動削除しません。ただし今回のメニューからは起動できません。Claude固有の認証方式は従来どおりです。

既定ブラウザーで開くサービスURL：

- ChatGPT: https://chatgpt.com/
- Gemini: https://gemini.google.com/
- Perplexity: https://www.perplexity.ai/
- Cursor: https://cursor.com/dashboard
- Grok: https://grok.com/dashboard

macOSネイティブのコンパイル・実際のクリック動作はMac実機で確認してください。既存のKeychainやアカウント設定はそのまま保持します。

## v1.7.3 の操作変更（履歴）（履歴）

- 「表示設定」から以前の枝分かれ式メニューに戻しました。変更後も親メニューと開いているサブメニューを維持する実装です。
- 「表示設定を続けて変更…」も、別の設定・接続管理ウィンドウも開きません。
- Codex / Claude / API は元のメニュー内で管理し、継続操作できます。ログイン画面・確認ダイアログだけは必要に応じて別途表示されます。
- GitHub Copilot が未接続か、個人向け請求APIの許可を受けていない場合、管理項目はメインメニューに表示しません。

**実機確認**: macOSのメニューイベント処理はこのLinux検証環境では評価できません。Macでクリック後の開いたサブメニュー、連続選択、再起動後の設定保存を確認してください。

## v1.7.3：他の項目も連続操作

- 「今すぐ更新」を押してもメインメニューを閉じず、取得中は再押下できないようにしました。
- ログイン時の自動起動の切替・Copilot利用区分・API接続後の取得操作等も、可能な範囲で開いた枝分かれメニューに状態を反映します。
- 「AIサービスを追加…」ではCodex／Claude／Copilotの接続手順がメニュー内で枝分かれします。未対応サービスはメニュー内に状況を表示します。
- ログイン時の自動起動にmacOSの承認が必要な場合、システム設定への移動はOS側の操作です。トークン入力・認証・削除確認も専用ダイアログが必要です。AI Checker本体の別設定ウィンドウは開きません。
- 終了操作は例外で、AI Checkerが終了するためメニューも閉じます。

この環境では実機のNSMenu追跡動作は検査できません。Mac上で連続クリックできることを確認してください。
