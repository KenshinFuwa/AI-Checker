import Foundation
import AICheckerCore

struct SourceOutcome {
    let snapshots: [String: AIQuotaSnapshot]
    let errors: [String]
}

protocol AIUsageSource {
    var sourceID: String { get }
    func fetch() -> SourceOutcome
}

enum ClaudeStatusLineStore {
    static var legacyURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AI Checker", isDirectory: true)
            .appendingPathComponent("claude-quota.json")
    }

    static func importStatusLine(_ data: Data, profileID: UUID?) -> Bool {
        let target = profileID.map { ClaudeProfileClient.quota($0) } ?? legacyURL
        guard data.count <= 256 * 1024,
              let snapshot = NativeQuotaDecoder.claudeStatusLine(data),
              let bytes = try? JSONEncoder().encode(SanitizedClaudeQuota(snapshot)) else { return false }
        do {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: target, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            return true
        } catch { return false }
    }

    static func read(profileID: UUID) -> AIQuotaSnapshot? {
        let target = ClaudeProfileClient.quota(profileID)
        guard let data = try? Data(contentsOf: target), data.count <= 2048,
              let saved = try? JSONDecoder().decode(SanitizedClaudeQuota.self, from: data) else { return nil }
        return saved.snapshot()
    }
}

struct ClaudeStatusLineSource: AIUsageSource {
    let profileID: UUID
    let sourceID = "claude-first-party-statusline"
    func fetch() -> SourceOutcome {
        guard let snapshot = ClaudeStatusLineStore.read(profileID: profileID) else {
            return SourceOutcome(snapshots: [:], errors: ["Claude: 公式statusLineから使用率が届いていません（Claude Code連携は任意）。"])
        }
        return SourceOutcome(snapshots: ["claude": snapshot], errors: [])
    }
}

struct UsagePipeline {
    let sources: [any AIUsageSource]
    func fetch() -> SourceOutcome {
        let results = sources.map { $0.fetch() }
        return SourceOutcome(snapshots: ProviderMerge.merge(results.map(\.snapshots)),
                             errors: results.flatMap(\.errors))
    }
}
