import AppKit

/// A menu item view that handles its own mouse gesture without asking NSMenu
/// to perform the usual select-and-dismiss action. This is intentionally only
/// used for in-place settings and menu-side commands, not for authentication.
final class StayOpenMenuRow: NSView {
    private let caption: String
    private let symbolName: String?
    private let current: () -> Bool
    private let activate: () -> Void
    private let available: () -> Bool
    private var hovering = false
    private var pressing = false
    private var tracking: NSTrackingArea?

    init(_ caption: String, checked: @escaping () -> Bool = { false },
         enabled: Bool = true, enabledWhen: @escaping () -> Bool = { true },
         symbolName: String? = nil, action: @escaping () -> Void) {
        self.caption = caption
        self.symbolName = symbolName
        self.current = checked
        self.available = { enabled && enabledWhen() }
        self.activate = action
        super.init(frame: NSRect(x: 0, y: 0, width: 250, height: 29))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(caption)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) {
        guard available() else { return }
        pressing = true
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        // AppKit may deliver mouseUp without a matching mouseDown to custom
        // views in tracked menus (e.g., after a submenu opens).
        let shouldActivate = available() && inside
        pressing = false
        needsDisplay = true
        if shouldActivate { activate() }
    }
    override func keyDown(with event: NSEvent) {
        if available() && (event.keyCode == 49 || event.keyCode == 36) {
            activate()
            needsDisplay = true
        } else { super.keyDown(with: event) }
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if available() && (hovering || pressing) {
            NSColor.controlAccentColor.withAlphaComponent(pressing ? 0.32 : 0.20).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 1), xRadius: 5, yRadius: 5).fill()
        }
        let textColor: NSColor = available() ? .labelColor : .tertiaryLabelColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: textColor
        ]
        if current() {
            ("✓" as NSString).draw(at: NSPoint(x: 13, y: (bounds.height - 16) / 2),
                                   withAttributes: attributes)
        } else if let symbolName,
                  let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
                  let image = symbol.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)) {
            image.draw(in: NSRect(x: 13, y: (bounds.height - 16) / 2,
                                  width: 16, height: 16),
                       from: .zero, operation: .sourceOver,
                       fraction: available() ? 1 : 0.45)
        }
        let titleRect = NSRect(x: 37, y: (bounds.height - 18) / 2,
                               width: bounds.width - 48, height: 19)
        (caption as NSString).draw(in: titleRect, withAttributes: attributes)
    }
}
