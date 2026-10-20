import Foundation

/// Descriptors have no credentials. Codex owns CODEX_HOME; Claude Code owns CLAUDE_CONFIG_DIR.
public struct AICheckerAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let providerID: String
    public var label: String
    public init(id: UUID = UUID(), providerID: String, label: String) {
        self.id = id
        self.providerID = providerID
        self.label = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
    }
}

public struct AccountConfiguration: Codable, Equatable, Sendable {
    public static let schema = 1 // Keep v1.3 settings fully compatible.
    public var version: Int
    public private(set) var accounts: [AICheckerAccount]
    public private(set) var activeCodexID: UUID?
    public private(set) var activeClaudeID: UUID?

    public init() { version = Self.schema; accounts = []; activeCodexID = nil; activeClaudeID = nil }

    private enum CodingKeys: String, CodingKey { case version, accounts, activeCodexID, activeClaudeID }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        accounts = try container.decode([AICheckerAccount].self, forKey: .accounts)
        activeCodexID = try container.decodeIfPresent(UUID.self, forKey: .activeCodexID)
        activeClaudeID = try container.decodeIfPresent(UUID.self, forKey: .activeClaudeID)
    }

    @discardableResult
    public mutating func add(provider: String, label: String) -> AICheckerAccount? {
        guard ["codex", "claude"].contains(provider),
              accounts.filter({ $0.providerID == provider }).count < 8 else { return nil }
        let proposed = label.isEmpty ? "\(provider == "codex" ? "Codex" : "Claude") \(accounts.filter { $0.providerID == provider }.count + 1)" : label
        let candidate = AICheckerAccount(providerID: provider, label: proposed)
        guard !candidate.label.isEmpty else { return nil }
        accounts.append(candidate)
        if provider == "codex" && activeCodexID == nil { activeCodexID = candidate.id }
        if provider == "claude" && activeClaudeID == nil { activeClaudeID = candidate.id }
        return candidate
    }

    public mutating func addCodex(label: String) -> AICheckerAccount? { add(provider: "codex", label: label) }
    public mutating func addClaude(label: String) -> AICheckerAccount? { add(provider: "claude", label: label) }

    @discardableResult
    public mutating func selectCodex(_ id: UUID) -> Bool { select(id, provider: "codex") }
    @discardableResult
    public mutating func selectClaude(_ id: UUID) -> Bool { select(id, provider: "claude") }

    private mutating func select(_ id: UUID, provider: String) -> Bool {
        guard accounts.contains(where: { $0.id == id && $0.providerID == provider }) else { return false }
        if provider == "codex" { activeCodexID = id } else { activeClaudeID = id }
        return true
    }

    @discardableResult public mutating func rename(_ id: UUID, to label: String) -> Bool {
        let trimmed = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
        guard !trimmed.isEmpty, let index = accounts.firstIndex(where: { $0.id == id }) else { return false }
        accounts[index].label = trimmed
        return true
    }

    @discardableResult public mutating func remove(_ id: UUID) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return false }
        let provider = accounts[index].providerID
        accounts.remove(at: index)
        if provider == "codex" && activeCodexID == id {
            activeCodexID = accounts.first(where: { $0.providerID == "codex" })?.id
        }
        if provider == "claude" && activeClaudeID == id {
            activeClaudeID = accounts.first(where: { $0.providerID == "claude" })?.id
        }
        return true
    }

    public var activeCodex: AICheckerAccount? {
        accounts.first(where: { $0.id == activeCodexID && $0.providerID == "codex" })
    }
    public var activeClaude: AICheckerAccount? {
        accounts.first(where: { $0.id == activeClaudeID && $0.providerID == "claude" })
    }

    public static func decodeSafely(_ data: Data) -> AccountConfiguration? {
        guard let config = try? JSONDecoder().decode(Self.self, from: data), config.version == schema,
              config.accounts.count <= 16,
              Set(config.accounts.map(\.id)).count == config.accounts.count,
              config.accounts.allSatisfy({ ["codex", "claude"].contains($0.providerID) && !$0.label.isEmpty && $0.label.count <= 48 }),
              config.accounts.filter({ $0.providerID == "codex" }).count <= 8,
              config.accounts.filter({ $0.providerID == "claude" }).count <= 8,
              config.activeCodexID == nil || config.activeCodex != nil,
              config.activeClaudeID == nil || config.activeClaude != nil else { return nil }
        return config
    }
}

/// The app server returns the complete server-side snapshot. Never assume primary == five hours.
public enum CodexAppServerQuotaDecoder {
    private static func numeric(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber else { return nil }
        let result = value.doubleValue
        return result.isFinite ? result : nil
    }
    private static func window(_ items: [[String: Any]], expectedMinutes: Double, now: Date) -> QuotaWindow {
        for object in items {
            guard let duration = numeric(object["windowDurationMins"]), abs(duration - expectedMinutes) <= 2 else { continue }
            let reset = numeric(object["resetsAt"]).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            guard let used = numeric(object["usedPercent"]), (0...100).contains(used),
                  let future = reset, future > now else { continue }
            return QuotaWindow(remainingPercent: 100 - used, resetsAt: future)
        }
        return QuotaWindow(remainingPercent: nil, resetsAt: nil)
    }
    public static func decodeResult(_ result: [String: Any], now: Date = Date()) -> AIQuotaSnapshot? {
        let selected: [String: Any]?
        if let map = result["rateLimitsByLimitId"] as? [String: Any] {
            selected = map["codex"] as? [String: Any]
        } else if let single = result["rateLimits"] as? [String: Any],
                  (single["limitId"] as? String).map({ $0 == "codex" }) ?? true {
            selected = single
        } else { selected = nil }
        guard let rate = selected else { return nil }
        let windows = [rate["primary"], rate["secondary"]].compactMap { $0 as? [String: Any] }
        let five = window(windows, expectedMinutes: 300, now: now)
        let week = window(windows, expectedMinutes: 10080, now: now)
        guard five.remainingPercent != nil || week.remainingPercent != nil else { return nil }
        return AIQuotaSnapshot(providerID: "codex", fiveHour: five, weekly: week,
                               updatedAt: now, source: "Codex App Server (isolated account)")
    }
}
