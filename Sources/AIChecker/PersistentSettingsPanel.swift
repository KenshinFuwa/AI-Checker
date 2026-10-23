import AppKit
import AICheckerCore

/// A modeless settings window. Native NSMenu submenus close after a selection;
/// controls here intentionally stay visible across successive changes.
final class PersistentSettingsPanel: NSObject, NSWindowDelegate {
    var onDisplayChange: ((AICheckerSettings) -> Void)?
    var onCopilotModeChange: ((CopilotAccessMode) -> Bool)?
    var onLaunchAtLoginChange: ((Bool) -> Bool)?

    private var window: NSPanel?
    private var state = AICheckerSettings()
    private var billingMode: CopilotAccessMode = .undetermined
    private var launchAtLogin = false
    private var launchButton: NSButton?
    private var providerButtons: [String: NSButton] = [:]
    private var namePopup: NSPopUpButton!
    private var barPopup: NSPopUpButton!
    private var metricPopup: NSPopUpButton!
    private var gapPopup: NSPopUpButton!
    private var codexTintPopup: NSPopUpButton!
    private var claudeTintPopup: NSPopUpButton!
    private var copilotPopup: NSPopUpButton!

    private let nameStyles: [NameStyle] = [.full, .short, .icon]
    private let barSizes: [BarSize] = [.compact, .standard, .wide]
    private let metrics: [MetricStyle] = [.barsAndPercent, .barsOnly, .percentOnly]
    private let gaps: [Double] = [0, 3, 6]
    private let tints: [TintStyle] = [.original, .aqua, .violet, .gold, .rose]
    private let modes = CopilotAccessMode.allCases

    func show(settings: AICheckerSettings, copilotMode: CopilotAccessMode,
              launchAtLogin: Bool) {
        state = settings
        billingMode = copilotMode
        self.launchAtLogin = launchAtLogin
        if window == nil { createPanel() }
        synchronizeControls()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(settings: AICheckerSettings, copilotMode: CopilotAccessMode,
                launchAtLogin: Bool) {
        state = settings
        billingMode = copilotMode
        self.launchAtLogin = launchAtLogin
        guard window?.isVisible == true else { return }
        synchronizeControls()
    }

    private func createPanel() {
        let w: CGFloat = 582
        let h: CGFloat = 622
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                            styleMask: [.titled, .closable, .miniaturizable],
                            backing: .buffered, defer: false)
        panel.title = "AI Checker — Preferences"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        panel.minSize = NSSize(width: w, height: h)
        panel.maxSize = NSSize(width: w, height: h)

        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        func group(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
            let box = NSBox(frame: NSRect(x: x, y: y, width: width, height: height))
            box.boxType = .custom
            box.borderWidth = 0.75
            box.borderColor = NSColor.separatorColor.withAlphaComponent(0.55)
            box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.60)
            box.cornerRadius = 14
            content.addSubview(box)
        }
        func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat,
                   size: CGFloat = 12, weight: NSFont.Weight = .regular,
                   secondary: Bool = false) {
            let field = NSTextField(labelWithString: AppL10n.text(value))
            field.frame = NSRect(x: x, y: y, width: width, height: 23)
            field.font = .systemFont(ofSize: size, weight: weight)
            if secondary { field.textColor = .secondaryLabelColor }
            content.addSubview(field)
        }
        func popup(_ choices: [String], y: CGFloat, action: Selector) -> NSPopUpButton {
            let control = NSPopUpButton(frame: NSRect(x: 217, y: y, width: 333, height: 29), pullsDown: false)
            control.addItems(withTitles: choices.map(AppL10n.text))
            control.target = self
            control.action = action
            content.addSubview(control)
            return control
        }

        label("AI CHECKER", x: 30, y: 576, width: 430, size: 21, weight: .bold)
        label("表示とアカウントの設定", x: 31, y: 553, width: 430,
              size: 12, secondary: true)
        label("変更は自動保存。何度切り替えても、この画面は閉じません。",
              x: 31, y: 528, width: 514, size: 11, secondary: true)

        group(x: 20, y: 226, width: 542, height: 291)
        label("DISPLAY  /  メニューバー", x: 41, y: 484, width: 490,
              size: 12, weight: .semibold)
        for (id, title, x) in [("codex", "Codex を表示", CGFloat(47)),
                                ("claude", "Claude を表示", CGFloat(277))] {
            let button = NSButton(checkboxWithTitle: AppL10n.text(title), target: self,
                                  action: #selector(changeDisplay(_:)))
            button.frame = NSRect(x: x, y: 454, width: 212, height: 26)
            providerButtons[id] = button
            content.addSubview(button)
        }
        label("名前表示", x: 47, y: 420, width: 146)
        namePopup = popup(["フルネーム", "短縮名", "各AIのアイコン"], y: 415,
                          action: #selector(changeDisplay(_:)))
        label("バーの長さ", x: 47, y: 386, width: 146)
        barPopup = popup(["短い", "標準", "長い"], y: 381,
                         action: #selector(changeDisplay(_:)))
        label("表示形式", x: 47, y: 352, width: 146)
        metricPopup = popup(["バー + 数字", "バーのみ", "数字のみ"], y: 347,
                            action: #selector(changeDisplay(_:)))
        label("AI同士の間隔", x: 47, y: 318, width: 146)
        gapPopup = popup(["0pt（最小）", "3pt", "6pt"], y: 313,
                         action: #selector(changeDisplay(_:)))
        label("Codex の文字色", x: 47, y: 284, width: 146)
        codexTintPopup = popup(["標準", "水色", "紫", "金色", "ピンク"], y: 279,
                                action: #selector(changeDisplay(_:)))
        label("Claude の文字色", x: 47, y: 250, width: 146)
        claudeTintPopup = popup(["標準", "水色", "紫", "金色", "ピンク"], y: 245,
                                 action: #selector(changeDisplay(_:)))

        group(x: 20, y: 95, width: 542, height: 120)
        label("GITHUB COPILOT  /  利用区分", x: 41, y: 183, width: 505,
              size: 12, weight: .semibold)
        copilotPopup = popup(modes.map(\.menuLabel), y: 146,
                             action: #selector(changeCopilot(_:)))
        label("API連携", x: 47, y: 152, width: 145)
        label("個人課金なしなら請求APIを停止します。", x: 47, y: 117,
              width: 480, size: 11, secondary: true)

        let login = NSButton(checkboxWithTitle: AppL10n.text("ログイン時に自動起動"), target: self,
                             action: #selector(changeLaunchAtLogin(_:)))
        login.frame = NSRect(x: 47, y: 70, width: 365, height: 22)
        content.addSubview(login)
        launchButton = login

        let reset = NSButton(title: AppL10n.text("表示設定を初期化"), target: self,
                             action: #selector(resetDisplay))
        reset.frame = NSRect(x: 29, y: 35, width: 170, height: 33)
        content.addSubview(reset)
        let close = NSButton(title: AppL10n.text("完了"), target: self, action: #selector(closePanel))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\r"
        close.frame = NSRect(x: 449, y: 35, width: 107, height: 33)
        content.addSubview(close)
        panel.contentView = content
        window = panel
    }

    private func synchronizeControls() {
        providerButtons["codex"]?.state = state.visibleProviderIDs.contains("codex") ? .on : .off
        providerButtons["claude"]?.state = state.visibleProviderIDs.contains("claude") ? .on : .off
        namePopup.selectItem(at: nameStyles.firstIndex(of: state.nameStyle) ?? 0)
        barPopup.selectItem(at: barSizes.firstIndex(of: state.barSize) ?? 1)
        metricPopup.selectItem(at: metrics.firstIndex(of: state.metricStyle) ?? 0)
        gapPopup.selectItem(at: gaps.firstIndex(of: state.providerGap) ?? 1)
        codexTintPopup.selectItem(at: tints.firstIndex(of: state.tints["codex"] ?? .original) ?? 0)
        claudeTintPopup.selectItem(at: tints.firstIndex(of: state.tints["claude"] ?? .original) ?? 0)
        copilotPopup.selectItem(at: modes.firstIndex(of: billingMode) ?? 0)
        launchButton?.state = launchAtLogin ? .on : .off
    }

    @objc private func changeDisplay(_ sender: Any?) {
        var updated = state
        for (id, button) in providerButtons {
            updated.setVisible(id, button.state == .on)
        }
        // A hidden-only status item could become inaccessible; reject that state.
        if !updated.visibleProviderIDs.contains("codex") &&
           !updated.visibleProviderIDs.contains("claude") {
            synchronizeControls()
            NSSound.beep()
            return
        }
        updated.nameStyle = nameStyles[namePopup.indexOfSelectedItem]
        updated.barSize = barSizes[barPopup.indexOfSelectedItem]
        updated.metricStyle = metrics[metricPopup.indexOfSelectedItem]
        updated.setGap(gaps[gapPopup.indexOfSelectedItem])
        updated.tints["codex"] = tints[codexTintPopup.indexOfSelectedItem]
        updated.tints["claude"] = tints[claudeTintPopup.indexOfSelectedItem]
        state = updated
        onDisplayChange?(updated)
    }

    @objc private func changeCopilot(_ sender: NSPopUpButton) {
        let selected = modes[sender.indexOfSelectedItem]
        if selected == billingMode { return }
        if onCopilotModeChange?(selected) == true {
            billingMode = selected
        }
        synchronizeControls() // restore prior choice if billing opt-in was declined
    }

    @objc private func changeLaunchAtLogin(_ sender: NSButton) {
        let desired = sender.state == .on
        launchAtLogin = onLaunchAtLoginChange?(desired) ?? launchAtLogin
        synchronizeControls()
    }

    @objc private func resetDisplay() {
        state = AICheckerSettings()
        synchronizeControls()
        onDisplayChange?(state)
    }

    @objc private func closePanel() { window?.orderOut(nil) }
}
