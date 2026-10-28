#!/usr/bin/env bash
# Runs only the portable source/privacy and Swift core gates.
# The FULL Codex RPC mock and native AppKit build remain macOS PR gates.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/verify-source-manifest.py
for file in scripts/*.sh; do bash -n "$file"; done
python3 Tests/test_public_release.py
python3 Tests/test_distribution_release.py
python3 Tests/test_release_checksum.py
python3 Tests/test_free_preview.py
python3 Tests/test_packaged_bootstrap.py
python3 Tests/test_isolated_e2e_preflight.py
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
swiftc -frontend -parse Sources/AIChecker/*.swift
swift test --jobs 2
echo 'PASS: portable source/core checks (does NOT include native macOS/Codex RPC mock)'
