#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# SwiftPM treats unknown files under Sources as unhandled resources.
python3 - <<'PYSOURCE'
from pathlib import Path
junk = [p.as_posix() for p in Path('Sources').rglob('*')
        if p.is_file() and p.suffix.lower() in {'.orig', '.bak', '.swp', '.tmp'}]
assert not junk, f'Unexpected editor backup files in SwiftPM source tree: {junk}'
source = Path('Sources/AIChecker/GlobalUsageHotkey.swift').read_text()
assert 'MemoryLayout<EventHotKeyID>.size, nil, &received)' in source
assert 'UInt32(MemoryLayout<EventHotKeyID>.size)' not in source
print('PASS: Carbon GetEventParameter size type and source hygiene')
PYSOURCE
for file in scripts/*.sh; do bash -n "$file"; done
python3 - <<'PY'
from pathlib import Path
main = Path('Sources/AIChecker/main.swift').read_text()
art = Path('Sources/AIChecker/StatusArtwork.swift').read_text()
installer = Path('scripts/install-local.sh').read_text()
launch = Path('scripts/launch.sh').read_text()
cleanup = Path('scripts/cleanup-legacy.sh').read_text()
checks = {
    'new app identity': 'dev.aichecker.localapp' in installer and 'AI Checker.app' in installer,
    'no menu-bar icon hiding code': 'NativeMenuBarTrial' not in main and 'MenuBarDiscovery' not in main,
    'no AX requirements or requests': not any(s in main for s in ['AXIsProcessTrusted', 'requestAuthorization', 'AXUIElement', 'Accessibility']),
    'no synthetic mouse events': not any(s in main for s in ['CGEvent', 'AXUIElementSetAttributeValue']),
    'no hardcoded 160pt provider cells': '160' not in art and 'measure(' in art,
    'bitmap starts at zero': 'var cursor: CGFloat = 0' in art,
    'no generated launch agents': not any(s in installer for s in ['launchctl', 'LaunchAgents']),
    'launch is read-only': not any(s in launch for s in ['swift build', 'codesign', 'tccutil', 'security ']),
    'no active global BTM reset': not any(line.strip().startswith(('sfltool resetbtm', 'tccutil reset')) for line in cleanup.splitlines()),
    'new app executable': 'AIChecker' in Path('Package.swift').read_text(),
    'SMAppService login main app': 'SMAppService.mainApp.register()' in main and 'ServiceManagement' in main and 'SMAppService.mainApp' in main,
    'one coalesced timer': 'timer.tolerance = RefreshPolicy.timerTolerance' in main and 'Timer.scheduledTimer(timeInterval: 10' not in main,
    'stop on sleep and refresh after wake': 'NSWorkspace.willSleepNotification' in main and 'NSWorkspace.didWakeNotification' in main and 'stopRefreshTimer()' in main,
    'change-based artwork': 'lastDisplayKey' in main and 'if currentKey != lastDisplayKey' in main,
    'no AX permission required': 'AXIsProcessTrusted' not in main,
    'CodexBar CLI removed': not any('CodexBar' in f.read_text() for f in Path('Sources/AIChecker').glob('*.swift')),
    'isolated official codex account source': 'connectSelectedAccount()' in main and 'ClaudeStatusLineSource(profileID: profileID)' in main and 'NativeCodexSessionSource()' not in main.split('if CommandLine.arguments.contains')[0],
    'dedicated Codex profile directories': 'CODEX_HOME' in Path('Sources/AIChecker/CodexAccountClient.swift').read_text() and 'CodexAccounts' in Path('Sources/AIChecker/CodexAccountClient.swift').read_text(),
    'login via official app server': 'account/login/start' in Path('Sources/AIChecker/CodexAccountClient.swift').read_text(),
    'no account token persistence in AI Checker': not any(token in Path('Sources/AIChecker/main.swift').read_text() for token in ['auth.json', 'access_token', 'refresh_token']),
    'optional Claude statusline helper': '--ingest-claude-statusline' in main,
    'no default codex session read': 'NativeCodexSessionSource' not in Path('Sources/AIChecker/AIUsageSource.swift').read_text() and '--probe-native' not in main,
    'Claude secret-free cache': 'SanitizedClaudeQuota' in Path('Sources/AIChecker/AIUsageSource.swift').read_text(),
    'separate official Claude Code profiles': 'CLAUDE_CONFIG_DIR' in Path('Sources/AIChecker/ClaudeProfileClient.swift').read_text() and 'activeClaudeID' in Path('Sources/AICheckerCore/AccountProfiles.swift').read_text(),
    'no global Claude settings mutation': not any('.claude/settings.json' in f.read_text() for f in Path('scripts').glob('*.sh') if f.name != 'check.sh'),
    'no Claude private OAuth reuse': not any(token in Path('Sources/AIChecker/ClaudeProfileClient.swift').read_text() for token in ['.credentials.json', 'oauthAccount', 'sessionKey']),
    'Claude statusLine bound to profile': 'ClaudeStatusLineSource(profileID: profileID)' in main and '--profile' in main,
    'Codex profile unaffected': 'Codexアカウント管理' in main and 'connectSelectedAccount()' in main,
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if not all(checks.values()): raise SystemExit(1)
PY
python3 - <<'PYVALIDATE'
from pathlib import Path
p = Path('Sources/AIChecker/ClaudeWebSession.swift').read_text()
m = Path('Sources/AIChecker/main.swift').read_text()
assert "return false" in m.split('private func claudeWebEnabled(', 1)[1].split('private func configureClaudeWebSession()',1)[0]
assert 'func poll(force: Bool = false) { /* Deliberately no network requests. */ }' in p
assert 'callAsyncJavaScript' not in p and "fetch('/api/organizations'" not in p
assert 'Claude専用ブラウザでログイン…' not in m
print('PASS: public Claude Web network access disabled; CLI statusLine retained')
PYVALIDATE
python3 Tests/test_public_release.py
python3 Tests/test_distribution_release.py
python3 Tests/test_release_checksum.py
python3 Tests/test_free_preview.py
python3 Tests/test_packaged_bootstrap.py
python3 Tests/test_release_invariants.py
python3 Tests/test_consumer_web_integration.py
python3 Tests/test_quota_notifications_integration.py
python3 Tests/test_live_settings_preview.py
python3 Tests/test_menu_bar_fallback.py
python3 Tests/test_spotlight_reopen.py
python3 Tests/test_network_speed_and_spotlight.py
python3 Tests/test_notification_diagnostics.py
python3 Tests/test_menu_bar_provider_selection.py
python3 Tests/test_installer_offline.py
python3 Tests/test_app_discovery_and_icon.py
# Parsing verifies syntax on Linux; native AppKit/WebKit type-check requires macOS.
swiftc -frontend -parse Sources/AIChecker/*.swift
swift test --jobs 2
bash scripts/test-codex-bridge.sh
if [[ "$(uname -s)" == Darwin ]]; then
    swift build --jobs 2 -c release
    "$(swift build -c release --show-bin-path)/AIChecker" --selftest-claude-profile
    "$(swift build -c release --show-bin-path)/AIChecker" --selftest-status-layout
    "$(swift build -c release --show-bin-path)/AIChecker" --selftest-quick-access-layout
    bash scripts/test-claude-telemetry.sh
fi
