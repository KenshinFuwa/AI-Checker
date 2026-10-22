import AppKit

/// Original AI Checker symbol: one instrument ring, a distinct active arc,
/// and a small center check. No provider trademarks or external icon files.
enum AICheckerBrandArtwork {
    static func draw(in rect: NSRect) {
        let side = min(rect.width, rect.height)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let ring = NSRect(x: center.x - side * 0.34, y: center.y - side * 0.34,
                          width: side * 0.68, height: side * 0.68)
        let back = NSBezierPath(ovalIn: ring)
        back.lineWidth = max(1.2, side * 0.075)
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        back.stroke()
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: side * 0.34,
                      startAngle: -65, endAngle: 220, clockwise: false)
        arc.lineWidth = max(1.2, side * 0.092)
        arc.lineCapStyle = .round
        NSColor.systemTeal.setStroke()
        arc.stroke()
        let check = NSBezierPath()
        check.move(to: NSPoint(x: center.x - side * 0.17, y: center.y))
        check.line(to: NSPoint(x: center.x - side * 0.03, y: center.y - side * 0.12))
        check.line(to: NSPoint(x: center.x + side * 0.20, y: center.y + side * 0.15))
        check.lineWidth = max(1.3, side * 0.08)
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.labelColor.setStroke()
        check.stroke()
    }
}
