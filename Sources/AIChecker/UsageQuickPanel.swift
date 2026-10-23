import AppKit
import AICheckerCore

/// Recovery entry point when macOS cannot fit the menu-bar item.
/// This is an on-demand panel, not a permanently floating overlay.
final class UsageQuickPanel {
    private var window: NSPanel?
    private let width: CGFloat = 612
    private var onRefresh: (() -> Void)?
    private var onGuide: (() -> Void)?
    private var onMode: ((MenuBarPresentation) -> Void)?
    private var onShortcut: ((Bool, QuickPanelShortcut) -> Void)?
    private var mode: MenuBarPresentation = .standard
    private var shortcut: QuickPanelShortcut = .defaultShortcut
    private var shortcutEnabled = true
    private var shortcutError: String?
    var isVisible: Bool { window?.isVisible ?? false }

    func configure(mode: MenuBarPresentation, shortcut: QuickPanelShortcut,
                   shortcutEnabled: Bool, shortcutError: String?,
                   onMode: @escaping (MenuBarPresentation) -> Void,
                   onShortcut: @escaping (Bool, QuickPanelShortcut) -> Void) {
        self.mode = mode
        self.shortcut = shortcut
        self.shortcutEnabled = shortcutEnabled
        self.shortcutError = shortcutError
        self.onMode = onMode
        self.onShortcut = onShortcut
    }

    func present(catalog: [AIProviderDescriptor], snapshots: [String: AIQuotaSnapshot],
                 failures: [String: ProviderFailure?],
                 onRefresh: @escaping () -> Void, onGuide: @escaping () -> Void) {
        self.onRefresh = onRefresh
        self.onGuide = onGuide
        let panel = ensurePanel()
        refresh(catalog: catalog, snapshots: snapshots, failures: failures)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func refresh(catalog: [AIProviderDescriptor], snapshots: [String: AIQuotaSnapshot],
                 failures: [String: ProviderFailure?]) {
        guard let panel = window else { return }
        let inner = NSView(frame: NSRect(x: 0, y: 0, width: width,
                                         height: 132 + CGFloat(catalog.count) * 126))
        inner.wantsLayer = true
        inner.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let heading = NSTextField(labelWithString: AppL10n.text("AI Checker  ·  利用状況"))
        heading.font = NSFont.boldSystemFont(ofSize: 18)
        heading.frame = NSRect(x: 24, y: inner.bounds.height - 42, width: 560, height: 25)
        inner.addSubview(heading)

        let hintText = shortcutError == nil
            ? AppL10n.text("メニューバーから隠れても、このパネルで残量を確認できます")
            : AppL10n.text("ショートカットが登録できません。下の『キー』から変更してください。")
        let hint = NSTextField(labelWithString: hintText)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = shortcutError == nil ? .secondaryLabelColor : .systemOrange
        hint.frame = NSRect(x: 24, y: inner.bounds.height - 65, width: 560, height: 19)
        inner.addSubview(hint)

        let count = catalog.count
        for (index, descriptor) in catalog.enumerated() {
            let card = UsageDashboardMenuView(provider: descriptor,
                snapshot: snapshots[descriptor.id], failure: failures[descriptor.id] ?? nil)
            card.frame.origin = NSPoint(x: 16, y: 89 + CGFloat(count - 1 - index) * 126)
            inner.addSubview(card)
        }

        let displayLabel = NSTextField(labelWithString: AppL10n.text("表示"))
        displayLabel.frame = NSRect(x: 24, y: 55, width: 45, height: 20)
        inner.addSubview(displayLabel)
        let density = NSPopUpButton(frame: NSRect(x: 70, y: 50, width: 173, height: 28), pullsDown: false)
        density.addItems(withTitles: ["通常", "省スペース", "アイコンのみ"].map(AppL10n.text))
        density.selectItem(at: [MenuBarPresentation.standard, .compact, .iconOnly].firstIndex(of: mode) ?? 0)
        density.target = self
        density.action = #selector(setMode(_:))
        inner.addSubview(density)

        let shortcutLabel = NSTextField(labelWithString: AppL10n.text("キー"))
        shortcutLabel.frame = NSRect(x: 257, y: 55, width: 45, height: 20)
        inner.addSubview(shortcutLabel)
        let key = NSPopUpButton(frame: NSRect(x: 296, y: 50, width: 209, height: 28), pullsDown: false)
        key.addItems(withTitles: ["⌃⌥⌘ A", "⌃⌥⌘ U", "OFF"])
        key.selectItem(at: shortcutEnabled ? (shortcut == .defaultShortcut ? 0 : 1) : 2)
        key.target = self
        key.action = #selector(setKey(_:))
        inner.addSubview(key)

        let refresh = NSButton(title: AppL10n.text("今すぐ更新"), target: self, action: #selector(refreshAction))
        refresh.frame = NSRect(x: width - 132, y: 13, width: 110, height: 28)
        inner.addSubview(refresh)
        let help = NSButton(title: AppL10n.text("整理方法"), target: self, action: #selector(guideAction))
        help.frame = NSRect(x: 20, y: 13, width: 110, height: 28)
        inner.addSubview(help)

        panel.setContentSize(NSSize(width: width, height: inner.frame.height))
        panel.contentView = inner
    }

    private func ensurePanel() -> NSPanel {
        if let window { return window }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 385),
                            styleMask: [.titled, .closable, .miniaturizable],
                            backing: .buffered, defer: false)
        panel.title = "AI Checker"
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.level = .floating
        panel.backgroundColor = .windowBackgroundColor
        window = panel
        return panel
    }

    @objc private func setMode(_ sender: NSPopUpButton) {
        let modes: [MenuBarPresentation] = [.standard, .compact, .iconOnly]
        guard modes.indices.contains(sender.indexOfSelectedItem) else { return }
        let choice = modes[sender.indexOfSelectedItem]
        // Do not replace the sender's view while AppKit is still dispatching its action.
        DispatchQueue.main.async { [weak self] in self?.onMode?(choice) }
    }

    @objc private func setKey(_ sender: NSPopUpButton) {
        let requested: (Bool, QuickPanelShortcut)?
        switch sender.indexOfSelectedItem {
        case 0: requested = (true, .defaultShortcut)
        case 1: requested = (true, .alternativeShortcut)
        case 2: requested = (false, shortcut)
        default: requested = nil
        }
        guard let requested else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onShortcut?(requested.0, requested.1)
        }
    }

    @objc private func refreshAction() { onRefresh?() }
    @objc private func guideAction() { onGuide?() }
    func close() { window?.close() }
}
