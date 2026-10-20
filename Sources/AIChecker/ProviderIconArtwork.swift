import AppKit

/// Lightweight vector icons drawn in the existing status bitmap.
/// They never fetch remote assets or require an installed provider desktop app.
/// Simple in-house symbols are inspired by the services, not official artwork.
enum ProviderIconArtwork {
    // Do not use desktop app icons: their square backgrounds were too small
    // and looked different from the user's preferred compact glyphs.

    private static var packagedAssets: [String: NSImage] = [:]
    private static func packagedIcon(for id: String) -> NSImage? {
        if let saved = packagedAssets[id] { return saved }
        guard id == "codex" || id == "claude",
              let resources = Bundle.main.resourceURL,
              let image = NSImage(contentsOf: resources.appendingPathComponent("\(id).png")) else {
            return nil
        }
        packagedAssets[id] = image
        return image
    }

    static func draw(id: String, at rect: NSRect, color: NSColor) {
        guard rect.width > 0 && rect.height > 0 else { return }
        if let icon = packagedIcon(for: id) {
            icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return
        }
        // If the bundled artwork is unavailable in a development invocation,
        // use the independent in-house vector rather than a black app tile.
        let center = NSPoint(x: rect.midX, y: rect.midY)
        if id == "claude" {
            // Distinct eight-rayed Claude-inspired starburst.
            for ray in 0..<8 {
                let angle = CGFloat(ray) * .pi / 4
                let path = NSBezierPath()
                path.lineWidth = 1.9
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: center.x + CGFloat(cos(Double(angle))) * 2.2, y: center.y + CGFloat(sin(Double(angle))) * 2.2))
                path.line(to: NSPoint(x: center.x + CGFloat(cos(Double(angle))) * 6.1, y: center.y + CGFloat(sin(Double(angle))) * 6.1))
                color.setStroke()
                path.stroke()
            }
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)).fill()
        } else if id == "codex" || id == "chatgpt" {
            // Six interwoven petals suggest an OpenAI-style knot without using an asset.
            for ray in 0..<6 {
                let a = CGFloat(ray) * .pi / 3
                let x = center.x + CGFloat(cos(Double(a))) * 2.4
                let y = center.y + CGFloat(sin(Double(a))) * 2.4
                let petal = NSBezierPath(ovalIn: NSRect(x: x - 2.5, y: y - 2.5, width: 5.0, height: 5.0))
                petal.lineWidth = 1.05
                color.setStroke()
                petal.stroke()
            }
        } else {
            // Fallback for future registered providers.
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1.8, dy: 1.8))
            circle.lineWidth = 1.5
            color.setStroke()
            circle.stroke()
        }
    }
}
