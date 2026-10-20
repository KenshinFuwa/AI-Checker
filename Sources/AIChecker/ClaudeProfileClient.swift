import AppKit
import Foundation
import AICheckerCore

/// A Claude profile is an OFFICIAL Claude Code configuration directory, not a
/// third-party subscription OAuth implementation. No credentials are inspected.
enum ClaudeProfileClient {
    static func root(_ id: UUID) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AI Checker/ClaudeAccounts", isDirectory: true)
            .appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    static func config(_ id: UUID) -> URL { root(id).appendingPathComponent("config", isDirectory: true) }
    static func quota(_ id: UUID) -> URL { root(id).appendingPathComponent("quota.json") }

    /// Quote for a shell script whose arguments contain controlled UUID/path only.
    private static func shquote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Filesystem protection: never overwrite unexpected paths or follow profile symlinks.
    static func prepare(_ account: AICheckerAccount, executable: URL) throws -> URL {
        guard account.providerID == "claude" else { throw Error.invalidAccount }
        let fs = FileManager.default
        let dir = root(account.id)
        if fs.fileExists(atPath: dir.path) {
            let attrs = try fs.attributesOfItem(atPath: dir.path)
            guard attrs[.type] as? FileAttributeType == .typeDirectory else { throw Error.unsafePath }
        } else {
            try fs.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let configDir = config(account.id)
        if fs.fileExists(atPath: configDir.path) {
            let attrs = try fs.attributesOfItem(atPath: configDir.path)
            guard attrs[.type] as? FileAttributeType == .typeDirectory else { throw Error.unsafePath }
        } else {
            try fs.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let settings = configDir.appendingPathComponent("settings.json")
        let command = "\(shquote(executable.path)) --ingest-claude-statusline --profile \(account.id.uuidString.lowercased())"
        if fs.fileExists(atPath: settings.path) {
            let attrs = try fs.attributesOfItem(atPath: settings.path)
            guard attrs[.type] as? FileAttributeType == .typeRegular,
                  let bytes = try? Data(contentsOf: settings), bytes.count < 1024 * 1024,
                  let dictionary = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  let status = dictionary["statusLine"] as? [String: Any],
                  status["type"] as? String == "command", status["command"] as? String == command else {
                // Existing user customizations are NOT silently replaced.
                throw Error.existingSettings
            }
        } else {
            let content: [String: Any] = ["statusLine": ["type": "command", "command": command]]
            let bytes = try JSONSerialization.data(withJSONObject: content, options: [.prettyPrinted, .sortedKeys])
            try bytes.write(to: settings, options: [.atomic])
            try fs.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)
        }
        let connector = dir.appendingPathComponent("connect.command")
        // This is ONLY a manual interactive first-party Claude Code session.
        // Inherited API credentials could divert requests to paid Console API.
        let script = """
        #!/bin/zsh
        set -eu
        unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_BASE_URL
        unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
        export CLAUDE_CONFIG_DIR=\(shquote(configDir.path))
        echo 'AI Checker: dedicated Claude Code session. Verify the account with /status.'
        if command -v claude >/dev/null 2>&1; then
          exec claude
        fi
        echo 'Claude Code CLI was not found. Install the official Claude Code and retry.'
        read -k 1 '?Press any key to close...'
        exit 127
        """
        if fs.fileExists(atPath: connector.path) {
            let attrs = try fs.attributesOfItem(atPath: connector.path)
            guard attrs[.type] as? FileAttributeType == .typeRegular else { throw Error.unsafePath }
        }
        try Data((script + "\n").utf8).write(to: connector, options: [.atomic])
        try fs.setAttributes([.posixPermissions: 0o700], ofItemAtPath: connector.path)
        return connector
    }

    enum Error: Swift.Error, LocalizedError {
        case invalidAccount, existingSettings, unsafePath
        var errorDescription: String? {
            switch self {
            case .invalidAccount: return "Claudeのプロフィールではありません。"
            case .existingSettings: return "専用Claude設定に既存のstatusLineがあります。上書きはしません。設定を確認してください。"
            case .unsafePath: return "設定先が通常のディレクトリ／ファイルではありません。安全のため停止しました。"
            }
        }
    }
}
