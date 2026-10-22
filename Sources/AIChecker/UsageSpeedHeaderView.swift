import AppKit

/// Passive live readout at the right edge of the USAGE menu heading.
/// The menu starts/stops the sampler; this view never polls on its own.
final class UsageSpeedHeaderView: NSView {
    private var label = "↓ —    ↑ —"

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 580, height: 29))
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("AI Checker network transfer speed")
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }

    func begin() {
        label = "測定中…"
        needsDisplay = true
        displayIfNeeded()
    }

    func show(_ outcome: NetworkSpeedOutcome) {
        switch outcome {
        case .unavailable:
            label = "↓ —    ↑ —"
        case .reading(let rate):
            label = "↓ " + NetworkSpeedReading.format(rate.downBitsPerSecond)
                + "    ↑ " + NetworkSpeedReading.format(rate.upBitsPerSecond)
        }
        needsDisplay = true
        displayIfNeeded()
    }

    func end() {
        label = "↓ —    ↑ —"
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor]
        ("  AI CHECKER  /  USAGE" as NSString).draw(
            at: NSPoint(x: 10, y: 8), withAttributes: titleAttrs)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font,
            .foregroundColor: NSColor.secondaryLabelColor]
        let size = (label as NSString).size(withAttributes: attrs)
        (label as NSString).draw(at: NSPoint(x: bounds.width - size.width - 16,
                                               y: (bounds.height - size.height) / 2),
                                   withAttributes: attrs)
    }
}
