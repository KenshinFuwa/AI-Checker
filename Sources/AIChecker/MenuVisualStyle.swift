import AppKit

/// Reusable native menu styling, intentionally lightweight (no extra windows,
/// polling, timers or third-party UI dependencies).
enum MenuVisualStyle {
    static func heading(_ title: String) -> NSMenuItem {
        let localizedTitle = AppL10n.text(title)
        let item = NSMenuItem(title: localizedTitle, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(string: "  " + localizedTitle.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        return item
    }

    static func adorn(_ item: NSMenuItem, symbol: String) {
        guard let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return }
        icon.isTemplate = true
        icon.size = NSSize(width: 15, height: 15)
        item.image = icon
    }
}
