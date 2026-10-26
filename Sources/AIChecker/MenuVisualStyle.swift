import AppKit

/// Reusable native menu styling, intentionally lightweight (no extra windows,
/// polling, timers or third-party UI dependencies).
enum MenuVisualStyle {
    static func heading(_ title: String) -> NSMenuItem {
        // A disabled NSMenuItem dims even an attributed title on macOS.
        // A passive native NSView keeps the section label legible in dark mode.
        let localizedTitle = AppL10n.text(title)
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 27))
        let label = NSTextField(labelWithString: localizedTitle.uppercased())
        label.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        label.textColor = NSColor.secondaryLabelColor
        label.frame = NSRect(x: 38, y: 5, width: 525, height: 18)
        container.addSubview(label)
        item.view = container
        return item
    }

    static func adorn(_ item: NSMenuItem, symbol: String) {
        guard let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return }
        icon.isTemplate = true
        icon.size = NSSize(width: 15, height: 15)
        item.image = icon
    }
}
