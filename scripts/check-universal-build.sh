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
echo 'PASS: macOS arm64 + x86_64 slices. Artifact removed on exit; no app installation or release.'
