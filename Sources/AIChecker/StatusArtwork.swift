import AppKit
import AICheckerCore

/// One bitmap for the whole bar. No artificial fixed-width provider cells.
/// The bitmap itself begins at x=0; macOS can still apply a native button inset.
struct StatusArtwork {
    static let height: CGFloat = 27
    private static let nameFont = NSFont.boldSystemFont(ofSize: 10)
    private static let rowFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    private static let iconWidth: CGFloat = 21

    struct Slot {
        let descriptor: AIProviderDescriptor
        let startX: CGFloat
        let cadenceX: CGFloat
        let barX: CGFloat
        let percentX: CGFloat
        let right: CGFloat
    }

    private static func measure(_ s: String, font: NSFont) -> CGFloat {
        ceil((s as NSString).size(withAttributes: [.font: font]).width)
    }

    static func layout(for preferences: AICheckerSettings,
                       catalog: [AIProviderDescriptor]) -> (width: CGFloat, slots: [Slot]) {
        let visible = preferences.visibleProviders(in: catalog)
        guard !visible.isEmpty else { return (0, []) }
        let cadenceWidth = max(measure("5h", font: rowFont), measure("W", font: rowFont))
        let pctWidth = max(measure("100%", font: rowFont), measure("—", font: rowFont))
        let gap = CGFloat(max(0, min(12, preferences.providerGap)))
        var cursor: CGFloat = 0 // user-requested zero image inset
        var slots: [Slot] = []
        for (i, descriptor) in visible.enumerated() {
            if i > 0 { cursor += gap }
            let labelWidth: CGFloat
            switch preferences.nameStyle {
            case .full: labelWidth = measure(descriptor.name, font: nameFont)
            case .short: labelWidth = measure(descriptor.shortName, font: nameFont)
            case .icon: labelWidth = iconWidth
            }
            let cadenceX = cursor + labelWidth + CGFloat(CompactLayout.labelToCadence)
            let barX = cadenceX + cadenceWidth + CGFloat(CompactLayout.cadenceToBar)
            let percentX: CGFloat = preferences.metricStyle.showBars
                ? barX + CGFloat(preferences.barSize.width) + CGFloat(CompactLayout.barToPercent)
                : barX
            let right: CGFloat = preferences.metricStyle.showPercent
                ? percentX + pctWidth
                : preferences.metricStyle.showBars ? barX + CGFloat(preferences.barSize.width)
                                                 : cadenceX + cadenceWidth
            slots.append(Slot(descriptor: descriptor, startX: cursor, cadenceX: cadenceX,
                              barX: barX, percentX: percentX, right: right))
            cursor = right
        }
        return (ceil(cursor), slots)
    }

    static func render(_ snapshots: [String: AIQuotaSnapshot], stale: Bool,
                       demo: Bool, preferences: AICheckerSettings,
                       catalog: [AIProviderDescriptor],
                       monthlyCopilotUsage: CopilotPremiumUsage? = nil) -> NSImage? {
        let geometry = layout(for: preferences, catalog: catalog)
        guard !geometry.slots.isEmpty else { return nil }
        // Monthly count is a different metric from 5h/weekly remaining. It is
        // appended as a labelled text meter only when the user opts in.
        let countLabel = monthlyCopilotUsage.map {
            "GH " + String(format: "%.1f", $0.grossRequests) + " req"
        }
        let extraWidth: CGFloat = countLabel.map { measure($0, font: rowFont) + 6 } ?? 0
        let img = NSImage(size: NSSize(width: geometry.width + extraWidth, height: height), flipped: false) { _ in
            for slot in geometry.slots {
                draw(slot, snapshots: snapshots, stale: stale, preferences: preferences)
            }
            if let countLabel = countLabel {
                text(countLabel, x: geometry.width + 6, y: 8, font: rowFont, color: .secondaryLabelColor)
            }
            if demo { text("•", x: max(0, geometry.width + extraWidth - 5), y: 0, font: rowFont, color: .systemOrange) }
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func text(_ text: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor) {
        (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: font, .foregroundColor: color
        ])
    }

    private static func color(for descriptor: AIProviderDescriptor, settings: AICheckerSettings) -> NSColor {
        switch settings.tints[descriptor.id] ?? .original {
        case .original: return descriptor.id == "codex" ? .systemGreen : (descriptor.id == "claude" ? .systemOrange : .systemTeal)
        case .aqua: return .systemTeal
        case .violet: return .systemPurple
        case .gold: return .systemYellow
        case .rose: return .systemPink
        }
    }

    private static func draw(_ slot: Slot, snapshots: [String: AIQuotaSnapshot],
                             stale: Bool, preferences: AICheckerSettings) {
        // Provider tint controls text labels only; quota meters always use
        // the same threshold colors and packaged glyphs keep their own colors.
        let nameColor = color(for: slot.descriptor, settings: preferences)
        switch preferences.nameStyle {
        case .full:
            text(slot.descriptor.name, x: slot.startX, y: 7.5, font: nameFont, color: nameColor)
        case .short:
            text(slot.descriptor.shortName, x: slot.startX, y: 7.5, font: nameFont, color: nameColor)
        case .icon:
            ProviderIconArtwork.draw(id: slot.descriptor.id,
                at: NSRect(x: slot.startX, y: 2.5, width: 21, height: 21),
                color: slot.descriptor.id == "codex" ? .white :
                    (slot.descriptor.id == "claude" ? .systemOrange : .systemTeal))
        }
        let snapshot = snapshots[slot.descriptor.id]
        // A missing/stale Claude input must not grey out a fresh Codex bar (and
        // vice versa). Provider freshness comes from the provider observation.
        let providerStale: Bool = {
            guard let observed = snapshot?.updatedAt else { return true }
            let age = Date().timeIntervalSince(observed)
            return age > 180 || age < -60
        }()
        let values: [Double?] = [snapshot?.fiveHour.remainingPercent, snapshot?.weekly.remainingPercent]
        for index in 0..<2 {
            let y: CGFloat = index == 0 ? 14 : 2
            let value = values[index]
            text(index == 0 ? "5h" : "W", x: slot.cadenceX, y: y, font: rowFont, color: .labelColor)
            if preferences.metricStyle.showBars {
                let totalWidth = CGFloat(preferences.barSize.width)
                let track = NSRect(x: slot.barX, y: y + 4, width: totalWidth, height: 6)
                NSColor.quaternaryLabelColor.setFill()
                NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
                if let pct = value, pct > 0 {
                    let filled = NSRect(x: track.minX, y: track.minY,
                                        width: track.width * CGFloat(pct / 100), height: 6)
                    (providerStale ? NSColor.secondaryLabelColor :
                        (QuotaColorPalette.color(for: value) ?? .secondaryLabelColor)).setFill()
                    NSBezierPath(roundedRect: filled, xRadius: 3, yRadius: 3).fill()
                }
            }
            if preferences.metricStyle.showPercent {
                let percent = value.map { "\(Int($0.rounded()))%" } ?? "—"
                text(percent, x: slot.percentX, y: y, font: rowFont,
                     color: value == nil || providerStale ? .secondaryLabelColor :
                         (QuotaColorPalette.color(for: value) ?? .secondaryLabelColor))
            }
        }
    }
}
