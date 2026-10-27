import AppKit
import AICheckerCore

/// A single elegant, full-width card per provider. Exactly two data rows:
/// LABEL | 215pt meter + percent | time until that SAME window resets.
/// The compact status-item bitmap is intentionally unaffected.
final class UsageDashboardMenuView: NSView {
    private let provider: AIProviderDescriptor
    private let snapshot: AIQuotaSnapshot?
    private let failure: ProviderFailure?

    init(provider: AIProviderDescriptor, snapshot: AIQuotaSnapshot?, failure: ProviderFailure?) {
        self.provider = provider
        self.snapshot = snapshot
        self.failure = failure
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: CGFloat(UsageMenuPresentation.providerCardWidth),
                                 height: CGFloat(UsageMenuPresentation.providerCardHeight)))
        autoresizingMask = []
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let now = Date()
        let fresh = TelemetryFreshness.isRecent(snapshot, now: now) && failure == nil
        let card = bounds.insetBy(dx: 8, dy: 5)
        let rounded = NSBezierPath(roundedRect: card, xRadius: 14, yRadius: 14)
        NSColor.controlBackgroundColor.withAlphaComponent(0.48).setFill()
        rounded.fill()
        NSColor.separatorColor.withAlphaComponent(0.63).setStroke()
        rounded.lineWidth = 0.8
        rounded.stroke()

        let headerY = CGFloat(UsageMenuPresentation.headerCenterY)
        let iconSize = CGFloat(UsageMenuPresentation.headerIconSize)
        ProviderIconArtwork.draw(id: provider.id,
            at: NSRect(x: CGFloat(UsageMenuPresentation.headerIconX),
                       y: headerY - iconSize / 2, width: iconSize, height: iconSize),
            color: provider.id == "codex" ? .white : .systemOrange)

        // NSString.draw(at:) uses the bottom of the string's layout box,
        // not its optical center. Center its measured box on the icon centerline.
        writeCentered(provider.name, atX: CGFloat(UsageMenuPresentation.headerTitleX),
                      centerY: headerY, font: .boldSystemFont(ofSize: 15),
                      color: .labelColor)

        // Right edge is EXACTLY the same as every countdown beneath this
        // heading; never give the caption an unrelated hard-coded x origin.
        writeRightAligned(AppL10n.text(UsageMenuPresentation.resetCaption),
                          rightX: CGFloat(UsageMenuPresentation.resetCaptionRightX),
                          centerY: headerY,
                          font: .systemFont(ofSize: 9, weight: .semibold),
                          color: .tertiaryLabelColor)

        let divider = NSBezierPath()
        let dividerY = CGFloat(UsageMenuPresentation.dividerY)
        divider.move(to: NSPoint(x: 28, y: dividerY))
        divider.line(to: NSPoint(x: bounds.width - 28, y: dividerY))
        divider.lineWidth = 0.5
        NSColor.separatorColor.withAlphaComponent(0.33).setStroke()
        divider.stroke()

        metric(label: AppL10n.text(UsageMenuPresentation.rowLabels[0]),
               percent: snapshot?.fiveHour.remainingPercent,
               resetAt: snapshot?.fiveHour.resetsAt,
               centerY: CGFloat(UsageMenuPresentation.fiveHourRowCenterY),
               now: now, fresh: fresh)
        metric(label: AppL10n.text(UsageMenuPresentation.rowLabels[1]),
               percent: snapshot?.weekly.remainingPercent,
               resetAt: snapshot?.weekly.resetsAt,
               centerY: CGFloat(UsageMenuPresentation.weekRowCenterY),
               now: now, fresh: fresh)
    }

    private func metric(label: String, percent: Double?, resetAt: Date?,
                        centerY: CGFloat, now: Date, fresh: Bool) {
        writeCentered(label, atX: CGFloat(UsageMenuPresentation.labelX), centerY: centerY,
                      font: .systemFont(ofSize: 11, weight: .medium),
                      color: .secondaryLabelColor)

        let track = NSRect(x: CGFloat(UsageMenuPresentation.meterX),
                           y: centerY - 4,
                           width: CGFloat(UsageMenuPresentation.meterWidth), height: 8)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: track, xRadius: 4, yRadius: 4).fill()
        let fraction = UsageMenuPresentation.fillFraction(fresh ? percent : nil)
        let accent = fresh ? QuotaColorPalette.color(for: percent) : nil
        if fraction > 0 {
            let fill = NSRect(x: track.minX, y: track.minY,
                              width: track.width * CGFloat(fraction), height: track.height)
            (accent ?? NSColor.tertiaryLabelColor).setFill()
            NSBezierPath(roundedRect: fill, xRadius: 4, yRadius: 4).fill()
        }
        writeCentered(UsageMenuPresentation.percentage(fresh ? percent : nil),
                      atX: CGFloat(UsageMenuPresentation.percentX), centerY: centerY,
                      font: .monospacedDigitSystemFont(ofSize: 12, weight: .bold),
                      color: accent ?? .secondaryLabelColor)

        let countdown = ResetCountdown.format(until: resetAt, now: now, fresh: fresh)
        writeCountdown(localizedCountdown(countdown), centerY: centerY)
    }

    /// Keep the validated core countdown math; adapt only its visual units.
    private func localizedCountdown(_ english: String) -> String {
        guard Bundle.main.preferredLocalizations.first == "ja" else {
            return AppL10n.text(english)
        }
        let words = english.split(separator: " ")
        guard words.count > 0, words.count.isMultiple(of: 2) else {
            return AppL10n.text(english)
        }
        var result = ""
        for index in stride(from: 0, to: words.count, by: 2) {
            guard let quantity = Int(words[index]) else { return AppL10n.text(english) }
            let suffix: String
            switch words[index + 1] {
            case "day", "days": suffix = "日"
            case "hour", "hours": suffix = "時間"
            case "minute", "minutes": suffix = "分"
            default: return AppL10n.text(english)
            }
            result += "\(quantity)\(suffix)"
        }
        return result
    }

    private func writeCountdown(_ value: String, centerY: CGFloat) {
        // Right-align all countdowns to the SAME x coordinate as RESETS IN.
        // Only reduce the size if a long localized duration requires it.
        let maxWidth = CGFloat(UsageMenuPresentation.durationRightX -
                               UsageMenuPresentation.durationMinX)
        var size: CGFloat = 10.1
        var font = NSFont.systemFont(ofSize: size, weight: .medium)
        var width = textSize(value, font: font).width
        while width > maxWidth && size > 7.5 {
            size -= 0.4
            font = .systemFont(ofSize: size, weight: .medium)
            width = textSize(value, font: font).width
        }
        writeRightAligned(value, rightX: CGFloat(UsageMenuPresentation.durationRightX),
                          centerY: centerY, font: font, color: .secondaryLabelColor)
    }

    private func textSize(_ value: String, font: NSFont) -> NSSize {
        (value as NSString).size(withAttributes: [.font: font])
    }

    private func writeCentered(_ value: String, atX x: CGFloat, centerY: CGFloat,
                               font: NSFont, color: NSColor) {
        let metrics = textSize(value, font: font)
        write(value, atX: x, y: centerY - metrics.height / 2, font: font, color: color)
    }

    private func writeRightAligned(_ value: String, rightX: CGFloat, centerY: CGFloat,
                                   font: NSFont, color: NSColor) {
        let metrics = textSize(value, font: font)
        write(value, atX: rightX - metrics.width,
              y: centerY - metrics.height / 2, font: font, color: color)
    }

    private func write(_ value: String, atX x: CGFloat, y: CGFloat,
                       font: NSFont, color: NSColor) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: font, .foregroundColor: color
        ])
    }
}
