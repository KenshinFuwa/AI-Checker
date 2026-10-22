#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# The mock is launched via Foundation.Process (not python3 directly).
# Give the isolated temporary copy an executable bit even when an archive
# extraction or filesystem did not retain the source script mode.
MOCK="$TMP/mock-codex-app-server.py"
cp Tests/mock-codex-app-server.py "$MOCK"
chmod 700 "$MOCK"
swiftc -emit-library -emit-module -module-name AICheckerCore Sources/AICheckerCore/*.swift \
  -o "$TMP/libAICheckerCore.$([[ "$(uname -s)" == Darwin ]] && echo dylib || echo so)" \
  -emit-module-path "$TMP/AICheckerCore.swiftmodule"
swiftc -I "$TMP" -L "$TMP" -lAICheckerCore \
  Sources/AIChecker/CodexAccountClient.swift Tests/CodexBridgeMockRun.swift \
  -o "$TMP/codex-bridge-mock"
if [[ "$(uname -s)" == Darwin ]]; then
  MOCK_CODEX="$MOCK" DYLD_LIBRARY_PATH="$TMP" "$TMP/codex-bridge-mock"
else
  MOCK_CODEX="$MOCK" LD_LIBRARY_PATH="$TMP" "$TMP/codex-bridge-mock"
fi
