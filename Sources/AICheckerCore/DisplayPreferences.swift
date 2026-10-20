import Foundation

public enum ProviderSelection: String, Codable, CaseIterable, Sendable {
    case both
    case codex
    case claude

    public var providers: [QuotaProvider] {
        switch self {
        case .both: return [.codex, .claude]
        case .codex: return [.codex]
        case .claude: return [.claude]
        }
    }
}

public enum NameStyle: String, Codable, CaseIterable, Sendable {
    case full
    case short
    case icon
}

public enum BarSize: String, Codable, CaseIterable, Sendable {
    case compact
    case standard
    case wide

    public var width: Double {
        switch self {
        case .compact: return 45
        case .standard: return 66
        case .wide: return 90
        }
    }
}

public enum MetricStyle: String, Codable, CaseIterable, Sendable {
    case barsAndPercent
    case barsOnly
    case percentOnly

    public var showBars: Bool { self != .percentOnly }
    public var showPercent: Bool { self != .barsOnly }
}

public enum TintStyle: String, Codable, CaseIterable, Sendable {
    case original
    case aqua
    case violet
    case gold
    case rose
}

public struct DisplayPreferences: Equatable, Codable, Sendable {
    public var selection: ProviderSelection
    public var nameStyle: NameStyle
    public var barSize: BarSize
    public var metricStyle: MetricStyle
    public var codexTint: TintStyle
    public var claudeTint: TintStyle

    public init(selection: ProviderSelection = .both,
                nameStyle: NameStyle = .full,
                barSize: BarSize = .standard,
                metricStyle: MetricStyle = .barsAndPercent,
                codexTint: TintStyle = .original,
                claudeTint: TintStyle = .original) {
        self.selection = selection
        self.nameStyle = nameStyle
        self.barSize = barSize
        self.metricStyle = metricStyle
        self.codexTint = codexTint
        self.claudeTint = claudeTint
    }
}

// A new versioned settings layer; legacy MenuPilot DisplayPreferences stays
// decodable for preference migration. Unknown providers are opt-in.
public struct AICheckerSettings: Equatable, Codable, Sendable {
    public var visibleProviderIDs: [String]
    public var nameStyle: NameStyle
    public var barSize: BarSize
    public var metricStyle: MetricStyle
    public var tints: [String: TintStyle]
    public var providerGap: Double

    public init(visibleProviderIDs: [String] = ["codex", "claude"],
                nameStyle: NameStyle = .full, barSize: BarSize = .standard,
                metricStyle: MetricStyle = .barsAndPercent,
                tints: [String: TintStyle] = [:], providerGap: Double = CompactLayout.providerGap) {
        self.visibleProviderIDs = visibleProviderIDs
        self.nameStyle = nameStyle
        self.barSize = barSize
        self.metricStyle = metricStyle
        self.tints = tints
        self.providerGap = providerGap
    }

    public static func migrated(from old: DisplayPreferences) -> AICheckerSettings {
        AICheckerSettings(visibleProviderIDs: old.selection.providers.map(\.rawValue),
                          nameStyle: old.nameStyle, barSize: old.barSize,
                          metricStyle: old.metricStyle,
                          tints: ["codex": old.codexTint, "claude": old.claudeTint])
    }

    public func visibleProviders(in catalog: [AIProviderDescriptor]) -> [AIProviderDescriptor] {
        let known = Set(visibleProviderIDs)
        return catalog.filter { known.contains($0.id) }
    }

    public mutating func setVisible(_ id: String, _ value: Bool) {
        if value {
            if !visibleProviderIDs.contains(id) { visibleProviderIDs.append(id) }
        } else {
            visibleProviderIDs.removeAll { $0 == id }
        }
    }

    public mutating func setGap(_ requested: Double) {
        providerGap = requested.isFinite ? max(0, min(12, requested)) : CompactLayout.providerGap
    }
}
