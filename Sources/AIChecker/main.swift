import AppKit
import Foundation
import ServiceManagement
import AICheckerCore

final class AICheckerApplication: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var menuIsTracking = false
    private let networkSpeed = OnDemandNetworkSpeed()
    private weak var speedHeader: UsageSpeedHeaderView?
    private var liveMenuRows: [StayOpenMenuRow] = []
    private var pendingMenuRefresh = false
    private var refreshTimer: Timer?
    private var sleeping = false
    private var refreshAfterWake = false
    private var lastDisplayKey: RefreshPolicy.DisplayKey?
    private var lastAttempt: Date = .distantPast
    private var lastSuccess: Date?
    private var lastError: String?
    private var snapshots: [String: AIQuotaSnapshot] = [:]
    private var fetching = false
    private let quotaNotifier = QuotaNotificationCenter()
    private let quotaNotificationSettingsKey = "AIChecker.v190.quotaNotificationSettings"
    private let quotaNotificationHistoryKey = "AIChecker.v190.quotaNotificationHistory"
    private var quotaNotificationSettings = QuotaNotificationPreferences()
    private var quotaNotificationMonitor = QuotaNotificationMonitor()
    private let fetchQueue = DispatchQueue(label: "AI Checker.usage", qos: .utility)
    private let catalog = AIProviderRegistry.catalog
    private var providerHealth = ProviderRefreshCoordinator()
    // Claude Status Line source is bound to the selected profile on each fetch.
    private let accountPreferencesKey = "AIChecker.v13.accounts" // v1.3 format migrated in-place
    private var accountConfig = AccountConfiguration()
    private var codexClient: CodexAccountClient?
    private let copilotClient = CopilotBillingClient()
    private var copilotAccessMode: CopilotAccessMode = .undetermined
    private weak var copilotTokenInput: NSSecureTextField?
    private var copilotReport: CopilotPremiumUsage?
    private var copilotState = "未接続"
    private let externalClients: [ExternalAPIKind: ExternalAPIClient] = Dictionary(
        uniqueKeysWithValues: ExternalAPIKind.allCases.map { ($0, ExternalAPIClient(kind: $0)) })
    private var externalReports: [ExternalAPIKind: ExternalAPIReport] = [:]
    private var externalStates: [ExternalAPIKind: String] = [:]
    // Five consumer web sites have first-party browsing and user observations,
    // not an officially documented consumer-quota reader.
    private var consumerWebSessions: [String: ConsumerWebSession] = [:]
    private let consumerNotesKey = "AIChecker.consumer.v1.manualNotes"
    private var consumerNotes: [String: ConsumerUsageNote] = [:]
    private var connectedCodexProfileID: UUID?
    private var claudeWebClient: ClaudeWebSession?
    private var claudeWebState = "未接続（任意の実験機能）"
    private var codexState = "未設定（アカウントを追加してください）"
    private let preferencesKey = "AIChecker.v1.displaySettings"
    private let legacyPreferencesKey = "MenuPilot.v03.displayPreferences"
    private let loginPreferenceKey = "AIChecker.v1.launchAtLogin"
    private let copilotMenuBarKey = "AIChecker.v16.copilotMenuBar"
    // Selection is separate from credentials and quota snapshots; old display JSON stays compatible.
    private let apiMenuBarSelectionKey = "AIChecker.v110.apiMenuBarSelection"
    private var selectedAPIMenuBarIDs = Set<String>()
    private let copilotAccessKey = "AIChecker.v163.copilotAccessMode"
    private var wantsLaunchAtLogin = true
    private var loginRegistrationError: String?
    private var preferences = AICheckerSettings()
    // Explicit user-controlled fallback; macOS does not expose reliable status-item occlusion.
    private let menuBarModeKey = "AIChecker.v193.menuBarMode"
    private let shortcutEnabledKey = "AIChecker.v193.globalShortcutEnabled"
    private let shortcutPresetKey = "AIChecker.v193.shortcutPreset"
    private var menuBarMode: MenuBarPresentation = .standard
    private var shortcutEnabled = true
    private var shortcutPreset: QuickPanelShortcut = .defaultShortcut
    private let globalHotkey = GlobalUsageHotkey()
    private let quickPanel = UsageQuickPanel()
    private let demo = ProcessInfo.processInfo.environment["AI_CHECKER_DEMO"] == "1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Explicitly load the signed bundle icon for AppKit UI surfaces.
        // Finder/Spotlight/Notification Center may have independent OS caches;
        // this does not modify those caches or the installed app signature.
        configureApplicationIcon()
        installStandardEditCommands()
        loadPreferences()
        loadQuickAccessPreferences()
        loadAccounts()
        loadCopilotAccessMode()
        loadConsumerNotes()
        loadQuotaNotifications()
        loadAPIMenuBarSelection()
        configureLaunchAtLogin()
        subscribeToPowerEvents()
        createStatusItem()
        configureQuickAccess()
        for unsupported in AIProviderRegistry.planned where !AIProviderRegistry.supportsUsageReport(unsupported.id) {
            providerHealth.setAuth(unsupported.id, .unsupported)
        }
        if !demo {
            configureCopilotCallbacks()
            configureExternalAPICallbacks()
            connectSelectedAccount()
            configureClaudeWebSession()
        }
        if demo {
            let now = Date()
            snapshots = [
                "codex": AIQuotaSnapshot(providerID: "codex", fiveHour: .init(remainingPercent: 93, resetsAt: nil), weekly: .init(remainingPercent: 76, resetsAt: nil), updatedAt: now, source: "DEMO"),
                "claude": AIQuotaSnapshot(providerID: "claude", fiveHour: .init(remainingPercent: 73, resetsAt: nil), weekly: .init(remainingPercent: 53, resetsAt: nil), updatedAt: now, source: "DEMO")
            ]
            lastSuccess = now
        }
        renderUI()
        if !demo { refresh(force: true) }
        startRefreshTimer()
        // One-time discoverability: if the menu bar is full on first launch,
        // the user still learns the keyboard entry point to this independent panel.
        if !demo && !UserDefaults.standard.bool(forKey: "AIChecker.v193.quickAccessWelcomeShown") {
            UserDefaults.standard.set(true, forKey: "AIChecker.v193.quickAccessWelcomeShown")
            DispatchQueue.main.async { [weak self] in self?.showQuickPanel() }
        }
    }

    /// Opening AI Checker again from Spotlight or Finder must reveal a window
    /// even when macOS has hidden the status item due to menu-bar crowding.
    /// Reopening an already running LSUIElement app should not spawn another
    /// process or alter user preferences, accounts, or notification state.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.showQuickPanel()
        }
        return false  // The quick panel handles its own focus/visibility.
    }

    private func configureApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL), icon.isValid else {
            NSLog("AI Checker: signed app icon resource is unavailable")
            return
        }
        NSApp.applicationIconImage = icon
    }

    // Accessory/menu-bar-only apps do not necessarily have the standard Edit menu.
    // Without the Paste key equivalent, Cmd+V can beep in NSAlert text inputs.
    private func installStandardEditCommands() {
        let mainMenu = NSMenu(title: "AI Checker")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, action, shortcut) in [
            ("Undo", "undo:", "z"),
            ("Cut", "cut:", "x"),
            ("Copy", "copy:", "c"),
            ("Paste", "paste:", "v"),
            ("Select All", "selectAll:", "a")
        ] {
            let menuItem = NSMenuItem(title: title,
                                      action: NSSelectorFromString(action),
                                      keyEquivalent: shortcut)
            menuItem.keyEquivalentModifierMask = [.command]
            menuItem.target = nil // First Responder (the active NSTextField editor)
            editMenu.addItem(menuItem)
        }
        mainMenu.addItem(editItem)
        mainMenu.setSubmenu(editMenu, for: editItem)
        // Mouse clicks on the status menu use StayOpenMenuRow. Keep the
        // pre-existing Cmd+R shortcut on the app's keyboard command menu.
        let actionsItem = NSMenuItem(title: "Actions", action: nil, keyEquivalent: "")
        let actionsMenu = NSMenu(title: "Actions")
        let refreshItem = NSMenuItem(title: AppL10n.text("今すぐ更新"), action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.keyEquivalentModifierMask = [.command]
        actionsMenu.addItem(refreshItem)
        let panelItem = NSMenuItem(title: AppL10n.text("利用状況パネルを開く"), action: #selector(showQuickPanel), keyEquivalent: "")
        panelItem.target = self
        actionsMenu.addItem(panelItem)
        mainMenu.addItem(actionsItem)
        mainMenu.setSubmenu(actionsMenu, for: actionsItem)
        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        networkSpeed.stop()
        stopRefreshTimer()
        globalHotkey.unregister()
        quickPanel.close()
        codexClient?.stopAndWait()
        claudeWebClient?.stop()
        copilotClient.stop()
        externalClients.values.forEach { $0.stop() }
        consumerWebSessions.values.forEach { $0.stop() }
        consumerWebSessions.removeAll()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // A single coalescible one-minute timer replaces the old 10-second UI poll.
    private func startRefreshTimer() {
        stopRefreshTimer()
        guard !demo, !sleeping else { return }
        let timer = Timer(timeInterval: RefreshPolicy.interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = RefreshPolicy.timerTolerance
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func subscribeToPowerEvents() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep(_:)),
                           name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake(_:)),
                           name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func willSleep(_ notification: Notification) {
        sleeping = true
        providerHealth.sleep()
        networkSpeed.stop()
        stopRefreshTimer()
        codexClient?.stopAndWait()
        copilotClient.stop()
        externalClients.values.forEach { $0.stop() }
        claudeWebClient?.stop() // prevent stale WebKit work during sleep
        claudeWebClient = nil   // a fresh profile-scoped client is made on wake
        // The single one-minute timer is stopped; no new fetches start asleep.
    }

    @objc private func didWake(_ notification: Notification) {
        sleeping = false
        providerHealth.wake()
        copilotClient.resume()
        externalClients.values.forEach { $0.resume() }
        connectSelectedAccount()
        configureClaudeWebSession()
        if menuIsTracking { startMenuNetworkSpeed() }
        startRefreshTimer()
        if fetching {
            refreshAfterWake = true
        } else {
            refresh(force: true) // One immediate post-wake refresh.
        }
    }

    private func configureLaunchAtLogin() {
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: loginPreferenceKey) as? Bool {
            wantsLaunchAtLogin = saved
        } else {
            wantsLaunchAtLogin = true
            defaults.set(true, forKey: loginPreferenceKey)
        }
        // This registers the MAIN app only. No helper or LaunchAgent is created.
        // macOS may require approval in System Settings before it starts at login.
        guard !demo, wantsLaunchAtLogin, SMAppService.mainApp.status == .notRegistered else { return }
        do {
            try SMAppService.mainApp.register()
            loginRegistrationError = nil
        } catch {
            loginRegistrationError = error.localizedDescription
        }
    }

    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let saved = try? JSONDecoder().decode(AICheckerSettings.self, from: data) {
            preferences = saved
            preferences.visibleProviderIDs.removeAll { !AIProviderRegistry.isImplemented($0) }
            return
        }
        // Read old preferences, but do not inherit menu-bar AX/accessibility settings.
        let previous = UserDefaults(suiteName: "dev.menupilot.localapp")
        let old = UserDefaults.standard.data(forKey: legacyPreferencesKey)
            ?? previous?.data(forKey: legacyPreferencesKey)
        if let data = old, let decoded = try? JSONDecoder().decode(DisplayPreferences.self, from: data) {
            preferences = AICheckerSettings.migrated(from: decoded)
            savePreferences()
        }
    }

    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: preferencesKey)
        }
        lastDisplayKey = nil // settings affect artwork even if usage values did not change
        renderUI()
    }

    private func loadQuickAccessPreferences() {
        if let raw = UserDefaults.standard.string(forKey: menuBarModeKey),
           let mode = MenuBarPresentation(rawValue: raw) { menuBarMode = mode }
        // Enabled by default, but never change system-wide keyboard settings.
        if let value = UserDefaults.standard.object(forKey: shortcutEnabledKey) as? Bool {
            shortcutEnabled = value
        }
        if let raw = UserDefaults.standard.string(forKey: shortcutPresetKey),
           let preset = QuickPanelShortcut(rawValue: raw) { shortcutPreset = preset }
    }

    private func configureQuickAccess() {
        globalHotkey.onActivate = { [weak self] in self?.showQuickPanel() }
        if shortcutEnabled { globalHotkey.register(shortcutPreset) }
    }

    private func setMenuBarMode(_ mode: MenuBarPresentation) {
        guard menuBarMode != mode else { return }
        menuBarMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: menuBarModeKey)
        lastDisplayKey = nil
        renderUI()
    }

    private func setShortcut(enabled: Bool, preset: QuickPanelShortcut) {
        shortcutEnabled = enabled
        shortcutPreset = preset
        UserDefaults.standard.set(enabled, forKey: shortcutEnabledKey)
        UserDefaults.standard.set(preset.rawValue, forKey: shortcutPresetKey)
        globalHotkey.unregister()
        if enabled { globalHotkey.register(preset) }
        renderUI()
    }

    private func configureQuickPanelControls() {
        quickPanel.configure(mode: menuBarMode, shortcut: shortcutPreset,
            shortcutEnabled: shortcutEnabled, shortcutError: globalHotkey.errorMessage,
            onMode: { [weak self] mode in self?.setMenuBarMode(mode) },
            onShortcut: { [weak self] enabled, key in
                self?.setShortcut(enabled: enabled, preset: key)
            })
    }

    @objc private func showQuickPanel() {
        configureQuickPanelControls()
        quickPanel.present(catalog: catalog.filter { AIProviderRegistry.isImplemented($0.id) },
                           snapshots: displaySnapshots,
                           failures: providerHealth.states.mapValues { $0.lastFailure },
                           onRefresh: { [weak self] in self?.refresh(force: true) },
                           onGuide: { [weak self] in self?.showMenuBarHelp() })
    }

    private func showMenuBarHelp() {
        let alert = NSAlert()
        alert.messageText = AppL10n.text("メニューバーにAI Checkerが表示されない場合")
        alert.informativeText = AppL10n.text("メニューバーに空きがないと、macOSがアイコンを表示できないことがあります。\n\n") +
            AppL10n.text("1. AI Checkerの表示設定で『アイコンのみ』または『省スペース』を選択します。\n") +
            AppL10n.text("2. システム設定 → メニューバー（macOSのバージョンによって項目名が異なります）で不要な標準アイコンを整理します。\n") +
            AppL10n.text("3. 他社アプリは各アプリの設定でメニューバー表示をOFFにします。\n") +
            AppL10n.text("4. AI Checkerが隠れていても、設定したショートカットで利用状況パネルを開けます。\n\n") +
            AppL10n.text("AI Checkerは他アプリのアイコンを移動・非表示にしたり、アクセシビリティ権限を要求したりしません。")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func addQuickAccessMenu(to parent: NSMenu) {
        let item = NSMenuItem(title: "省スペース・ショートカット", action: nil, keyEquivalent: "")
        MenuVisualStyle.adorn(item, symbol: "rectangle.compress.vertical")
        let menu = NSMenu(title: "省スペース・ショートカット")
        menu.autoenablesItems = false
        addChoiceMenu("メニューバーの表示", options: [
            ("通常", MenuBarPresentation.standard),
            ("省スペース（数字のみ）", .compact),
            ("アイコンのみ", .iconOnly)
        ], to: menu,
           selected: { [weak self] in self?.menuBarMode ?? .standard }) { [weak self] choice in
            self?.setMenuBarMode(choice)
        }
        menu.addItem(.separator())
        addStayOpenRow("ショートカットで開く", to: menu,
            checked: { [weak self] in self?.shortcutEnabled ?? false }) { [weak self] in
            guard let self else { return }
            self.setShortcut(enabled: !self.shortcutEnabled, preset: self.shortcutPreset)
        }
        addChoiceMenu("ショートカットのキー", options: [
            ("⌃⌥⌘ A", QuickPanelShortcut.defaultShortcut),
            ("⌃⌥⌘ U", .alternativeShortcut)
        ], to: menu,
           selected: { [weak self] in self?.shortcutPreset ?? .defaultShortcut }) { [weak self] preset in
            self?.setShortcut(enabled: self?.shortcutEnabled ?? true, preset: preset)
        }
        if let error = globalHotkey.errorMessage, shortcutEnabled {
            let hint = NSMenuItem(title: AppL10n.format("割り当てに失敗: %@", error), action: nil, keyEquivalent: "")
            menu.addItem(hint)
        }
        addStayOpenRow("利用状況パネルを開く", to: menu,
                       symbolName: "rectangle.on.rectangle") { [weak self] in
            self?.showQuickPanel()
        }
        addStayOpenRow("メニューバーの整理方法…", to: menu,
                       symbolName: "questionmark.circle") { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.showMenuBarHelp() }
        }
        item.submenu = menu
        parent.addItem(item)
    }

    /// Do NOT infer paid eligibility from an old PAT or from HTTP status codes.
    /// On upgrade we deliberately default to API-off, without removing saved tokens.
    private func loadCopilotAccessMode() {
        copilotAccessMode = CopilotAccessMode.restored(
            UserDefaults.standard.string(forKey: copilotAccessKey))
        copilotClient.allowBillingRequests = copilotAccessMode.permitsPersonalBillingAPI
    }

    private func createStatusItem() {
        // Do not create menu-bar separators, accessory status items or AX UI.
        // Let AppKit track the natural image width. A fixed length retained
        // a large highlighted area after switching to "numbers only" while
        // the menu and its native submenus were being tracked.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "AIChecker.QuotaStatus.v1"
        item.button?.imagePosition = .imageOnly
        statusItem = item
    }

    private func tick() {
        guard !sleeping else { return }
        // Check freshness once per minute; redraw only if stale state changed.
        renderUI()
        refresh(force: false)
    }

    private func refresh(force: Bool) {
        guard !demo, !sleeping, !fetching else { return }
        if !force && Date().timeIntervalSince(lastAttempt) < RefreshPolicy.interval { return }
        fetching = true
        lastAttempt = Date()
        let now = Date()
        var activeAdapters: [any LiveProviderAdapter] = []
        if let codexClient = codexClient { activeAdapters.append(codexClient) }
        if let claudeWebClient = claudeWebClient { activeAdapters.append(claudeWebClient) }
        if copilotAccessMode.permitsPersonalBillingAPI && copilotClient.configured { activeAdapters.append(copilotClient) }
        for adapter in activeAdapters {
            if providerHealth.begin(adapter.providerID, now: now, forced: force) {
                adapter.requestUsage(force: force)
            }
        }
        for kind in ExternalAPIKind.allCases {
            guard let client = externalClients[kind], client.configured,
                  client.shouldPoll(now: now, force: force) else { continue }
            if providerHealth.begin(kind.rawValue, now: now, forced: force) {
                client.requestUsage(force: force)
            }
        }
        let requestedClaude = claudeWebClient == nil ? accountConfig.activeClaudeID : nil
        fetchQueue.async { [weak self] in
            guard let self = self else { return }
            let result: SourceOutcome
            if let profileID = requestedClaude {
                result = UsagePipeline(sources: [ClaudeStatusLineSource(profileID: profileID)]).fetch()
            } else {
                result = SourceOutcome(snapshots: [:], errors: [])
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.fetching = false
                if !self.sleeping && self.accountConfig.activeClaudeID == requestedClaude {
                    // Missing/expired telemetry must never display a previous account's percentage.
                    if let fresh = result.snapshots["claude"] {
                        if let accountID = requestedClaude { self.observeQuota(fresh, accountID: accountID) }
                        self.snapshots["claude"] = fresh
                        self.lastSuccess = Date()
                        self.providerHealth.succeed("claude", now: Date())
                    } else {
                        self.snapshots.removeValue(forKey: "claude")
                    }
                    self.lastError = result.errors.isEmpty ? nil : result.errors.joined(separator: "; ")
                }
                // A menu may still be tracked: refresh the live rows regardless
                // of whether the statusLine fallback profile matched.
                self.renderUI()
                if self.refreshAfterWake && !self.sleeping {
                    self.refreshAfterWake = false
                    self.refresh(force: true)
                }
            }
        }
    }

    private var displaySnapshots: [String: AIQuotaSnapshot] {
        var shown = snapshots
        // Any stale observation is retained as history but never presented as
        // fresh quota, including Codex App Server values and Claude Web/Status Line.
        // Each provider is evaluated independently; one stale AI cannot erase another.
        for (id, snapshot) in snapshots where !TelemetryFreshness.isRecent(snapshot) {
            shown[id] = AIQuotaSnapshot(providerID: id,
                fiveHour: QuotaWindow(remainingPercent: nil, resetsAt: snapshot.fiveHour.resetsAt),
                weekly: QuotaWindow(remainingPercent: nil, resetsAt: snapshot.weekly.resetsAt),
                updatedAt: snapshot.updatedAt, source: (snapshot.source ?? id) + " (stale)")
        }
        return shown
    }

    private var isStale: Bool {
        let now = Date()
        // A stale optional Claude profile should not make a fresh Codex grey.
        return !preferences.visibleProviders(in: catalog).contains { descriptor in
            return TelemetryFreshness.isRecent(snapshots[descriptor.id], now: now)
        }
    }

    private var currentCopilotBarUsage: CopilotPremiumUsage? {
        guard copilotAccessMode.permitsPersonalBillingAPI,
              UserDefaults.standard.bool(forKey: copilotMenuBarKey), let report = copilotReport else { return nil }
        let current = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: Date())
        guard report.year == current.year, report.month == current.month,
              Date().timeIntervalSince(report.observedAt) <= 3600 else { return nil }
        return report
    }

    private func renderUI() {
        guard let item = statusItem else { return }
        let presented = displaySnapshots
        let currentKey = RefreshPolicy.DisplayKey(
            snapshots: presented,
            visibleProviders: preferences.visibleProviders(in: catalog),
            stale: isStale, demo: demo)
        if currentKey != lastDisplayKey {
            let imagePreferences: AICheckerSettings = {
                var settings = preferences
                if menuBarMode == .compact {
                    settings.nameStyle = .icon
                    settings.metricStyle = .percentOnly
                    settings.providerGap = 0
                }
                return settings
            }()
            let image = (menuBarMode == .iconOnly
                ? StatusArtwork.renderLauncherIcon()
                : StatusArtwork.render(presented, stale: isStale, demo: demo,
                                       preferences: imagePreferences, catalog: catalog,
                                       monthlyCopilotUsage: currentCopilotBarUsage,
                                       monthlyAPIReports: currentAPIMenuBarLabels))
                ?? StatusArtwork.renderLauncherIcon()
            guard let image else { return }
            item.isVisible = true
            // A variable-length status item follows NSStatusBarButton's
            // content width without an explicit item.length write. This is
            // also important while the user is holding a native submenu open:
            // the compact artwork AND its highlighted region can shrink.
            item.button?.image = image
            item.button?.invalidateIntrinsicContentSize()
            item.button?.toolTip = "AI Checker — AI usage"
            item.button?.needsDisplay = true
            item.button?.displayIfNeeded()
            lastDisplayKey = currentKey
        }
        if quickPanel.isVisible {
            configureQuickPanelControls()
            quickPanel.refresh(catalog: catalog.filter { AIProviderRegistry.isImplemented($0.id) },
                               snapshots: presented,
                               failures: providerHealth.states.mapValues { $0.lastFailure })
        }
        if menuIsTracking {
            // Keep the *existing* native root + open submenu alive during
            // redraws, network callbacks, and settings changes.
            pendingMenuRefresh = true
            for row in liveMenuRows {
                row.needsDisplay = true
                row.displayIfNeeded() // update selected checks without dismissing a submenu
            }
            return
        }
        liveMenuRows.removeAll()
        let menu = NSMenu(title: "AI Checker")
        menu.autoenablesItems = false
        let speedHeader = UsageSpeedHeaderView()
        self.speedHeader = speedHeader
        let heading = NSMenuItem(title: "AI CHECKER / USAGE", action: nil, keyEquivalent: "")
        heading.view = speedHeader
        menu.addItem(heading)
        menu.addItem(.separator())
        // Every provider uses the full width. The detailed reset times and source
        // now branch into native menus rather than taking five grey rows each.
        for provider in catalog where AIProviderRegistry.isImplemented(provider.id) {
            let snap = presented[provider.id]
            let failure = providerHealth.states[provider.id]?.lastFailure
            let card = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            card.view = UsageDashboardMenuView(provider: provider, snapshot: snap, failure: failure)
            menu.addItem(card)

            let details = NSMenuItem(title: "  " + AppL10n.format("%@ Details", provider.name), action: nil, keyEquivalent: "")
            let detailsMenu = NSMenu(title: AppL10n.format("%@ Details", provider.name))
            detailsMenu.addItem(withTitle: AppL10n.format("5h残量: %@", percent(snap?.fiveHour.remainingPercent)), action: nil, keyEquivalent: "")
            detailsMenu.addItem(withTitle: AppL10n.format("週残量: %@", percent(snap?.weekly.remainingPercent)), action: nil, keyEquivalent: "")
            detailsMenu.addItem(.separator())
            detailsMenu.addItem(withTitle: AppL10n.format("5h更新: %@", dateText(snap?.fiveHour.resetsAt)), action: nil, keyEquivalent: "")
            detailsMenu.addItem(withTitle: AppL10n.format("週更新: %@", dateText(snap?.weekly.resetsAt)), action: nil, keyEquivalent: "")
            detailsMenu.addItem(withTitle: AppL10n.format("記録時刻: %@", dateText(snap?.updatedAt)), action: nil, keyEquivalent: "")
            detailsMenu.addItem(withTitle: AppL10n.format("情報源: %@", snap?.source ?? AppL10n.text("未取得")), action: nil, keyEquivalent: "")
            if let state = providerHealth.states[provider.id] {
                detailsMenu.addItem(withTitle: AppL10n.format("状態: %@", state.lastFailure?.displayMessage ?? (state.auth == .connected ? AppL10n.text("接続済み") : AppL10n.text("取得状態未確認"))), action: nil, keyEquivalent: "")
            }
            details.submenu = detailsMenu
            MenuVisualStyle.adorn(details, symbol: "chart.bar.xaxis")
            menu.addItem(details)
        }
        if copilotAccessMode.permitsPersonalBillingAPI, let report = copilotReport {
            let currentMonth = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: Date())
            if report.year == currentMonth.year && report.month == currentMonth.month {
                menu.addItem(.separator())
                menu.addItem(withTitle: AppL10n.text("GitHub Copilot（当月のPremium Requests使用量）"), action: nil, keyEquivalent: "")
                menu.addItem(withTitle: AppL10n.format("    使用数: %@ 件（上限・残量率は未取得）", String(format: "%.1f", report.grossRequests)), action: nil, keyEquivalent: "")
                menu.addItem(withTitle: AppL10n.format("    更新: %@ / 個人向け請求レポート", dateText(report.observedAt)), action: nil, keyEquivalent: "")
            }
        }
        let currentPeriod = ExternalAPIUsage.startOfUTCMonth(Date())
        let activeExternal = ExternalAPIKind.allCases.filter {
            externalClients[$0]?.configured == true
        }
        if !activeExternal.isEmpty {
            menu.addItem(.separator())
            menu.addItem(MenuVisualStyle.heading("API REPORTS  /  公式API使用量"))
            for kind in activeExternal {
                let state = externalStates[kind] ?? "未取得"
                let report = externalReports[kind]
                let current = report != nil && report!.periodStart == currentPeriod &&
                    Date().timeIntervalSince(report!.observedAt) <= 3600
                let item: String
                if current, let report = report {
                    let formatted = report.unit == "USD"
                        ? String(format: "$%.2f", report.value)
                        : String(format: "%.0f requests", report.value)
                    item = AppL10n.format("%@: %@（%@・当月）", kind.name, formatted, report.label)
                } else {
                    item = AppL10n.format("%@: 未取得 / 古いデータ", kind.name)
                }
                menu.addItem(withTitle: item, action: nil, keyEquivalent: "")
                if !current { menu.addItem(withTitle: "    \(state)", action: nil, keyEquivalent: "") }
            }
        }
        if copilotAccessMode.permitsPersonalBillingAPI && copilotClient.configured {
            menu.addItem(withTitle: AppL10n.format("    GitHub状態: %@", copilotState), action: nil, keyEquivalent: "")
        }
        if !consumerNotes.isEmpty {
            menu.addItem(.separator())
            menu.addItem(MenuVisualStyle.heading("WEB CHECK  /  手動記録（自動取得ではありません）"))
            for site in ConsumerWebAccess.destinations {
                guard let note = consumerNotes[site.id] else { continue }
                let age = note.isRecent() ? "1時間以内" : "古い記録"
                menu.addItem(withTitle: AppL10n.format("  %@: %@ ［%@・手動］", site.name, note.text, AppL10n.text(age)),
                             action: nil, keyEquivalent: "")
            }
        }
        menu.addItem(.separator())
        menu.addItem(MenuVisualStyle.heading("ACCOUNTS  /  接続"))
        // First-time Codex users should reach the official ChatGPT login in one
        // deliberate menu action when an official Codex CLI is already installed.
        addStayOpenRow("ChatGPTでかんたん接続…", to: menu,
                       enabledWhen: { [weak self] in
                           guard let self else { return false }
                           return !self.sleeping && !self.demo
                       }, symbolName: "person.crop.circle.badge.checkmark") { [weak self] in
            // NSAlert and the system browser must not be opened inside menu tracking.
            DispatchQueue.main.async { [weak self] in self?.beginEasyCodexConnection() }
        }
        addAccountsSubmenu("Codexアカウント管理", section: .codex,
                           symbol: "person.crop.circle", to: menu)
        addAccountsSubmenu("Claudeアカウント管理", section: .claude,
                           symbol: "person.crop.circle", to: menu)
        if copilotClient.configured && copilotAccessMode.permitsPersonalBillingAPI {
            addAccountsSubmenu("GitHub Copilotアカウント管理", section: .copilot,
                               symbol: "person.crop.circle", to: menu)
        }
        addAccountsSubmenu("AIサービスを追加…", section: .catalog,
                           symbol: "plus.circle", to: menu)
        menu.addItem(.separator())
        menu.addItem(MenuVisualStyle.heading("APPEARANCE  /  設定"))
        addDisplaySettingsMenu(to: menu)
        addQuickAccessMenu(to: menu)
        addQuotaNotificationMenu(to: menu)
        menu.addItem(.separator())
        addStayOpenRow("ログイン時に自動起動", to: menu,
            checked: { [weak self] in self?.wantsLaunchAtLogin ?? false }) { [weak self] in
            self?.toggleLaunchAtLogin()
        }
        if wantsLaunchAtLogin && SMAppService.mainApp.status != .enabled {
            // Native menu selection would dismiss the whole menu. The setting
            // hand-off is still an explicit OS action, not a nested AI Checker panel.
            addStayOpenRow("ログイン項目の承認・状態を確認…", to: menu) { [weak self] in
                self?.openLoginItemsSettings()
            }
        }
        if let error = loginRegistrationError {
            menu.addItem(withTitle: AppL10n.format("ログイン項目: %@", error), action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        menu.addItem(MenuVisualStyle.heading("SYNC  /  更新"))
        menu.addItem(withTitle: AppL10n.format("最終同期: %@%@", dateText(lastSuccess), isStale ? AppL10n.text("（古い／未取得）") : ""), action: nil, keyEquivalent: "")
        if let error = lastError { menu.addItem(withTitle: AppL10n.format("取得エラー: %@", error), action: nil, keyEquivalent: "") }
        if !demo {
            addStayOpenRow("今すぐ更新", to: menu,
                enabledWhen: { [weak self] in
                    guard let self else { return false }
                    return !self.fetching && !self.sleeping
                }, symbolName: "arrow.clockwise") { [weak self] in
                self?.refreshNow()
            }
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "AI Checker を終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        MenuVisualStyle.adorn(quit, symbol: "power.circle")
        menu.addItem(quit)
        menu.delegate = self
        AppL10n.apply(to: menu)
        item.menu = menu
        pendingMenuRefresh = false
    }

    // MARK: - Native branching menus that stay open on in-place changes

    func menuWillOpen(_ menu: NSMenu) {
        menuIsTracking = true
        startMenuNetworkSpeed()
    }

    private func startMenuNetworkSpeed() {
        guard menuIsTracking, !sleeping else { return }
        speedHeader?.begin()
        networkSpeed.start { [weak self] outcome in
            guard let self, self.menuIsTracking, !self.sleeping else { return }
            self.speedHeader?.show(outcome)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        networkSpeed.stop()
        speedHeader?.end()
        menuIsTracking = false
        // Avoid mutating a menu inside AppKit's tracking/close callback.
        if pendingMenuRefresh {
            DispatchQueue.main.async { [weak self] in self?.renderUI() }
        }
    }

    private func addStayOpenRow(_ title: String, to menu: NSMenu,
                                checked: @escaping () -> Bool = { false },
                                enabled: Bool = true,
                                enabledWhen: @escaping () -> Bool = { true },
                                symbolName: String? = nil,
                                action: @escaping () -> Void) {
        let row = StayOpenMenuRow(title, checked: checked,
                                  enabled: enabled, enabledWhen: enabledWhen,
                                  symbolName: symbolName, action: action)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = row
        menu.addItem(item)
        liveMenuRows.append(row)
    }

    private func addChoiceMenu<T: Equatable>(_ title: String, options: [(String, T)],
                                              to parent: NSMenu,
                                              selected: @escaping () -> T,
                                              change: @escaping (T) -> Void) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for (label, value) in options {
            addStayOpenRow(label, to: submenu,
                checked: { selected() == value }, action: { change(value) })
        }
        item.submenu = submenu
        parent.addItem(item)
    }

    private func updateDisplaySetting(_ change: (inout AICheckerSettings) -> Void) {
        var updated = preferences
        change(&updated)
        // An icon-only launcher remains available even when neither quota meter
        // is selected; never make the application impossible to reopen.

        preferences = updated
        savePreferences()   // menu remains tracked; only status artwork changes
    }

    private func addAccountsSubmenu(_ title: String, section: PersistentAccountsPanel.Section,
                                    symbol: String, to parent: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        MenuVisualStyle.adorn(item, symbol: symbol)
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        let state = accountPanelState
        func command(_ text: String, _ action: AccountPanelAction, _ enabled: Bool = true,
                     enabledWhen: @escaping () -> Bool = { true },
                     selected: @escaping () -> Bool = { false }) {
            addStayOpenRow(text, to: menu, checked: selected,
                           enabled: enabled, enabledWhen: enabledWhen) { [weak self] in
                // Auth dialogs may be modal; do not invoke them while the
                // menu is processing a mouse event.
                DispatchQueue.main.async { [weak self] in self?.performAccountPanelAction(action) }
            }
        }
        switch section {
        case .codex:
            menu.addItem(MenuVisualStyle.heading("CODEX / アカウント"))
            if state.codex.isEmpty { menu.addItem(withTitle: "未登録", action: nil, keyEquivalent: "") }
            for record in state.codex {
                command(record.label, .selectCodex(record.id), true, selected: { [weak self] in
                    self?.accountConfig.activeCodexID == record.id
                })
            }
            menu.addItem(.separator())
            command("アカウントを追加…", .addCodex)
            command("ログイン…", .loginCodex, enabledWhen: { [weak self] in self?.accountConfig.activeCodex != nil })
            command("ログアウト…", .logoutCodex, enabledWhen: { [weak self] in self?.accountConfig.activeCodex != nil })
            command("名前を変更…", .renameCodex, enabledWhen: { [weak self] in self?.accountConfig.activeCodex != nil })
            command("選択中アカウントを削除…", .removeCodex, enabledWhen: { [weak self] in self?.accountConfig.activeCodex != nil })
            command("再接続", .reconnectCodex)
            command("Codex CLIの場所を選択…", .chooseCodexCLI)
        case .claude:
            menu.addItem(MenuVisualStyle.heading("CLAUDE / プロフィール"))
            if state.claude.isEmpty { menu.addItem(withTitle: "未登録", action: nil, keyEquivalent: "") }
            for record in state.claude {
                command(record.label, .selectClaude(record.id), true, selected: { [weak self] in
                    self?.accountConfig.activeClaudeID == record.id
                })
            }
            menu.addItem(.separator())
            command("プロフィールを追加…", .addClaude)
            command("Claude Codeでログイン…", .loginClaudeCode,
                    enabledWhen: { [weak self] in self?.accountConfig.activeClaude != nil })
            command("名前を変更…", .renameClaude,
                    enabledWhen: { [weak self] in self?.accountConfig.activeClaude != nil })
            command("選択中プロフィールを削除…", .removeClaude,
                    enabledWhen: { [weak self] in self?.accountConfig.activeClaude != nil })
        case .copilot:
            menu.addItem(MenuVisualStyle.heading("COPILOT / 請求API"))
            let modeItem = NSMenuItem(title: "利用区分", action: nil, keyEquivalent: "")
            let modeMenu = NSMenu(title: "利用区分")
            modeMenu.autoenablesItems = false
            for mode in CopilotAccessMode.allCases {
                addStayOpenRow(mode.menuLabel, to: modeMenu,
                    checked: { [weak self] in self?.copilotAccessMode == mode }) { [weak self] in
                    guard let self else { return }
                    let sender = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    sender.representedObject = mode.rawValue
                    DispatchQueue.main.async { [weak self] in self?.changeCopilotAccessMode(sender) }
                }
            }
            modeItem.submenu = modeMenu
            menu.addItem(modeItem)
            command("接続・設定…", .configureCopilot,
                    enabledWhen: { [weak self] in self?.copilotAccessMode.permitsPersonalBillingAPI ?? false })
            command("今すぐ使用量を取得", .refreshCopilot,
                    enabledWhen: { [weak self] in
                        guard let self else { return false }
                        return self.copilotAccessMode.permitsPersonalBillingAPI && self.copilotClient.configured
                    })
            command("メニューバーに表示", .toggleCopilotBar,
                    enabledWhen: { [weak self] in
                        guard let self else { return false }
                        return self.copilotAccessMode.permitsPersonalBillingAPI && self.copilotClient.configured
                    },
                    selected: { [weak self] in
                        self.map { UserDefaults.standard.bool(forKey: $0.copilotMenuBarKey) } ?? false
                    })
            command("通信エラーの対処…", .copilotTroubleshooting)
            command("キーを削除して切断…", .disconnectCopilot,
                    enabledWhen: { [weak self] in self?.copilotClient.configured ?? false })
        case .api:
            menu.addItem(MenuVisualStyle.heading("OFFICIAL API REPORTS"))
            for kind in ExternalAPIKind.allCases {
                let subitem = NSMenuItem(title: kind.name, action: nil, keyEquivalent: "")
                let sub = NSMenu(title: kind.name)
                sub.autoenablesItems = false
                addStayOpenRow("APIキーを登録・更新…", to: sub) { [weak self] in
                    DispatchQueue.main.async { [weak self] in
                        self?.performAccountPanelAction(.configureAPI(kind))
                    }
                }
                addStayOpenRow("今すぐ取得", to: sub,
                    enabledWhen: { [weak self] in self?.externalClients[kind]?.configured ?? false }) { [weak self] in
                    self?.performAccountPanelAction(.refreshAPI(kind))
                }
                addStayOpenRow("キーを削除して切断…", to: sub,
                    enabledWhen: { [weak self] in self?.externalClients[kind]?.configured ?? false }) { [weak self] in
                    DispatchQueue.main.async { [weak self] in
                        self?.performAccountPanelAction(.disconnectAPI(kind))
                    }
                }
                subitem.submenu = sub
                menu.addItem(subitem)
            }
        case .catalog:
            menu.addItem(MenuVisualStyle.heading("AI SERVICES / 追加・管理"))
            addAccountsSubmenu("Codexの接続設定", section: .codex,
                               symbol: "person.crop.circle", to: menu)
            addAccountsSubmenu("Claudeの接続設定", section: .claude,
                               symbol: "person.crop.circle", to: menu)
            addAccountsSubmenu("GitHub Copilotを接続", section: .copilot,
                               symbol: "person.crop.circle", to: menu)
            for kind in ExternalAPIKind.allCases {
                addExternalAPIProviderSubmenu(kind, to: menu)
            }
            menu.addItem(.separator())
            for id in ["chatgpt", "gemini", "perplexity", "cursor", "grok"] {
                addConsumerProviderSubmenu(id, to: menu)
            }
        }
        item.submenu = menu
        parent.addItem(item)
    }

    private func addExternalAPIProviderSubmenu(_ kind: ExternalAPIKind, to parent: NSMenu) {
        let item = NSMenuItem(title: "\(kind.name) のAPI", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "\(kind.name) のAPI")
        menu.autoenablesItems = false
        addStayOpenRow("APIキーを登録・更新…", to: menu) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.performAccountPanelAction(.configureAPI(kind))
            }
        }
        addStayOpenRow("今すぐ取得", to: menu,
                       enabledWhen: { [weak self] in self?.externalClients[kind]?.configured ?? false }) { [weak self] in
            self?.performAccountPanelAction(.refreshAPI(kind))
        }
        addStayOpenRow("キーを削除して切断…", to: menu,
                       enabledWhen: { [weak self] in self?.externalClients[kind]?.configured ?? false }) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.performAccountPanelAction(.disconnectAPI(kind))
            }
        }
        let currentPeriod = ExternalAPIUsage.startOfUTCMonth(Date())
        if let report = externalReports[kind], report.periodStart == currentPeriod {
            let formatted = report.unit == "USD"
                ? String(format: "$%.2f", report.value)
                : String(format: "%.0f requests", report.value)
            menu.addItem(.separator())
            menu.addItem(withTitle: "現在: \(formatted)（\(report.label)・当月）", action: nil, keyEquivalent: "")
        }
        item.submenu = menu
        parent.addItem(item)
    }

    private func addConsumerProviderSubmenu(_ id: String, to parent: NSMenu) {
        guard let descriptor = AIProviderRegistry.catalog.first(where: { $0.id == id }) else { return }
        let item = NSMenuItem(title: "\(descriptor.name)", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: descriptor.name)
        menu.autoenablesItems = false
        if ConsumerWebAccess.destination(for: id) != nil {
            addStayOpenRow("公式サイトを開く…", to: menu,
                           symbolName: "arrow.up.right.square") { [weak self] in
                self?.openConsumerExternally(id)
            }
            addStayOpenRow("画面で確認した内容を手動記録…", to: menu,
                           symbolName: "square.and.pencil") { [weak self] in
                DispatchQueue.main.async { [weak self] in self?.editConsumerNote(id) }
            }
            addStayOpenRow("手動記録を削除", to: menu,
                           enabledWhen: { [weak self] in self?.consumerNotes[id] != nil }) { [weak self] in
                self?.consumerNotes.removeValue(forKey: id)
                self?.saveConsumerNotes()
            }
            menu.addItem(.separator())
            if let note = consumerNotes[id] {
                menu.addItem(withTitle: "記録: \(note.text)", action: nil, keyEquivalent: "")
                menu.addItem(withTitle: "確認時刻: \(dateText(note.recordedAt))", action: nil, keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "現在: 手動記録なし", action: nil, keyEquivalent: "")
            }
        }
        item.submenu = menu
        parent.addItem(item)
    }

    // MARK: - Consumer web browsing (explicit manual-first integration)

    private func loadConsumerNotes() {
        guard let data = UserDefaults.standard.data(forKey: consumerNotesKey), data.count < 20_000,
              let decoded = try? JSONDecoder().decode([String: ConsumerUsageNote].self, from: data) else { return }
        consumerNotes = decoded.filter { key, note in
            key == note.providerID && ConsumerWebAccess.destination(for: key) != nil &&
            ConsumerUsageNote(providerID: key, text: note.text, recordedAt: note.recordedAt) != nil
        }
    }

    private func saveConsumerNotes() {
        if let encoded = try? JSONEncoder().encode(consumerNotes) {
            UserDefaults.standard.set(encoded, forKey: consumerNotesKey)
        }
        renderUI()
    }

    private func webStoreID(for providerID: String) -> UUID {
        let key = "AIChecker.consumer.v1.webStore.\(providerID)"
        if let raw = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: raw) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    private func openConsumerWeb(_ providerID: String) {
        guard let destination = ConsumerWebAccess.destination(for: providerID), destination.url != nil else { return }
        if let running = consumerWebSessions[providerID] { running.show(); return }
        let consentKey = "AIChecker.consumer.v1.webConsent.\(providerID)"
        if !UserDefaults.standard.bool(forKey: consentKey) {
            let alert = NSAlert()
            alert.messageText = "\(destination.name)公式サイトをAI Checker内で開きますか？"
            alert.informativeText = AppL10n.text("ログイン情報はAI Checker専用のWebKitストレージに保存されます（macOS 14以降）。通常のSafari・Chrome等のログインとは分離されます。AI CheckerはパスワードやCookieを読み取りません。使用量を自動取得する機能ではありません。Google等の認証がWebKitを拒否する場合は既定ブラウザーを利用してください。")
            alert.addButton(withTitle: AppL10n.text("開く"))
            alert.addButton(withTitle: AppL10n.text("キャンセル"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            UserDefaults.standard.set(true, forKey: consentKey)
        }
        let session = ConsumerWebSession(destination: destination, storeID: webStoreID(for: providerID))
        consumerWebSessions[providerID] = session
        session.show()
    }

    private func openConsumerExternally(_ providerID: String) {
        guard let url = ConsumerWebAccess.destination(for: providerID)?.url else { return }
        NSWorkspace.shared.open(url)
    }

    private func editConsumerNote(_ providerID: String) {
        guard let destination = ConsumerWebAccess.destination(for: providerID) else { return }
        let alert = NSAlert()
        alert.messageText = "\(destination.name) — 手動記録"
        alert.informativeText = AppL10n.text("公式サイトに実際に表示された残量やリセット時刻だけを記録してください（120文字まで）。これはメモであり、自動更新・認証済みの数値ではありません。APIキー、パスワード、Cookie、個人情報は絶対に入力しないでください。")
        alert.addButton(withTitle: AppL10n.text("手動記録を保存"))
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 430, height: 28))
        field.placeholderString = AppL10n.text("例: Proモデル 残り28%、リセット 18:00")
        field.stringValue = consumerNotes[providerID]?.text ?? ""
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let note = ConsumerUsageNote(providerID: providerID, text: field.stringValue,
                                           recordedAt: Date()) else {
            let invalid = NSAlert()
            invalid.messageText = AppL10n.text("手動記録を保存できませんでした")
            invalid.informativeText = AppL10n.text("空欄・改行・120文字超過・資格情報を含む値は保存できません。")
            invalid.runModal()
            return
        }
        consumerNotes[providerID] = note
        saveConsumerNotes()
    }

    private func eraseConsumerWeb(_ providerID: String) {
        guard ConsumerWebAccess.destination(for: providerID) != nil else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "専用ブラウザーの\(providerID)ログインデータを削除しますか？"
        alert.informativeText = "AI Checker内の専用WebKitセッションだけを削除します。Safari・Chrome・公式アプリのログインには影響しません。手動記録は保持します。"
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        alert.addButton(withTitle: AppL10n.text("削除"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        consumerWebSessions.removeValue(forKey: providerID)?.stop()
        let key = "AIChecker.consumer.v1.webStore.\(providerID)"
        guard let raw = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: raw) else { return }
        ConsumerWebSession.erase(storeID: uuid) { error in
            DispatchQueue.main.async {
                if error == nil { UserDefaults.standard.removeObject(forKey: key) }
                let result = NSAlert()
                result.messageText = error == nil ? AppL10n.text("専用ログインデータを削除しました") : AppL10n.text("削除できませんでした")
                if let error { result.informativeText = error.localizedDescription }
                result.runModal()
            }
        }
    }

    private var accountPanelState: AccountPanelState {
        let codex = accountConfig.accounts.filter { $0.providerID == "codex" }.map {
            AccountPanelRecord(id: $0.id, label: $0.label, selected: $0.id == accountConfig.activeCodexID)
        }
        let claude = accountConfig.accounts.filter { $0.providerID == "claude" }.map {
            AccountPanelRecord(id: $0.id, label: $0.label, selected: $0.id == accountConfig.activeClaudeID)
        }
        return AccountPanelState(codex: codex, claude: claude,
            codexStatus: codexState, claudeStatus: claudeWebState,
            claudeWebEnabled: accountConfig.activeClaudeID.map { claudeWebEnabled($0) } ?? false,
            copilotConfigured: copilotClient.configured,
            copilotStatus: copilotState, copilotMode: copilotAccessMode,
            copilotBarEnabled: UserDefaults.standard.bool(forKey: copilotMenuBarKey),
            externalConfigured: Dictionary(uniqueKeysWithValues: ExternalAPIKind.allCases.map {
                ($0, externalClients[$0]?.configured == true)
            }), externalStatuses: externalStates)
    }

    private func accountItem(_ value: String) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.representedObject = value
        return item
    }

    private func performAccountPanelAction(_ action: AccountPanelAction) {
        switch action {
        case .selectCodex(let id): selectCodexAccount(accountItem(id.uuidString))
        case .selectClaude(let id): selectClaudeAccount(accountItem(id.uuidString))
        case .addCodex: addCodexAccount()
        case .loginCodex: loginCodex()
        case .logoutCodex: logoutCodex()
        case .renameCodex: renameCodex()
        case .removeCodex: removeCodex()
        case .reconnectCodex: reconnectCodex()
        case .chooseCodexCLI: chooseCodexExecutable()
        case .addClaude: addClaudeAccount()
        case .loginClaudeWeb: openClaudeWeb()
        case .refreshClaudeWeb: refreshClaudeWeb()
        case .disconnectClaudeWeb: disconnectClaudeWeb()
        case .loginClaudeCode: openClaudeCode()
        case .renameClaude: renameClaude()
        case .removeClaude: removeClaude()
        case .configureCopilot: configureCopilotAccount()
        case .disconnectCopilot: disconnectCopilot()
        case .refreshCopilot: refreshCopilot()
        case .copilotInfo: showCopilotScopeInfo()
        case .copilotTroubleshooting: showCopilotTroubleshooting()
        case .toggleCopilotBar: toggleCopilotBar()
        case .configureAPI(let kind): configureExternalAPI(accountItem(kind.rawValue))
        case .refreshAPI(let kind): refreshExternalAPI(accountItem(kind.rawValue))
        case .disconnectAPI(let kind): disconnectExternalAPI(accountItem(kind.rawValue))
        case .providerInfo(let id): showProviderInfo(accountItem(id))
        case .displaySettings: break // use the native branching APPEARANCE submenu
        }
    }

    // MARK: - Dedicated accounts (never read or modify the default ~/.codex account)

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountPreferencesKey),
           let decoded = AccountConfiguration.decodeSafely(data) { accountConfig = decoded }
    }

    private func saveAccounts() {
        if let bytes = try? JSONEncoder().encode(accountConfig) {
            UserDefaults.standard.set(bytes, forKey: accountPreferencesKey)
        }
    }

    private func connectSelectedAccount() {
        codexClient?.stopAndWait()
        codexClient = nil
        snapshots.removeValue(forKey: "codex") // never display old account's percentage for another account
        if connectedCodexProfileID != accountConfig.activeCodexID {
            providerHealth.reset("codex")
            connectedCodexProfileID = accountConfig.activeCodexID
        }
        if let profile = accountConfig.activeCodex, !sleeping, !demo {
            codexState = "接続準備中（\(profile.label)）"
            let client = CodexAccountClient(profile: profile)
            client.onState = { [weak self, weak client] message in
                guard let self = self, let client = client, self.codexClient === client,
                      self.accountConfig.activeCodexID == profile.id else { return }
                self.codexState = message
                self.renderUI()
            }
            client.onSnapshot = { [weak self, weak client] sample in
                guard let self = self, let client = client, self.codexClient === client,
                      !self.sleeping, self.accountConfig.activeCodexID == profile.id else { return }
                if let sample = sample {
                    self.observeQuota(sample, accountID: profile.id)
                    self.snapshots["codex"] = sample
                    self.providerHealth.succeed("codex", now: Date())
                    self.lastSuccess = Date()
                } else {
                    self.snapshots.removeValue(forKey: "codex")
                    self.providerHealth.setAuth("codex", .disconnected)
                }
                self.renderUI()
            }
            client.onFailure = { [weak self, weak client] failure in
                guard let self = self, let client = client, self.codexClient === client,
                      !self.sleeping, self.accountConfig.activeCodexID == profile.id else { return }
                self.providerHealth.fail("codex", failure: failure, now: Date())
                self.renderUI()
            }
            client.onOpenBrowser = { url in NSWorkspace.shared.open(url) }
            codexClient = client
            client.start()
        } else {
            codexState = "未設定（アカウントを追加してください）"
        }
        lastDisplayKey = nil
        renderUI()
    }

    // MARK: - Optional Claude WebKit website-session experiment

    private func claudeWebConsentKey(_ id: UUID) -> String {
        "AIChecker.v141.claudeWebConsent." + id.uuidString.lowercased()
    }

    private func claudeWebEnabled(_ id: UUID) -> Bool {
        // Public source releases intentionally refuse non-public website polling.
        return false
    }

    private func configureClaudeWebSession() {
        claudeWebClient?.stop()
        claudeWebClient = nil
        claudeWebState = "Claude Code statusLine（公開版）"
    }

    @objc private func openClaudeWeb() {
        let alert = NSAlert()
        alert.messageText = AppL10n.text("Claude Web連携は公開版では利用できません")
        alert.informativeText = AppL10n.text("Claude CodeのstatusLine連携を使用してください。")
        alert.runModal()
    }

    @objc private func refreshClaudeWeb() { /* Intentionally unavailable. */ }
    @objc private func disconnectClaudeWeb() { /* Intentionally unavailable. */ }

    // MARK: - First-party Claude Code profiles / statusLine (no third-party OAuth)

    // Any Claude-profile change invalidates the old profile's observation and
    // rebinds Claude Code statusLine to the new active profile. This method
    // was accidentally omitted when the persistent accounts panel was added.
    private func changedClaudeProfile() {
        providerHealth.reset("claude")
        configureClaudeWebSession()
        snapshots.removeValue(forKey: "claude")
        lastDisplayKey = nil
        refresh(force: true)
        renderUI()
    }

    @objc private func addClaudeAccount() {
        guard let label = accountPrompt("Claudeプロフィールを追加", preset: "個人Claude") else { return }
        guard let profile = accountConfig.addClaude(label: label) else { return }
        _ = accountConfig.selectClaude(profile.id)
        saveAccounts()
        changedClaudeProfile()
        let alert = NSAlert()
        alert.messageText = AppL10n.text("Claudeプロフィールを追加しました")
        alert.informativeText = AppL10n.text("公開版ではClaude Code公式のstatusLine連携を利用してください。非公開のClaude Web利用量APIにはアクセスしません。")
        alert.runModal()
    }

    @objc private func selectClaudeAccount(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw), accountConfig.selectClaude(id) else { return }
        saveAccounts()
        changedClaudeProfile()
    }

    @objc private func openClaudeCode() {
        guard let profile = accountConfig.activeClaude else { return }
        let binary = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        do {
            let connect = try ClaudeProfileClient.prepare(profile, executable: binary)
            let alert = NSAlert()
            alert.messageText = AppL10n.text("Claude Code公式ログイン環境を開きます")
            alert.informativeText = AppL10n.text("TerminalでClaude Codeを起動します。必要なら公式ログインを行い、/statusでアカウントを確認してください。AI Checkerは専用CLAUDE_CONFIG_DIRだけを設定しますが、Claude側のKeychain等の共有認証状態まで分離できる保証はありません。既存の ~/.claude は変更しません。")
            alert.addButton(withTitle: AppL10n.text("Terminalで開く"))
            alert.addButton(withTitle: AppL10n.text("キャンセル"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            if !NSWorkspace.shared.open(connect) {
                showClaudeError(AppL10n.text("Terminalで.commandを開けませんでした。Finderから専用connect.commandを開いてください。"))
            }
        } catch {
            showClaudeError(error.localizedDescription)
        }
    }

    private func showClaudeError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppL10n.text("Claude Codeの準備に失敗しました")
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func renameClaude() {
        guard let profile = accountConfig.activeClaude,
              let label = accountPrompt("Claudeプロフィール名", preset: profile.label),
              accountConfig.rename(profile.id, to: label) else { return }
        saveAccounts()
        renderUI()
    }

    @objc private func removeClaude() {
        guard let profile = accountConfig.activeClaude else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\(profile.label)の専用設定を削除しますか？"
        alert.informativeText = AppL10n.text("専用CLAUDE_CONFIG_DIRとキャッシュが削除されます。Claude Code公式の認証失効は保証しません。先にClaude Codeの/login・/logoutなどでアカウント状態を確認してください。共有 ~/.claude は削除しません。")
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        alert.addButton(withTitle: "専用設定を削除")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        let dir = ClaudeProfileClient.root(profile.id)
        do {
            if FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.removeItem(at: dir)
            }
        } catch {
            showClaudeError("専用ディレクトリを削除できなかったため、プロフィールは残しました。")
            return
        }
        if claudeWebClient?.profileID == profile.id {
            claudeWebClient?.stop()
            claudeWebClient = nil
        }
        UserDefaults.standard.removeObject(forKey: claudeWebConsentKey(profile.id))
        ClaudeWebSession.eraseProfile(profile.id) { error in
            if let error = error { NSLog("AI Checker: Claude WebKit profile data removal failed: \(error.localizedDescription)") }
        }
        _ = accountConfig.remove(profile.id)
        saveAccounts()
        changedClaudeProfile()
    }

    private func accountPrompt(_ title: String, preset: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = AppL10n.text("アカウント識別用の表示名です。パスワードは入力しないでください。")
        alert.addButton(withTitle: AppL10n.text("保存"))
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.stringValue = preset
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : String(value.prefix(48))
    }

    @objc private func addCodexAccount() {
        guard let label = accountPrompt("Codexアカウントを追加", preset: "個人Codex") else { return }
        guard let profile = accountConfig.addCodex(label: label) else { return }
        _ = accountConfig.selectCodex(profile.id)
        saveAccounts()
        connectSelectedAccount()
        let alert = NSAlert()
        alert.messageText = AppL10n.text("専用Codexプロフィールを追加しました")
        alert.informativeText = AppL10n.text("このプロフィールは研究室の ~/.codex と独立しています。ブラウザログインはメニューから明示的に実行してください。")
        alert.runModal()
    }

    @objc private func selectCodexAccount(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw),
              accountConfig.selectCodex(id) else { return }
        saveAccounts()
        connectSelectedAccount()
    }

    // Deliberate, single-entry-point onboarding. No CLI installer is launched.
    // Existing accounts and the user's default ~/.codex remain untouched.
    private func beginEasyCodexConnection() {
        guard !demo, !sleeping else { return }
        // Verify the official CLI executable is present BEFORE creating a new
        // empty profile or mutating the user's account selection.
        guard CodexAccountClient.executable() != nil else {
            showCodexInstallationGuide()
            return
        }
        if accountConfig.activeCodex == nil {
            if let existing = accountConfig.accounts.first(where: { $0.providerID == "codex" }) {
                guard accountConfig.selectCodex(existing.id) else { return }
            } else {
                guard let profile = accountConfig.addCodex(label: "個人Codex"),
                      accountConfig.selectCodex(profile.id) else {
                    let alert = NSAlert()
                    alert.messageText = AppL10n.text("Codexプロフィールを作成できませんでした")
                    alert.informativeText = AppL10n.text("アカウント管理画面から登録状況を確認してください。")
                    alert.runModal()
                    return
                }
            }
            saveAccounts()
            connectSelectedAccount()
        } else if codexClient == nil {
            connectSelectedAccount()
        }
        // The official app-server generates the browser authentication URL.
        // AI Checker never handles the ChatGPT password or OAuth tokens.
        codexClient?.login()
    }

    private func showCodexInstallationGuide() {
        let alert = NSAlert()
        alert.messageText = AppL10n.text("OpenAI公式Codex CLIが見つかりません")
        alert.informativeText = AppL10n.text("ChatGPTで接続するには、OpenAI公式Codex CLIが必要です。公式の導入手順を確認し、インストール後に「ChatGPTでかんたん接続」を再度選んでください。既に別の場所へインストール済みの場合は実行ファイルを指定できます。AI Checkerはインストールコマンドを無断実行しません。")
        alert.addButton(withTitle: AppL10n.text("公式の導入手順を見る"))
        alert.addButton(withTitle: AppL10n.text("CLIの場所を選択…"))
        alert.addButton(withTitle: AppL10n.text("閉じる"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "https://github.com/openai/codex") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            chooseCodexExecutable()
            // If selection was cancelled, simply return; no second dialog.
            if CodexAccountClient.executable() != nil { beginEasyCodexConnection() }
        default:
            break
        }
    }

    @objc private func loginCodex() { codexClient?.login() }
    @objc private func reconnectCodex() { connectSelectedAccount() }
    @objc private func logoutCodex() { codexClient?.logout() }
    @objc private func renameCodex() {
        guard let profile = accountConfig.activeCodex,
              let label = accountPrompt("アカウント名を変更", preset: profile.label) else { return }
        guard accountConfig.rename(profile.id, to: label) else { return }
        saveAccounts(); connectSelectedAccount()
    }
    @objc private func removeCodex() {
        guard let profile = accountConfig.activeCodex else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\(profile.label)を削除しますか？"
        alert.informativeText = "AI Checker専用のCODEX_HOMEフォルダーを削除します。先に『ログアウト』を行ってください。Codexが別の保管先に保存した資格情報は残る場合があります。通常の ~/.codex は変更しません。"
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        alert.addButton(withTitle: "プロフィールと認証情報を削除")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        codexClient?.stopAndWait()
        codexClient = nil
        // Remove ONLY the UUID-named directory under AI Checker's own account root.
        let url = CodexAccountClient.accountHome(profile.id)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            let failure = NSAlert()
            failure.messageText = AppL10n.text("認証情報を削除できませんでした")
            failure.informativeText = AppL10n.text("安全のためプロフィールはそのまま残します。")
            failure.runModal()
            connectSelectedAccount()
            return
        }
        _ = accountConfig.remove(profile.id)
        saveAccounts()
        connectSelectedAccount()
    }
    @objc private func chooseCodexExecutable() {
        let panel = NSOpenPanel()
        panel.message = "公式Codex CLIの実行ファイルを選んでください（codex app-server）。"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              FileManager.default.isExecutableFile(atPath: url.path) else { return }
        UserDefaults.standard.set(url.path, forKey: "AIChecker.v13.codexExecutable")
        connectSelectedAccount()
    }

    // MARK: - GitHub Copilot (official personal billing report, NOT 5h/weekly quota)

    private func configureCopilotCallbacks() {
        copilotClient.onState = { [weak self] message in
            self?.copilotState = message
            self?.renderUI()
        }
        copilotClient.onReport = { [weak self] report in
            guard let self = self, !self.sleeping, self.copilotClient.username == report.username else { return }
            self.copilotReport = report
            self.lastDisplayKey = nil // optional GH request counter artwork changed
            self.providerHealth.succeed("copilot", now: Date())
            self.lastSuccess = Date()
            self.renderUI()
        }
        copilotClient.onFailure = { [weak self] failure in
            guard let self = self, !self.sleeping else { return }
            self.providerHealth.fail("copilot", failure: failure, now: Date())
            self.renderUI()
        }
        copilotState = copilotAccessMode.permitsPersonalBillingAPI
            ? (copilotClient.configured ? "接続情報あり（公式APIの確認待ち）" : "未接続")
            : copilotAccessMode.informationalStatus
    }

    @objc private func changeCopilotAccessMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let selected = CopilotAccessMode(rawValue: raw),
              selected != copilotAccessMode else { return }
        if selected == .personallyBilled {
            let confirm = NSAlert()
            confirm.messageText = AppL10n.text("個人で購入したCopilotプランですか？")
            confirm.informativeText = AppL10n.text("GitHub公式の個人向け請求APIは、自分で購入したプランが対象です。Free／未契約／組織管理の使用枠はここから取得できません。\n\n続行すると、保存済みトークンがあれば個人請求APIを読み取る設定に変わります。")
            confirm.addButton(withTitle: AppL10n.text("個人課金APIを許可"))
            confirm.addButton(withTitle: AppL10n.text("キャンセル"))
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
        }
        // Fail closed before mutating visible state or persisting the new mode.
        copilotClient.stop()
        copilotClient.allowBillingRequests = false
        copilotReport = nil
        providerHealth.reset("copilot")
        UserDefaults.standard.set(false, forKey: copilotMenuBarKey)
        copilotAccessMode = selected
        UserDefaults.standard.set(selected.rawValue, forKey: copilotAccessKey)
        copilotClient.allowBillingRequests = selected.permitsPersonalBillingAPI
        if selected.permitsPersonalBillingAPI { copilotClient.resume() }
        copilotState = selected.permitsPersonalBillingAPI
            ? "個人請求APIを許可済み（未取得）" : selected.informationalStatus
        lastDisplayKey = nil
        renderUI()
    }

    @objc private func showCopilotScopeInfo() {
        let alert = NSAlert()
        alert.messageText = AppL10n.text("Copilotの利用区分について")
        alert.informativeText = "GitHubへのログインだけでは、Copilotの契約や残量は分かりません。\n\n現在の公式個人請求APIは自分で購入したCopilotプランの課金使用量用であり、Copilot Freeの残り枠を確認するAPIではありません。\n\nFree・未契約・組織管理を選んだ場合は請求APIの通信を停止します。過去のトークンはここから明示的に削除できます。\n\n選択した利用区分は自己申告であり、AI Checkerが契約を検証した結果ではありません。"
        alert.addButton(withTitle: AppL10n.text("閉じる"))
        alert.runModal()
    }

    @objc private func showCopilotTroubleshooting() {
        let alert = NSAlert()
        alert.messageText = AppL10n.text("GitHub Copilot使用量 — エラーの確認")
        alert.informativeText = "HTTP 401: トークン無効・失効。GitHub側で再発行を確認。\n\nHTTP 403: トークンの Account permissions → Plan: Read が必要。個人ではなく学校・組織がCopilotを支払う場合は、個人の請求APIに使用量が出ません。API制限による403もあります。\n\nHTTP 404: GitHubユーザー名や個人請求データの有無を確認。\n\nHTTP 429: 一時的なアクセス制限。自動再試行を待ってください。\n\n利用量はPremium Requestsの当月使用数で、Codexの5h/週の残量ではありません。トークン自体はこの画面に表示しません。"
        alert.addButton(withTitle: AppL10n.text("閉じる"))
        alert.runModal()
    }

    @objc private func configureCopilotAccount() {
        guard copilotAccessMode.permitsPersonalBillingAPI else { showCopilotScopeInfo(); return }
        let alert = NSAlert()
        alert.messageText = AppL10n.text("GitHub Copilot使用量を接続")
        alert.informativeText = "GitHubのFine-grained PAT（Plan: Read）と個人ユーザー名を入力。資格情報はmacOS Keychainのみに保存し、公式GitHub請求APIの当月使用数を取得します。組織負担プランや5時間/週の残量は対象外です。"
        alert.addButton(withTitle: "保存して取得")
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        let username = NSTextField(frame: NSRect(x: 0, y: 50, width: 390, height: 24))
        username.placeholderString = AppL10n.text("GitHubユーザー名（例: octocat）")
        username.stringValue = copilotClient.username ?? ""
        let token = NSSecureTextField(frame: NSRect(x: 0, y: 38, width: 390, height: 24))
        token.placeholderString = "Fine-grained personal access token（Plan: Read）"
        let pasteButton = NSButton(title: "クリップボードから貼り付け",
                                   target: self, action: #selector(pasteCopilotToken(_:)))
        pasteButton.frame = NSRect(x: 181, y: 2, width: 209, height: 28)
        pasteButton.toolTip = AppL10n.text("押したときだけクリップボードを読み取ります。入力は黒丸で隠れます。")
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 102))
        username.frame.origin.y = 74
        panel.addSubview(username)
        panel.addSubview(token)
        panel.addSubview(pasteButton)
        alert.accessoryView = panel
        copilotTokenInput = token
        let response = alert.runModal()
        copilotTokenInput = nil
        guard response == .alertFirstButtonReturn else { return }
        if copilotClient.configure(username: username.stringValue, token: token.stringValue) {
            copilotReport = nil
            providerHealth.reset("copilot")
            copilotClient.requestUsage(force: true)
        } else {
            let invalid = NSAlert()
            invalid.messageText = AppL10n.text("接続設定を保存できませんでした")
            invalid.informativeText = AppL10n.text("ユーザー名・トークンまたはKeychainの書き込み権限を確認してください。")
            invalid.runModal()
        }
        renderUI()
    }

    @objc private func pasteCopilotToken(_ sender: NSButton) {
        // Clipboard access occurs ONLY on the user's explicit button click.
        // Never print, transmit, or persist plaintext here. The existing
        // CopilotBillingClient stores the value in the macOS Keychain on submit.
        guard let token = copilotTokenInput,
              let value = NSPasteboard.general.string(forType: .string),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }
        token.stringValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func toggleCopilotBar() {
        guard copilotAccessMode.permitsPersonalBillingAPI else { return }
        let next = !UserDefaults.standard.bool(forKey: copilotMenuBarKey)
        UserDefaults.standard.set(next, forKey: copilotMenuBarKey)
        lastDisplayKey = nil
        renderUI()
    }

    @objc private func refreshCopilot() {
        guard copilotAccessMode.permitsPersonalBillingAPI else { return }
        guard providerHealth.begin("copilot", now: Date(), forced: true) else { return }
        copilotClient.requestUsage(force: true)
    }

    @objc private func disconnectCopilot() {
        let alert = NSAlert()
        alert.messageText = AppL10n.text("GitHub Copilot連携を解除しますか？")
        alert.informativeText = "AI CheckerのKeychain内の個人トークンだけを削除します。GitHub側で発行済みのトークン自体を失効させるものではありません。"
        alert.addButton(withTitle: AppL10n.text("削除して切断"))
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        copilotClient.disconnect()
        copilotReport = nil
        lastDisplayKey = nil
        providerHealth.reset("copilot")
        renderUI()
    }

    // MARK: - External official API reports (separate from chat subscriptions)

    private func configureExternalAPICallbacks() {
        for kind in ExternalAPIKind.allCases {
            guard let client = externalClients[kind] else { continue }
            client.onState = { [weak self] state in
                self?.externalStates[kind] = state
                self?.renderUI()
            }
            client.onReport = { [weak self] report in
                guard let self = self, !self.sleeping,
                      self.externalClients[kind]?.configured == true else { return }
                self.externalReports[kind] = report
                self.lastDisplayKey = nil // official API report may be visible in the status bar
                self.providerHealth.succeed(kind.rawValue, now: Date())
                self.lastSuccess = Date()
                self.renderUI()
            }
            client.onFailure = { [weak self] failure in
                guard let self = self, !self.sleeping else { return }
                self.providerHealth.fail(kind.rawValue, failure: failure, now: Date())
                self.renderUI()
            }
            externalStates[kind] = client.configured ? "設定済み・API確認待ち" : "未接続"
        }
    }

    @objc private func configureExternalAPI(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let kind = ExternalAPIKind(rawValue: id), let client = externalClients[kind] else { return }
        let alert = NSAlert()
        alert.messageText = "\(kind.name) — 公式APIレポート接続"
        alert.informativeText = "\(kind.scope)のみ取得します。5時間/週のチャット残量とは別です。APIキーはmacOS Keychainに保存。必要な権限と契約は公式サービス側で設定してください。管理用キーは高権限のため、必ず信頼できる個人のMacでのみ利用してください。"
        alert.addButton(withTitle: "Keychainに保存して取得")
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 410, height: kind.requiresTeamID ? 90 : 55))
        let token = NSSecureTextField(frame: NSRect(x: 0, y: kind.requiresTeamID ? 46 : 15, width: 410, height: 25))
        token.placeholderString = kind == .openaiAPI ? "OpenAI organization admin key" :
            (kind == .cursorTeam ? "Cursor team Admin API key" : "xAI Management API key")
        panel.addSubview(token)
        var team: NSTextField? = nil
        if kind.requiresTeamID {
            let field = NSTextField(frame: NSRect(x: 0, y: 8, width: 410, height: 25))
            field.placeholderString = "xAI Team ID (UUID)"
            field.stringValue = client.teamID ?? ""
            panel.addSubview(field)
            team = field
        }
        alert.accessoryView = panel
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if client.configure(secret: token.stringValue, teamID: team?.stringValue) {
            externalReports.removeValue(forKey: kind)
            lastDisplayKey = nil
            providerHealth.reset(kind.rawValue)
            if providerHealth.begin(kind.rawValue, now: Date(), forced: true) {
                client.requestUsage(force: true)
            }
        } else {
            let failure = NSAlert()
            failure.messageText = AppL10n.text("接続設定を保存できませんでした")
            failure.informativeText = "APIキー、Team ID (UUID)、Keychain書き込み権限を確認してください。"
            failure.runModal()
        }
        renderUI()
    }

    @objc private func refreshExternalAPI(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let kind = ExternalAPIKind(rawValue: id), let client = externalClients[kind],
              client.configured else { return }
        if providerHealth.begin(kind.rawValue, now: Date(), forced: true) {
            client.requestUsage(force: true)
        }
    }

    @objc private func disconnectExternalAPI(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let kind = ExternalAPIKind(rawValue: id), let client = externalClients[kind] else { return }
        let alert = NSAlert()
        alert.messageText = "\(kind.name)とのAPI連携を解除しますか？"
        alert.informativeText = "このMacのKeychainに保存された専用キーを削除します。発行元サービス上のAPIキーは失効しません。"
        alert.addButton(withTitle: AppL10n.text("削除して切断"))
        alert.addButton(withTitle: AppL10n.text("キャンセル"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        client.disconnect()
        externalReports.removeValue(forKey: kind)
        lastDisplayKey = nil
        providerHealth.reset(kind.rawValue)
        renderUI()
    }

    @objc private func showProviderInfo(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let provider = AIProviderRegistry.catalog.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = provider.name + " — 接続状況"
        if id == "copilot" {
            showCopilotScopeInfo()
            return
        } else if id == "codex" || id == "claude" {
            alert.informativeText = "このサービスは対応済みです。メニューのアカウント管理から接続してください。"
        } else if AIProviderRegistry.supportsExternalAPIReport(id) {
            alert.informativeText = "公式API利用量の接続は『AIサービスを追加…』から設定できます。チャット製品・個人契約の残量ではありません。"
        } else if id == "chatgpt" {
            alert.informativeText = "ChatGPTのチャット用利用制限はCodexの使用枠とは別です。現時点ではChatGPT個人向けの残量を取得する正式なAPIを確認できないため、ログイン画面や架空の残量を作成していません。"
        } else {
            alert.informativeText = "このサービスの公式な認証・使用率取得方法は未接続です。正確なデータ取得を確認した後に有効化します。"
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Opt-in quota notifications (no extra timers or web requests)

    private func loadQuotaNotifications() {
        if let data = UserDefaults.standard.data(forKey: quotaNotificationSettingsKey),
           let saved = try? JSONDecoder().decode(QuotaNotificationPreferences.self, from: data) {
            quotaNotificationSettings = saved
        }
        if let data = UserDefaults.standard.data(forKey: quotaNotificationHistoryKey),
           data.count < 100_000,
           let saved = try? JSONDecoder().decode(QuotaNotificationMonitor.self, from: data) {
            quotaNotificationMonitor = saved
        }
    }

    private func saveQuotaNotificationSettings() {
        if let data = try? JSONEncoder().encode(quotaNotificationSettings) {
            UserDefaults.standard.set(data, forKey: quotaNotificationSettingsKey)
        }
        renderUI()
    }

    private func observeQuota(_ sample: AIQuotaSnapshot, accountID: UUID) {
        guard !sleeping, !demo else { return }
        let events = quotaNotificationMonitor.ingest(accountID: accountID, snapshot: sample,
                                                     settings: quotaNotificationSettings)
        if let data = try? JSONEncoder().encode(quotaNotificationMonitor) {
            UserDefaults.standard.set(data, forKey: quotaNotificationHistoryKey)
        }
        events.forEach { quotaNotifier.deliver($0) }
    }

    private func setQuotaNotification(_ isReset: Bool) {
        let wasEnabled = isReset ? quotaNotificationSettings.notifyOnReset
                                 : quotaNotificationSettings.notifyOnExhaustion
        if wasEnabled {
            if isReset { quotaNotificationSettings.notifyOnReset = false }
            else { quotaNotificationSettings.notifyOnExhaustion = false }
            saveQuotaNotificationSettings()
            return
        }
        quotaNotifier.requestPermission { [weak self] permitted in
            guard let self else { return }
            if permitted {
                if isReset { self.quotaNotificationSettings.notifyOnReset = true }
                else { self.quotaNotificationSettings.notifyOnExhaustion = true }
                self.saveQuotaNotificationSettings()
            } else {
                let alert = NSAlert()
                alert.messageText = AppL10n.text("通知が許可されていません")
                alert.informativeText = AppL10n.text("macOSの『システム設定 → 通知 → AI Checker』で通知を許可してから、もう一度有効にしてください。")
                alert.runModal()
            }
        }
    }

    private func addQuotaNotificationMenu(to parent: NSMenu) {
        let item = NSMenuItem(title: "通知設定", action: nil, keyEquivalent: "")
        MenuVisualStyle.adorn(item, symbol: "bell")
        let menu = NSMenu(title: "通知設定")
        menu.autoenablesItems = false
        addStayOpenRow("5時間・週間のリセット時に通知", to: menu,
            checked: { [weak self] in self?.quotaNotificationSettings.notifyOnReset ?? false }) { [weak self] in
            self?.setQuotaNotification(true)
        }
        addStayOpenRow("5時間・週間の残量を使い切ったら通知", to: menu,
            checked: { [weak self] in self?.quotaNotificationSettings.notifyOnExhaustion ?? false }) { [weak self] in
            self?.setQuotaNotification(false)
        }
        menu.addItem(.separator())
        addStayOpenRow("テスト通知を送る…", to: menu) { [weak self] in
            guard let self else { return }
            self.quotaNotifier.requestPermission { [weak self] permitted in
                guard let self else { return }
                if permitted {
                    self.quotaNotifier.sendTestNotification { [weak self] error in
                        guard self != nil, let error else { return }
                        let alert = NSAlert()
                        alert.messageText = AppL10n.text("テスト通知の送信に失敗しました")
                        alert.informativeText = error.localizedDescription
                        alert.runModal()
                    }
                } else {
                    let alert = NSAlert()
                    alert.messageText = AppL10n.text("通知が許可されていません")
                    alert.informativeText = AppL10n.text("システム設定 → 通知 → AI Checker を確認してください。")
                    alert.runModal()
                }
            }
        }
        menu.addItem(.separator())
        addStayOpenRow("通知状態を確認…", to: menu, symbolName: "checkmark.shield") { [weak self] in
            guard let self else { return }
            self.quotaNotifier.describeSystemSettings { [weak self] systemStatus in
                guard let self else { return }
                let reset = self.quotaNotificationSettings.notifyOnReset ? "ON" : "OFF"
                let exhaustion = self.quotaNotificationSettings.notifyOnExhaustion ? "ON" : "OFF"
                let alert = NSAlert()
                alert.messageText = AppL10n.text("AI Checkerの通知診断")
                alert.informativeText = "リセット通知: \(reset)\n使い切り通知: \(exhaustion)\n\n\(systemStatus)\n\n実際の通知は新しい残量データによる状態変化時のみ発火します。最初から0%の場合や更新失敗時は通知しません。"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        item.submenu = menu
        parent.addItem(item)
    }

    // MARK: - Independent menu-bar provider choices

    private func loadAPIMenuBarSelection() {
        let valid = Set(ExternalAPIKind.allCases.map(\.rawValue))
        let stored = UserDefaults.standard.stringArray(forKey: apiMenuBarSelectionKey) ?? []
        selectedAPIMenuBarIDs = Set(stored.filter { valid.contains($0) })
    }

    private func toggleAPIMenuBar(_ kind: ExternalAPIKind) {
        guard externalClients[kind]?.configured == true else { return }
        if selectedAPIMenuBarIDs.contains(kind.rawValue) {
            selectedAPIMenuBarIDs.remove(kind.rawValue)
        } else {
            selectedAPIMenuBarIDs.insert(kind.rawValue)
        }
        UserDefaults.standard.set(selectedAPIMenuBarIDs.sorted(), forKey: apiMenuBarSelectionKey)
        lastDisplayKey = nil
        renderUI()
    }

    private var currentAPIMenuBarLabels: [String] {
        let now = Date()
        let thisMonth = ExternalAPIUsage.startOfUTCMonth(now)
        return ExternalAPIKind.allCases.compactMap { kind in
            guard selectedAPIMenuBarIDs.contains(kind.rawValue),
                  externalClients[kind]?.configured == true else { return nil }
            let prefix: String
            switch kind {
            case .openaiAPI: prefix = "OA"
            case .cursorTeam: prefix = "CT"
            case .xaiAPI: prefix = "xAI"
            }
            guard let report = externalReports[kind], report.periodStart == thisMonth,
                  report.observedAt <= now.addingTimeInterval(60),
                  now.timeIntervalSince(report.observedAt) <= 3600,
                  report.value.isFinite, report.value >= 0 else { return prefix + " —" }
            switch kind {
            case .cursorTeam: return prefix + " " + String(format: "%.0f req", report.value)
            case .openaiAPI, .xaiAPI: return prefix + " " + String(format: "$%.2f", report.value)
            }
        }
    }

    private func addMenuBarProviderSelectionMenu(to parent: NSMenu) {
        let item = NSMenuItem(title: "メニューバーに表示するAI", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: item.title)
        submenu.autoenablesItems = false
        for (id, name) in [("codex", "Codex（5h / Week）"), ("claude", "Claude（5h / Week）")] {
            addStayOpenRow(name, to: submenu,
                checked: { [weak self] in self?.preferences.visibleProviderIDs.contains(id) ?? false }) { [weak self] in
                self?.updateDisplaySetting { settings in
                    settings.setVisible(id, !settings.visibleProviderIDs.contains(id))
                }
            }
        }
        submenu.addItem(.separator())
        addStayOpenRow("GitHub Copilot（当月リクエスト）", to: submenu,
            checked: { [weak self] in
                self.map { UserDefaults.standard.bool(forKey: $0.copilotMenuBarKey) } ?? false
            }, enabledWhen: { [weak self] in
                guard let self else { return false }
                return self.copilotAccessMode.permitsPersonalBillingAPI && self.copilotClient.configured
            }) { [weak self] in self?.toggleCopilotBar() }
        for kind in ExternalAPIKind.allCases {
            addStayOpenRow(kind.name + "（当月API使用量）", to: submenu,
                checked: { [weak self] in self?.selectedAPIMenuBarIDs.contains(kind.rawValue) ?? false },
                enabledWhen: { [weak self] in self?.externalClients[kind]?.configured ?? false }) { [weak self] in
                self?.toggleAPIMenuBar(kind)
            }
        }
        item.submenu = submenu
        parent.addItem(item)
    }

    private func addDisplaySettingsMenu(to parent: NSMenu) {
        let item = NSMenuItem(title: "表示設定", action: nil, keyEquivalent: "")
        MenuVisualStyle.adorn(item, symbol: "paintbrush.pointed")
        let menu = NSMenu(title: "表示設定")
        menu.autoenablesItems = false
        addMenuBarProviderSelectionMenu(to: menu)
        menu.addItem(.separator())
        addChoiceMenu("名前表示", options: [("フルネーム", NameStyle.full),
                                        ("短縮名", .short), ("各AIのアイコン", .icon)],
                      to: menu, selected: { [weak self] in self?.preferences.nameStyle ?? .full }) { [weak self] value in
            self?.updateDisplaySetting { $0.nameStyle = value }
        }
        addChoiceMenu("バー幅", options: [("短い", BarSize.compact),
                                      ("標準", .standard), ("長い", .wide)],
                      to: menu, selected: { [weak self] in self?.preferences.barSize ?? .standard }) { [weak self] value in
            self?.updateDisplaySetting { $0.barSize = value }
        }
        addChoiceMenu("表示形式", options: [("バーと数字", MetricStyle.barsAndPercent),
                                        ("バーのみ", .barsOnly), ("数字のみ", .percentOnly)],
                      to: menu, selected: { [weak self] in self?.preferences.metricStyle ?? .barsAndPercent }) { [weak self] value in
            self?.updateDisplaySetting { $0.metricStyle = value }
        }
        addChoiceMenu("AI同士の間隔", options: [("0pt", 0.0), ("3pt", 3.0), ("6pt", 6.0)],
                      to: menu, selected: { [weak self] in self?.preferences.providerGap ?? 3.0 }) { [weak self] value in
            self?.updateDisplaySetting { $0.setGap(value) }
        }
        let tintOptions: [(String, TintStyle)] = [("標準", .original), ("水色", .aqua),
            ("紫", .violet), ("金色", .gold), ("ピンク", .rose)]
        for (id, title) in [("codex", "Codex の色"), ("claude", "Claude の色")] {
            addChoiceMenu(title, options: tintOptions, to: menu,
                selected: { [weak self] in self?.preferences.tints[id] ?? .original }) { [weak self] value in
                self?.updateDisplaySetting { $0.tints[id] = value }
            }
        }
        menu.addItem(.separator())
        addStayOpenRow("表示設定を初期化", to: menu) { [weak self] in
            self?.resetSettings()
        }
        item.submenu = menu
        parent.addItem(item)
    }

    @objc private func toggleLaunchAtLogin() {
        let enabled = !wantsLaunchAtLogin
        wantsLaunchAtLogin = enabled
        UserDefaults.standard.set(enabled, forKey: loginPreferenceKey)
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status == .notRegistered { try service.register() }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
            loginRegistrationError = nil
        } catch {
            loginRegistrationError = error.localizedDescription
        }
        renderUI()
    }

    @objc private func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func resetSettings() {
        selectedAPIMenuBarIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: apiMenuBarSelectionKey)
        UserDefaults.standard.set(false, forKey: copilotMenuBarKey)
        preferences = AICheckerSettings()
        savePreferences()
    }
    @objc private func refreshNow() { refresh(force: true) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func percent(_ pct: Double?) -> String { pct.map { "\(Int($0.rounded()))%" } ?? "—" }
    private func dateText(_ date: Date?) -> String {
        guard let date = date else { return AppL10n.text("不明") }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

if CommandLine.arguments.contains("--ingest-claude-statusline") {
    // Official Claude Code statusLine invokes us with a dedicated profile UUID.
    // A missing or invalid ID MUST NOT write to any other account's cache.
    let args = CommandLine.arguments
    let id: UUID? = {
        guard let index = args.firstIndex(of: "--profile"), args.indices.contains(index + 1) else { return nil }
        return UUID(uuidString: args[index + 1])
    }()
    guard let profileID = id else {
        print("Claude · プロフィールの再設定が必要")
        exit(2)
    }
    // The statusLine input can contain arbitrary session metadata. Limit the
    // read BEFORE parsing to avoid unbounded memory consumption.
    let data = FileHandle.standardInput.readData(ofLength: 256 * 1024 + 1)
    if ClaudeStatusLineStore.importStatusLine(data, profileID: profileID),
       let snap = ClaudeStatusLineStore.read(profileID: profileID) {
        let five = snap.fiveHour.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—"
        let week = snap.weekly.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—"
        print("Claude · 残り 5h \(five) / 週 \(week)")
    } else {
        print("Claude · 利用率未取得")
    }
} else if CommandLine.arguments.contains("--selftest-packaged-bootstrap") {
    // Noninteractive AppKit bootstrap from the actual .app bundle.
    // NEVER load account data, register login items, request notifications,
    // contact providers, or start the application's event loop here.
    guard Bundle.main.bundleURL.pathExtension == "app",
          Bundle.main.bundleIdentifier == "dev.aichecker.localapp",
          Bundle.main.infoDictionary?["CFBundleExecutable"] as? String == "AIChecker",
          Bundle.main.infoDictionary?["LSUIElement"] as? Bool == true,
          let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
          let appIcon = NSImage(contentsOf: iconURL), appIcon.isValid else {
        fputs("FAIL: packaged application identity or icon\n", stderr)
        exit(1)
    }
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    application.applicationIconImage = appIcon
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard let button = statusItem.button,
          let launcherIcon = StatusArtwork.renderLauncherIcon(),
          launcherIcon.isValid else {
        fputs("FAIL: AppKit status item or launcher artwork\n", stderr)
        exit(1)
    }
    button.image = launcherIcon
    let smokeMenu = NSMenu(title: "AI Checker Bootstrap Test")
    smokeMenu.addItem(withTitle: "Bootstrap OK", action: nil, keyEquivalent: "")
    statusItem.menu = smokeMenu
    guard statusItem.menu?.items.count == 1,
          application.applicationIconImage?.isValid == true else {
        fputs("FAIL: AppKit menu or bundle icon assignment\n", stderr)
        exit(1)
    }

    // CI-only locale smoke: process arguments select a language without changing
    // system/application preferences. Do not load accounts or enter the app loop.
    if let option = CommandLine.arguments.firstIndex(of: "--selftest-language") {
        guard CommandLine.arguments.indices.contains(option + 1) else {
            fputs("FAIL: missing locale argument\n", stderr)
            exit(1)
        }
        let language = CommandLine.arguments[option + 1]
        guard language == "en" || language == "ja",
              Bundle.main.preferredLocalizations.first == language else {
            fputs("FAIL: bundled locale negotiation\n", stderr)
            exit(1)
        }
        let english = language == "en"
        let expectedRefresh = english ? "Refresh Now" : "今すぐ更新"
        let expectedHelp = english ? "If AI Checker Is Missing from the Menu Bar" : "メニューバーにAI Checkerが表示されない場合"
        let expectedShortcut = english ? "Could not register shortcut: TEST" : "割り当てに失敗: TEST"
        let expectedClaude = english
            ? "Claude: No quota data has arrived from the official statusLine (Claude Code integration is optional)."
            : "Claude: 公式statusLineから使用率が届いていません（Claude Code連携は任意）。"
        guard AppL10n.text("今すぐ更新") == expectedRefresh,
              AppL10n.text("メニューバーにAI Checkerが表示されない場合") == expectedHelp,
              AppL10n.format("割り当てに失敗: %@", "TEST") == expectedShortcut,
              AppL10n.text("Claude: 公式statusLineから使用率が届いていません（Claude Code連携は任意）。") == expectedClaude else {
            fputs("FAIL: bundle localization lookup\n", stderr)
            exit(1)
        }
        let localizedMenu = NSMenu(title: "メニューバーにAI Checkerが表示されない場合")
        localizedMenu.addItem(withTitle: "今すぐ更新", action: nil, keyEquivalent: "")
        AppL10n.apply(to: localizedMenu)
        guard localizedMenu.title == expectedHelp,
              localizedMenu.items.first?.title == expectedRefresh else {
            fputs("FAIL: AppKit native menu localization\n", stderr)
            exit(1)
        }
        print("PASS: bundled \(language) localization and native menu (no account, no UI event loop)")
    }
    NSStatusBar.system.removeStatusItem(statusItem)
    print("PASS: packaged AppKit bootstrap, menu-bar item, icon and identity")
    print("TEST_SCOPE: no user data, no network, no login item, no notification, no event loop")
} else if CommandLine.arguments.contains("--selftest-status-layout") {
    // Native AppKit font measurements, without opening a menu or an account.
    let catalog = AIProviderRegistry.catalog
    var numeric = AICheckerSettings()
    numeric.metricStyle = .percentOnly
    var bars = numeric
    bars.metricStyle = .barsOnly
    var combined = numeric
    combined.metricStyle = .barsAndPercent
    var narrowBars = bars
    narrowBars.barSize = .compact
    var wideBars = bars
    wideBars.barSize = .wide
    var oneProvider = numeric
    oneProvider.visibleProviderIDs = ["codex"]
    func width(_ settings: AICheckerSettings) -> CGFloat {
        StatusArtwork.layout(for: settings, catalog: catalog).width
    }
    if !(width(numeric) < width(bars) &&
         width(bars) < width(combined) &&
         width(narrowBars) < width(wideBars) &&
         width(oneProvider) < width(numeric)) {
        fputs("FAIL: status item geometry does not follow visible content\n", stderr)
        exit(1)
    }
    var reportOnly = numeric
    reportOnly.visibleProviderIDs = []
    guard let apiOnlyImage = StatusArtwork.render([:], stale: false, demo: false,
        preferences: reportOnly, catalog: catalog, monthlyAPIReports: ["OA $1.23"]),
          apiOnlyImage.size.width > 40 else {
        fputs("FAIL: API-only status item must remain visible without invented quotas\n", stderr)
        exit(1)
    }
    print("PASS: API-only status item shows actual monthly usage without quota bars")
    print("PASS: AppKit status geometry numeric < bars < combined; compact < wide; one < two")
 } else if CommandLine.arguments.contains("--selftest-quick-access-layout") {
    // No accessibility access, credentials, hotkey installation or windows required.
    guard let icon = StatusArtwork.renderLauncherIcon(), icon.size.width >= 20,
          icon.size.width <= 30, icon.size.height == StatusArtwork.height else {
        fputs("FAIL: compact launcher artwork dimensions\n", stderr)
        exit(1)
    }
    let core = AICheckerSettings()
    var compact = core
    compact.nameStyle = .icon
    compact.metricStyle = .percentOnly
    compact.providerGap = 0
    let width = StatusArtwork.layout(for: compact, catalog: AIProviderRegistry.catalog).width
    guard width > 23 else { fputs("FAIL: compact mode width\n", stderr); exit(1) }
    print("PASS: independent 23pt launcher icon and compact layout available")
} else if CommandLine.arguments.contains("--selftest-claude-profile") {
    // Local, offline contract test. Writes only a fresh UUID-scoped directory
    // and removes it afterwards; never touches ~/.claude or credentials.
    let account = AICheckerAccount(providerID: "claude", label: "TEST")
    let root = ClaudeProfileClient.root(account.id)
    defer { try? FileManager.default.removeItem(at: root) }
    enum SelfTestError: Swift.Error { case unexpected }
    do {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0])
        let script = try ClaudeProfileClient.prepare(account, executable: exe)
        let settingsURL = ClaudeProfileClient.config(account.id).appendingPathComponent("settings.json")
        let settings = try Data(contentsOf: settingsURL)
        let json = try JSONSerialization.jsonObject(with: settings) as? [String: Any]
        let status = json?["statusLine"] as? [String: Any]
        guard status?["type"] as? String == "command",
              (status?["command"] as? String)?.contains("--profile \(account.id.uuidString.lowercased())") == true,
              FileManager.default.isExecutableFile(atPath: script.path) else { throw SelfTestError.unexpected }
        _ = try ClaudeProfileClient.prepare(account, executable: exe) // idempotent
        // Refuse to modify an existing user's custom statusLine.
        let customized = Data(#"{"statusLine":{"type":"command","command":"echo existing"}}"#.utf8)
        try customized.write(to: settingsURL, options: .atomic)
        do {
            _ = try ClaudeProfileClient.prepare(account, executable: exe)
            throw SelfTestError.unexpected
        } catch ClaudeProfileClient.Error.existingSettings {
            let unchanged = try Data(contentsOf: settingsURL)
            guard unchanged == customized else { throw SelfTestError.unexpected }
        } catch {
            throw error
        }
        // The cache reader must ignore an oversized file without parsing it,
        // and without reading outside this newly generated test profile.
        let cache = ClaudeProfileClient.quota(account.id)
        try Data(repeating: 65, count: 4096).write(to: cache, options: .atomic)
        guard ClaudeStatusLineStore.read(profileID: account.id) == nil else {
            throw SelfTestError.unexpected
        }
        try FileManager.default.removeItem(at: cache)
        print("PASS: isolated Claude cache over-limit guard")
        print("PASS: isolated Claude profile, idempotence, custom-settings non-overwrite")
    } catch {
        fputs("FAIL: Claude profile selftest: \(error)\n", stderr)
        exit(1)
    }
} else {
    let app = NSApplication.shared
    let delegate = AICheckerApplication()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
