import AppKit
import AICheckerCore

/// Actions are dispatched by the application. This view never accesses or stores credentials.
enum AccountPanelAction {
    case selectCodex(UUID), selectClaude(UUID)
    case addCodex, loginCodex, logoutCodex, renameCodex, removeCodex, reconnectCodex, chooseCodexCLI
    case addClaude, loginClaudeWeb, refreshClaudeWeb, disconnectClaudeWeb, loginClaudeCode, renameClaude, removeClaude
    case configureCopilot, disconnectCopilot, refreshCopilot, copilotInfo, copilotTroubleshooting, toggleCopilotBar
    case configureAPI(ExternalAPIKind), refreshAPI(ExternalAPIKind), disconnectAPI(ExternalAPIKind)
    case providerInfo(String), displaySettings
}

struct AccountPanelRecord: Equatable {
    let id: UUID
    let label: String
    let selected: Bool
}

struct AccountPanelState: Equatable {
    let codex: [AccountPanelRecord]
    let claude: [AccountPanelRecord]
    let codexStatus: String
    let claudeStatus: String
    let claudeWebEnabled: Bool
    let copilotConfigured: Bool
    let copilotStatus: String
    let copilotMode: CopilotAccessMode
    let copilotBarEnabled: Bool
    let externalConfigured: [ExternalAPIKind: Bool]
    let externalStatuses: [ExternalAPIKind: String]
}

/// A modeless connection window: unlike NSMenu submenus it stays open on each action.
/// Native connection dialogs can appear over it, and the original section remains visible.
final class PersistentAccountsPanel: NSObject, NSWindowDelegate {
    enum Section: Int, CaseIterable {
        case codex, claude, copilot, api, catalog
        var title: String {
            switch self {
            case .codex: return "Codex"
            case .claude: return "Claude"
            case .copilot: return "GitHub Copilot"
            case .api: return "APIレポート"
            case .catalog: return "AIサービスを追加"
            }
        }
    }

    var onAction: ((AccountPanelAction) -> Void)?
    private var window: NSPanel?
    private var scrollView: NSScrollView?
    private var navigation: [NSButton] = []
    private var selectedSection: Section = .codex
    private var current: AccountPanelState?
    private var commands: [Int: AccountPanelAction] = [:]
    private var nextTag = 100

    func show(section: Section, state: AccountPanelState) {
        selectedSection = section
        current = state
        if window == nil { createWindow() }
        rebuild()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(state: AccountPanelState) {
        let changed = current != state
        current = state
        guard changed, window?.isVisible == true else { return }
        rebuild(resetScroll: false)
    }

    private func createWindow() {
        let width: CGFloat = 760
        let height: CGFloat = 560
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                            styleMask: [.titled, .closable, .miniaturizable],
                            backing: .buffered, defer: false)
        panel.title = AppL10n.text("AI Checker — アカウントと接続")
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        panel.minSize = NSSize(width: width, height: height)
        panel.maxSize = NSSize(width: width, height: height)
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .windowBackground
        background.state = .active
        panel.contentView = background

        let title = NSTextField(labelWithString: AppL10n.text("ACCOUNTS  /  接続"))
        title.font = .systemFont(ofSize: 21, weight: .bold)
        title.frame = NSRect(x: 24, y: 510, width: 650, height: 29)
        background.addSubview(title)
        let hint = NSTextField(labelWithString: AppL10n.text("変更後もこの画面を維持します。接続情報は元の認証方式とKeychainに保存されます。"))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 24, y: 488, width: 706, height: 18)
        background.addSubview(hint)

        for (index, section) in Section.allCases.enumerated() {
            let button = NSButton(title: AppL10n.text(section.title), target: self, action: #selector(selectSection(_:)))
            button.tag = section.rawValue
            button.alignment = .left
            button.bezelStyle = .rounded
            button.setButtonType(.toggle)
            button.frame = NSRect(x: 18, y: 435 - CGFloat(index) * 48, width: 177, height: 38)
            background.addSubview(button)
            navigation.append(button)
        }
        let scroll = NSScrollView(frame: NSRect(x: 212, y: 37, width: 525, height: 437))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        background.addSubview(scroll)
        scrollView = scroll
        let close = NSButton(title: AppL10n.text("完了"), target: self, action: #selector(closePanel))
        close.bezelStyle = .rounded
        close.frame = NSRect(x: 640, y: 9, width: 95, height: 26)
        background.addSubview(close)
        window = panel
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let selected = Section(rawValue: sender.tag) else { return }
        selectedSection = selected
        rebuild()
    }

    private enum Line {
        case caption(String)
        case label(String)
        case command(String, AccountPanelAction, Bool)
    }

    private func makeLines(_ state: AccountPanelState) -> [Line] {
        var rows: [Line] = []
        switch selectedSection {
        case .codex:
            rows += [.caption("CODEX  /  アカウント管理"), .label("状態: \(state.codexStatus)")]
            if state.codex.isEmpty { rows.append(.label("未登録 — 以下からアカウントを追加できます")) }
            for record in state.codex {
                rows.append(.command("\(record.selected ? "✓ " : "○ ")\(record.label)", .selectCodex(record.id), true))
            }
            rows += [.command("アカウントを追加…", .addCodex, true),
                     .command("選択中アカウントでログイン…", .loginCodex, !state.codex.isEmpty),
                     .command("選択中アカウントからログアウト", .logoutCodex, !state.codex.isEmpty),
                     .command("名前を変更…", .renameCodex, !state.codex.isEmpty),
                     .command("選択中アカウントを削除…", .removeCodex, !state.codex.isEmpty),
                     .command("再接続", .reconnectCodex, true),
                     .command("Codex CLIの場所を選択…", .chooseCodexCLI, true)]
        case .claude:
            rows += [.caption("CLAUDE  /  プロフィール管理"), .label("状態: \(state.claudeStatus)")]
            if state.claude.isEmpty { rows.append(.label("未登録 — 以下からプロフィールを追加できます")) }
            for record in state.claude {
                rows.append(.command("\(record.selected ? "✓ " : "○ ")\(record.label)", .selectClaude(record.id), true))
            }
            rows += [.command("プロフィールを追加…", .addClaude, true),
                     .command("Claude Codeでログイン…", .loginClaudeCode, !state.claude.isEmpty),
                     .command("名前を変更…", .renameClaude, !state.claude.isEmpty),
                     .command("選択中プロフィールを削除…", .removeClaude, !state.claude.isEmpty)]
        case .copilot:
            rows += [.caption("GITHUB COPILOT  /  個人請求レポート"),
                     .label(state.copilotConfigured ? "接続設定あり" : "未接続（メインメニューから非表示）"),
                     .label("利用区分: \(state.copilotMode.menuLabel)"),
                     .label("状態: \(state.copilotStatus)"),
                     .caption("ChatGPTやCodexの5h/週残量とは別の請求APIです。"),
                     .command("利用区分を設定…", .displaySettings, true),
                     .command("個人課金APIを接続・更新…", .configureCopilot, state.copilotMode.permitsPersonalBillingAPI),
                     .command("Copilot取得対象について…", .copilotInfo, true)]
            if state.copilotConfigured {
                rows += [.command("今すぐ使用量を取得", .refreshCopilot, state.copilotMode.permitsPersonalBillingAPI),
                         .command("\(state.copilotBarEnabled ? "✓ " : "")メニューバーへの表示を切り替える", .toggleCopilotBar, state.copilotMode.permitsPersonalBillingAPI),
                         .command("通信エラーの対処…", .copilotTroubleshooting, true),
                         .command("保存済みトークンを削除して切断…", .disconnectCopilot, true)]
            }
        case .api:
            rows.append(.caption("OFFICIAL API REPORTS  /  組織・チーム向け"))
            rows.append(.label("API利用量を表示します。個人チャットの残量ではありません。"))
            for kind in ExternalAPIKind.allCases {
                let configured = state.externalConfigured[kind] == true
                rows += [.caption("\(kind.name) — \(configured ? "登録済み" : "未接続")"),
                         .label(kind.scope),
                         .label("状態: \(state.externalStatuses[kind] ?? "未取得")"),
                         .command("\(kind.name) のAPIキーを登録・更新…", .configureAPI(kind), true)]
                if configured {
                    rows += [.command("今すぐ取得", .refreshAPI(kind), true),
                             .command("Keychainのキーを削除して切断…", .disconnectAPI(kind), true)]
                }
            }
        case .catalog:
            rows += [.caption("AI SERVICES  /  接続先を選ぶ"),
                     .label("公式に確認できない個人向け残量は表示しません。"),
                     .command("Codexの接続設定 →", .providerInfo("codex"), true),
                     .command("Claudeの接続設定 →", .providerInfo("claude"), true),
                     .command("GitHub Copilotを接続 →", .providerInfo("copilot"), true),
                     .command("OpenAI API / Cursor Team / xAI API →", .providerInfo("external"), true)]
            for id in ["chatgpt", "gemini", "perplexity", "cursor", "grok"] {
                rows.append(.command("\(id.capitalized) の対応状況…", .providerInfo(id), true))
            }
        }
        return rows
    }

    private func rebuild(resetScroll: Bool = true) {
        guard let state = current else { return }
        let previousOffsetFromTop: CGFloat = {
            guard let scroll = scrollView, let oldHeight = scroll.documentView?.frame.height else { return 0 }
            return max(0, oldHeight - scroll.contentView.bounds.height - scroll.contentView.bounds.origin.y)
        }()
        for (index, button) in navigation.enumerated() {
            button.state = index == selectedSection.rawValue ? .on : .off
        }
        let lines = makeLines(state)
        let rowHeight: CGFloat = 39
        let contentHeight = max(437, CGFloat(lines.count) * rowHeight + 26)
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 502, height: contentHeight))
        commands.removeAll()
        nextTag = 100
        for (index, row) in lines.enumerated() {
            let y = contentHeight - 33 - CGFloat(index) * rowHeight
            switch row {
            case .caption(let value):
                let field = NSTextField(labelWithString: AppL10n.text(value))
                field.font = .systemFont(ofSize: 12, weight: .semibold)
                field.textColor = .secondaryLabelColor
                field.frame = NSRect(x: 12, y: y, width: 483, height: 24)
                document.addSubview(field)
            case .label(let value):
                let field = NSTextField(labelWithString: AppL10n.text(value))
                field.font = .systemFont(ofSize: 12)
                field.lineBreakMode = .byTruncatingTail
                field.frame = NSRect(x: 12, y: y, width: 480, height: 24)
                document.addSubview(field)
            case .command(let title, let command, let enabled):
                let button = NSButton(title: AppL10n.text(title), target: self, action: #selector(execute(_:)))
                button.bezelStyle = .rounded
                button.alignment = .left
                button.isEnabled = enabled
                button.frame = NSRect(x: 12, y: y - 3, width: 469, height: 32)
                button.tag = nextTag
                commands[nextTag] = command
                nextTag += 1
                document.addSubview(button)
            }
        }
        scrollView?.documentView = document
        if let scroll = scrollView {
            let fromTop: CGFloat = resetScroll ? 0 : previousOffsetFromTop
            let y = max(0, contentHeight - scroll.contentView.bounds.height - fromTop)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    @objc private func execute(_ sender: NSButton) {
        guard let command = commands[sender.tag] else { return }
        if case .providerInfo(let id) = command {
            switch id {
            case "codex": selectedSection = .codex
            case "claude": selectedSection = .claude
            case "copilot": selectedSection = .copilot
            case "external", "cursor", "grok": selectedSection = .api
            default: onAction?(command); return
            }
            rebuild()
            return
        }
        onAction?(command)
    }

    @objc private func closePanel() { window?.orderOut(nil) }
}
