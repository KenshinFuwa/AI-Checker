#!/usr/bin/env python3
"""Read-only integration/static release guards. No Keychain, session files or web access."""
import pathlib, re, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]

def source(name):
    return (ROOT / name).read_text()

class ReleaseInvariants(unittest.TestCase):
    def test_copilot_paste_access_is_explicit_and_secure(self):
        main = source('Sources/AIChecker/main.swift')
        client = source('Sources/AIChecker/CopilotBillingClient.swift')
        self.assertIn('installStandardEditCommands()', main)
        self.assertIn('NSApp.mainMenu = mainMenu', main)
        self.assertIn('NSSelectorFromString(action)', main)
        self.assertIn('("Paste", "paste:", "v")', main)
        self.assertIn('NSSecureTextField(frame:', main)
        self.assertIn('クリップボードから貼り付け', main)
        self.assertIn('#selector(pasteCopilotToken(_:))', main)
        self.assertIn('NSPasteboard.general.string(forType: .string)', main)
        self.assertIn('copilotTokenInput = nil', main)
        self.assertNotIn('NSPasteboard.general.string(forType: .string)', client)
        self.assertIn('kSecClassGenericPassword', client)

    def test_external_api_reports_are_read_only_and_opt_in(self):
        client = source('Sources/AIChecker/ExternalAPIClient.swift')
        core = source('Sources/AICheckerCore/ExternalAPIUsage.swift')
        main = source('Sources/AIChecker/main.swift')
        for host in ['api.openai.com', 'api.cursor.com', 'management-api.x.ai']:
            self.assertIn(host, client)
        for field in ['kSecClassGenericPassword', 'NSSecureTextField', 'stop()', 'disconnect()']:
            self.assertIn(field, client + main)
        self.assertIn('900', client)
        self.assertIn('NoAPIRedirectDelegate', client)
        self.assertIn('URLSessionConfiguration.ephemeral', client)
        self.assertIn('config.httpShouldSetCookies = false', client)
        self.assertIn('limitReached', core)
        self.assertIn('has_more', core)
        self.assertIn('externalClients[kind]?.configured == true', main)
        self.assertIn('API REPORTS  /  公式API使用量', main)
        self.assertNotIn('print(secret)', client)
        self.assertNotIn('String(data: data ?? Data()', client)
        self.assertNotIn('keychainSecret', source('Sources/AICheckerCore/ExternalAPIUsage.swift'))

    def test_identity_and_upgrade_signature(self):
        installer = source('scripts/install-local.sh')
        self.assertIn('dev.aichecker.localapp', installer)
        self.assertIn('<string>1.10.1</string>', installer)
        self.assertIn('get_req "$DEST"', installer)
        self.assertNotIn('tccutil reset', installer)

    def test_icon_is_third_choice_and_persisted(self):
        main = source('Sources/AIChecker/main.swift')
        settings = source('Sources/AICheckerCore/DisplayPreferences.swift')
        art = source('Sources/AIChecker/StatusArtwork.swift')
        self.assertIn('addDisplaySettingsMenu(to: menu)', main)
        self.assertIn('"各AIのアイコン"', source("Sources/AIChecker/PersistentSettingsPanel.swift"))
        self.assertIn('case icon', settings)
        self.assertIn('ProviderIconArtwork.draw', art)
        self.assertIn('var cursor: CGFloat = 0', art)
        self.assertIn('saved', main)

    def test_provider_account_distinction(self):
        registry = source('Sources/AICheckerCore/AIProviderRegistry.swift')
        self.assertIn('id: "codex"', registry)
        self.assertIn('id: "chatgpt"', registry)
        self.assertIn('not-available-chat-consumer-quota', registry)
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('AIサービスを追加…', main)
        self.assertIn('where AIProviderRegistry.isImplemented(provider.id)', main)
        self.assertIn('where AIProviderRegistry.isImplemented(provider.id)', main)

    def test_one_timer_and_lifecycle(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertEqual(main.count('Timer(timeInterval: RefreshPolicy.interval'), 1)
        self.assertIn('willSleepNotification', main)
        self.assertIn('didWakeNotification', main)
        self.assertIn('providerHealth.sleep()', main)
        self.assertIn('providerHealth.wake()', main)
        self.assertIn('providerHealth.begin(adapter.providerID', main)

    def test_live_adapters_and_retry_errors(self):
        live = source('Sources/AIChecker/LiveProviderAdapter.swift')
        core = source('Sources/AICheckerCore/ProviderRuntime.swift')
        self.assertIn('extension CodexAccountClient: LiveProviderAdapter', live)
        self.assertIn('extension ClaudeWebSession: LiveProviderAdapter', live)
        self.assertIn('case 429', core)
        self.assertIn('rateLimited', core)
        self.assertIn('reauthenticationRequired', core)
        self.assertIn('retryAfter', core)

    def test_packaged_icons_and_official_copilot_meter(self):
        art = source('Sources/AIChecker/StatusArtwork.swift')
        installer = source('scripts/install-local.sh')
        client = source('Sources/AIChecker/CopilotBillingClient.swift')
        core = source('Sources/AICheckerCore/CopilotBilling.swift')
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('private static let iconWidth: CGFloat = 21', art)
        self.assertIn('width: 21, height: 21', art)
        for name in ('codex', 'claude'):
            self.assertFalse((ROOT / 'Sources/AIChecker/Assets' / (name + '.png')).exists())
        self.assertIn('ProviderIconArtwork', source('Sources/AIChecker/ProviderIconArtwork.swift'))
        self.assertIn('Third-party logos are not distributed', installer)
        self.assertIn('dev.aichecker.localapp.github-copilot-billing', client)
        self.assertIn('SecItemCopyMatching', client)
        self.assertIn('SecItemDelete', client)
        self.assertIn('premium_request/usage', client)
        self.assertIn('CopilotBillingDecoder.decode', client)
        self.assertIn('grossQuantity', core)
        self.assertIn('copilotClient.requestUsage', main)
        self.assertIn('monthlyCopilotUsage: currentCopilotBarUsage', main)
        self.assertIn('monthlyCopilotUsage: CopilotPremiumUsage?', art)
        self.assertIn('github-copilot-billing', client)
        self.assertNotIn('print(secret)', client)

    def test_github_errors_are_distinct_and_do_not_expose_secrets(self):
        client = source('Sources/AIChecker/CopilotBillingClient.swift')
        core = source('Sources/AICheckerCore/CopilotBilling.swift')
        provider = source('Sources/AICheckerCore/ProviderRuntime.swift')
        self.assertIn('X-RateLimit-Remaining', client)
        self.assertIn('CopilotHTTPDiagnostic.failure', client)
        self.assertIn('CopilotHTTPDiagnostic.message', client)
        self.assertIn('case .permissionDenied:', provider)
        self.assertIn('case .resourceUnavailable:', provider)
        self.assertIn('Account permissions', source('Sources/AIChecker/main.swift'))
        self.assertNotIn('print(secret)', client)
        self.assertNotIn('String(data: data ?? Data()', client)

    def test_personal_copilot_billing_is_opt_in_only(self):
        main = source('Sources/AIChecker/main.swift')
        client = source('Sources/AIChecker/CopilotBillingClient.swift')
        access = source('Sources/AICheckerCore/CopilotAccessPolicy.swift')
        self.assertIn('case freeOrNotSubscribed', access)
        self.assertIn('case organizationBilled', access)
        self.assertIn('case undetermined', access)
        self.assertIn('self == .personallyBilled', access)
        self.assertIn('loadCopilotAccessMode()', main)
        self.assertIn('AIChecker.v163.copilotAccessMode', main)
        self.assertIn('copilotAccessMode.permitsPersonalBillingAPI && copilotClient.configured', main)
        self.assertIn('copilotClient.allowBillingRequests = false', main)
        self.assertIn('copilotClient.stop()', main)
        self.assertIn('copilotClient.allowBillingRequests = selected.permitsPersonalBillingAPI', main)
        self.assertIn('guard copilotAccessMode.permitsPersonalBillingAPI else { return }', main)
        self.assertIn('guard allowBillingRequests, !stopped, task == nil', client)
        self.assertIn('var allowBillingRequests = false', client)
        self.assertIn('保存済みトークンを削除して切断', source('Sources/AIChecker/PersistentAccountsPanel.swift'))
        self.assertIn('UserDefaults.standard.set(selected.rawValue, forKey: copilotAccessKey)', main)
        self.assertNotIn('tccutil reset', main)
        self.assertNotIn('SecItemDelete', main)

    def test_claude_profile_switch_restores_isolated_refresh_hook(self):
        main = source('Sources/AIChecker/main.swift')
        # Each call has exactly one declared handler; macOS type checking is
        # additionally performed by scripts/check.sh on a Mac.
        self.assertEqual(main.count('private func changedClaudeProfile()'), 1)
        self.assertEqual(main.count('changedClaudeProfile()'), 4)
        body = main.split('private func changedClaudeProfile() {', 1)[1].split('\n    }', 1)[0]
        for part in ['providerHealth.reset("claude")', 'configureClaudeWebSession()',
                     'snapshots.removeValue(forKey: "claude")', 'lastDisplayKey = nil',
                     'refresh(force: true)', 'renderUI()']:
            self.assertIn(part, body)
        self.assertLess(body.index('configureClaudeWebSession()'),
                        body.index('snapshots.removeValue(forKey: "claude")'))

    def test_manual_bundle_images_are_excluded_from_swiftpm(self):
        pkg = source('Package.swift')
        installer = source('scripts/install-local.sh')
        self.assertNotIn('exclude: ["Assets"]', pkg)
        self.assertIn('if [[ -d "$ROOT/Sources/AIChecker/Assets" ]]', installer)
        self.assertIn('Contents/Resources/$icon.png', installer)

    def test_native_branching_settings_stay_open(self):
        main = source('Sources/AIChecker/main.swift')
        row = source('Sources/AIChecker/StayOpenMenuRow.swift')
        art = source('Sources/AIChecker/StatusArtwork.swift')
        compact = source('Sources/AICheckerCore/CompactLayout.swift')
        self.assertIn('addDisplaySettingsMenu(to: menu)', main)
        self.assertIn('let menu = NSMenu(title: "表示設定")', main)
        self.assertIn('item.submenu = menu', main)
        self.assertIn('addStayOpenRow(', main)
        self.assertIn('checked: { selected() == value }', main)
        self.assertIn('savePreferences()', main)
        self.assertIn('menuIsTracking', main)
        self.assertIn('menuDidClose(_ menu: NSMenu)', main)
        self.assertIn('if menuIsTracking {', main)
        self.assertIn('item.view = row', main)
        self.assertIn('mouseUp(with event: NSEvent)', row)
        self.assertNotIn('cancelTracking()', row)
        self.assertNotIn('performActionForItem', row)
        self.assertNotIn('presentPersistentSettings()', main)
        self.assertNotIn('showPersistentSettings()', main)
        self.assertIn('static let height: CGFloat = 27', art)
        self.assertIn('statusButtonExtraWidth: Double = 0', compact)

    def test_account_management_branches_without_separate_window(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('addAccountsSubmenu("Codexアカウント管理"', main)
        self.assertIn('addAccountsSubmenu("Claudeアカウント管理"', main)
        self.assertIn('addAccountsSubmenu("AIサービスを追加…"', main)
        self.assertIn('if copilotClient.configured && copilotAccessMode.permitsPersonalBillingAPI {', main)
        self.assertIn('addAccountsSubmenu("GitHub Copilotアカウント管理"', main)
        self.assertIn('item.submenu = menu', main)
        self.assertIn('command("アカウントを追加…", .addCodex)', main)
        self.assertIn('command("プロフィールを追加…", .addClaude)', main)
        self.assertNotIn('presentAccountsPanel(', main)
        self.assertNotIn('openAccountsPanel(', main)
        self.assertNotIn('window?.makeKeyAndOrderFront(nil)', main)
        self.assertNotIn('表示設定を続けて変更…', main)

    def test_all_inplace_menu_actions_stay_open(self):
        main = source('Sources/AIChecker/main.swift')
        row = source('Sources/AIChecker/StayOpenMenuRow.swift')
        self.assertIn('addStayOpenRow("今すぐ更新", to: menu', main)
        self.assertIn('addStayOpenRow("ログイン項目の承認・状態を確認…", to: menu)', main)
        self.assertNotIn('NSMenuItem(title: fetching ? "取得中…"', main)
        self.assertNotIn('action: #selector(openLoginItemsSettings), keyEquivalent:', main)
        self.assertIn('action: #selector(refreshNow), keyEquivalent: "r"', main)  # Cmd+R retained
        self.assertIn('enabledWhen: @escaping () -> Bool', main)
        self.assertIn('enabledWhen: @escaping () -> Bool', row)
        self.assertIn('guard available() else { return }', row)
        self.assertIn('let shouldActivate = available() && inside', row)
        self.assertIn('item.view = row', main)
        self.assertNotIn('cancelTracking()', row)
        self.assertNotIn('performActionForItem', row)
        # A refresh completion must invalidate its live row even when there is
        # no active Claude statusLine snapshot to update.
        self.assertIn('self.fetching = false', main)
        self.assertIn('// A menu may still be tracked:', main)
        self.assertIn('self.renderUI()\n                if self.refreshAfterWake', main)

    def test_service_catalog_branches_and_live_connection_state(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('addAccountsSubmenu("Codexの接続設定", section: .codex', main)
        self.assertIn('addAccountsSubmenu("Claudeの接続設定", section: .claude', main)
        self.assertIn('addAccountsSubmenu("GitHub Copilotを接続", section: .copilot', main)
        self.assertIn('addConsumerProviderSubmenu(id, to: menu)', main)
        self.assertIn('addExternalAPIProviderSubmenu(kind, to: menu)', main)
        self.assertIn('addAccountsSubmenu("AIサービスを追加…", section: .catalog', main)
        self.assertNotIn('addAccountsSubmenu("追加APIアカウント管理"', main)
        self.assertNotIn('addUnsupportedProviderSubmenu(', main)
        api_section = main.split('private func addExternalAPIProviderSubmenu(', 1)[1].split('private func addConsumerProviderSubmenu(', 1)[0]
        self.assertIn('let currentPeriod = ExternalAPIUsage.startOfUTCMonth(Date())', api_section)
        self.assertIn('APIキーを登録・更新…', api_section)
        self.assertIn('キーを削除して切断…', api_section)
        consumer_section = main.split('private func addConsumerProviderSubmenu(', 1)[1].split('// MARK: - Consumer web browsing', 1)[0]
        self.assertIn('公式サイトを開く…', consumer_section)
        self.assertIn('openConsumerExternally(id)', consumer_section)
        self.assertIn('editConsumerNote(id)', consumer_section)
        self.assertIn('手動記録を削除', consumer_section)
        for obsolete in ['openConsumerWeb(id)', 'eraseConsumerWeb(id)', '公式サイトを専用ブラウザーで開く', '既定ブラウザーで公式サイト', '未対応']:
            self.assertNotIn(obsolete, consumer_section)

        self.assertNotIn('command("Codexの接続設定", .providerInfo', main)
        self.assertNotIn('command("GitHub Copilotを接続", .providerInfo', main)
        self.assertIn('self?.copilotAccessMode.permitsPersonalBillingAPI', main)
        self.assertIn('self?.externalClients[kind]?.configured ?? false', main)
        self.assertIn('self?.accountConfig.activeClaude != nil', main)
        self.assertNotIn('presentAccountsPanel(', main)
        self.assertNotIn('showPersistentSettings()', main)

    def test_reset_countdowns_and_quota_thresholds(self):
        view = source('Sources/AIChecker/UsageDashboardMenuView.swift')
        artwork = source('Sources/AIChecker/StatusArtwork.swift')
        policy = source('Sources/AICheckerCore/UsageVisualPolicy.swift')
        palette = source('Sources/AIChecker/QuotaColorPalette.swift')
        self.assertIn('resetAt: snapshot?.fiveHour.resetsAt', view)
        self.assertIn('resetAt: snapshot?.weekly.resetsAt', view)
        self.assertIn('let now = Date()', view)
        self.assertIn('TelemetryFreshness.isRecent(snapshot, now: now)', view)
        self.assertIn('ResetCountdown.format', view)
        self.assertIn('QuotaColorPalette.color(for: percent)', view)
        self.assertIn('QuotaColorPalette.color(for: value)', artwork)
        self.assertIn('let nameColor = color(', artwork)
        self.assertIn('if displayed >= 70', policy)
        self.assertIn('if displayed >= 40', policy)
        self.assertIn('if displayed >= 20', policy)
        self.assertIn('return .red', policy)
        self.assertIn('Awaiting update', policy)
        self.assertIn('case .yellow:', palette)
        self.assertIn('case .red:', palette)

    def test_public_claude_has_no_nonpublic_auto_fetch(self):
        session = source('Sources/AIChecker/ClaudeWebSession.swift')
        main = source('Sources/AIChecker/main.swift')
        self.assertNotIn('callAsyncJavaScript', session)
        self.assertNotIn('fetch(', session)
        self.assertNotIn('Claude専用ブラウザでログイン…', main)
        self.assertIn('ClaudeStatusLineSource(profileID: profileID)', main)

    def test_staged_update_stops_only_the_installed_app_and_auto_opens(self):
        script = source('scripts/install-local.sh')
        self.assertIn('running_installed_app_pids()', script)
        self.assertIn('kill -TERM', script)
        self.assertIn('open "$DEST"', script)
        self.assertLess(script.index('codesign --verify --strict --verbose=2 "$STAGE"'),
                        script.index('running_installed_app_pids()'))
        self.assertNotIn('pkill -x AIChecker', script)

    def test_dashboard_exactly_one_duration_per_quota(self):
        view = source('Sources/AIChecker/UsageDashboardMenuView.swift')
        self.assertIn('rowLabels[0]', view)
        self.assertIn('rowLabels[1]', view)
        self.assertIn('ResetsAt', view.replace('resetsAt','ResetsAt'))
        self.assertIn('meterWidth', view)
        self.assertIn('writeCountdown(countdown', view)
        self.assertNotIn('drawCountdown("5h ·', view)

    def test_dashboard_alignment_uses_shared_guides_not_magic_offsets(self):
        view = source('Sources/AIChecker/UsageDashboardMenuView.swift')
        layout = source('Sources/AICheckerCore/UsageMenuPresentation.swift')
        self.assertIn('resetCaptionRightX = durationRightX', layout)
        self.assertIn('rightX: CGFloat(UsageMenuPresentation.resetCaptionRightX)', view)
        self.assertIn('rightX: CGFloat(UsageMenuPresentation.durationRightX)', view)
        self.assertIn('centerY: headerY', view)
        self.assertIn('y: headerY - iconSize / 2', view)
        self.assertIn('centerY: CGFloat(UsageMenuPresentation.fiveHourRowCenterY)', view)
        self.assertIn('centerY: CGFloat(UsageMenuPresentation.weekRowCenterY)', view)
        self.assertIn('metrics.height / 2', view)
        self.assertIn('rightX - metrics.width', view)
        self.assertNotIn('atX: 454', view)
        self.assertNotIn('y: 83', view)
        self.assertNotIn('y: 89', view)

    def test_privacy_and_stale_handling(self):
        main = source('Sources/AIChecker/main.swift')
        self.assertIn('for (id, snapshot) in snapshots where !TelemetryFreshness.isRecent', main)
        self.assertNotIn('auth.json', main)
        self.assertNotIn('access_token', main)
        self.assertNotIn('refresh_token', main)
        for swift in (ROOT / 'Sources/AIChecker').glob('*.swift'):
            self.assertNotIn('CodexBar', swift.read_text())

if __name__ == '__main__':
    unittest.main(verbosity=2)
