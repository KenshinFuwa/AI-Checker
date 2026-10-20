#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -emit-library -emit-module -module-name AICheckerCore Sources/AICheckerCore/*.swift \
  -o "$TMP/libAICheckerCore.$([[ "$(uname -s)" == Darwin ]] && echo dylib || echo so)" \
  -emit-module-path "$TMP/AICheckerCore.swiftmodule"
swiftc -I "$TMP" -L "$TMP" -lAICheckerCore \
  Sources/AIChecker/CodexAccountClient.swift Tests/CodexBridgeMockRun.swift \
  -o "$TMP/codex-bridge-mock"
if [[ "$(uname -s)" == Darwin ]]; then
  MOCK_CODEX="$PWD/Tests/mock-codex-app-server.py" DYLD_LIBRARY_PATH="$TMP" "$TMP/codex-bridge-mock"
else
  MOCK_CODEX="$PWD/Tests/mock-codex-app-server.py" LD_LIBRARY_PATH="$TMP" "$TMP/codex-bridge-mock"
fi
