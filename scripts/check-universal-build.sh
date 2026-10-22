#!/usr/bin/env bash
# Non-distributable Universal 2 build gate for maintainers and CI.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: macOS required.' >&2; exit 2; }
cd "$(dirname "$0")/.."
TEMP="$(mktemp -d "${TMPDIR:-/tmp/}aichecker-universal-gate.XXXXXXXX")"
cleanup() { rm -rf "$TEMP"; }
trap cleanup EXIT
bash scripts/build-universal-binary.sh "$TEMP/AIChecker"
lipo "$TEMP/AIChecker" -verify_arch arm64 x86_64
# Exercise the same app-bundle layout as the guarded signed distribution flow.
mkdir -p "$TEMP/dmgroot"
bash scripts/stage-release-app.sh "$TEMP/AIChecker" "$TEMP/dmgroot/AI Checker.app"
ln -s /Applications "$TEMP/dmgroot/Applications"
hdiutil create -quiet -volname 'AI Checker QA' -srcfolder "$TEMP/dmgroot" -format UDZO "$TEMP/layout-test.dmg"
bash scripts/audit-release-dmg.sh --unsigned-preflight "$TEMP/layout-test.dmg"
echo 'PASS: macOS arm64 + x86_64, staged bundle and read-only DMG audit. Artifact removed on exit; no app installation or release.'
