#!/usr/bin/env bash
# Build a macOS Universal 2 executable WITHOUT signing or installing it.
# Caller provides a NEW, absolute output path (outside this repository).
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: macOS required.' >&2; exit 2; }
[[ $# -eq 1 && "$1" == /* ]] || { echo 'USAGE: build-universal-binary.sh /absolute/new/output/AIChecker' >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
OUTPUT="$1"
[[ ! -e "$OUTPUT" ]] || { echo 'ERROR: output already exists; refusing overwrite.' >&2; exit 2; }
[[ -d "$(dirname "$OUTPUT")" ]] || { echo 'ERROR: output parent directory is missing.' >&2; exit 2; }
for tool in swift lipo file mktemp; do
    command -v "$tool" >/dev/null || { echo "ERROR: missing $tool" >&2; exit 2; }
done
TEMP="$(mktemp -d "${TMPDIR:-/tmp/}aichecker-universal.XXXXXXXX")"
cleanup() { rm -rf "$TEMP"; }
trap cleanup EXIT
cd "$ROOT"
for ARCH in arm64 x86_64; do
    BUILD="$TEMP/swiftpm-$ARCH"
    echo "Building AI Checker release slice for $ARCH..."
    swift build --jobs 2 -c release --arch "$ARCH" --scratch-path "$BUILD"
    BIN_DIR="$(swift build --jobs 2 -c release --arch "$ARCH" --scratch-path "$BUILD" --show-bin-path)"
    BIN="$BIN_DIR/AIChecker"
    [[ -s "$BIN" && -x "$BIN" ]] || { echo "ERROR: missing $ARCH release executable." >&2; exit 3; }
    lipo "$BIN" -verify_arch "$ARCH" || { echo "ERROR: incorrect $ARCH executable architecture." >&2; exit 3; }
    cp "$BIN" "$TEMP/AIChecker-$ARCH"
done
# Signing must happen only AFTER combining Mach-O slices.
lipo -create -output "$TEMP/AIChecker" "$TEMP/AIChecker-arm64" "$TEMP/AIChecker-x86_64"
lipo "$TEMP/AIChecker" -verify_arch arm64 x86_64 || { echo 'ERROR: Universal 2 verification failed.' >&2; exit 3; }
file "$TEMP/AIChecker"
chmod 755 "$TEMP/AIChecker"
# One atomic rename, after both architectures have independently succeeded.
[[ ! -e "$OUTPUT" ]] || { echo 'ERROR: output appeared during build; refusing overwrite.' >&2; exit 3; }
mv "$TEMP/AIChecker" "$OUTPUT"
echo "PASS: Universal 2 executable at $OUTPUT (NOT signed, NOT notarized, NOT for public distribution)"
