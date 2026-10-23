#!/usr/bin/env bash
# Stage a Universal 2 app bundle in a NEW location. No signing or installation.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: macOS required.' >&2; exit 2; }
[[ $# -eq 2 && "$1" == /* && "$2" == /* ]] || {
    echo 'USAGE: stage-release-app.sh /absolute/AIChecker /absolute/AI\ Checker.app' >&2; exit 2;
}
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$1"
DEST="$2"
[[ "$(basename "$DEST")" == 'AI Checker.app' ]] || { echo 'ERROR: expected AI Checker.app destination.' >&2; exit 2; }
[[ -f "$BIN" && -x "$BIN" && ! -L "$BIN" ]] || { echo 'ERROR: missing or unsafe executable.' >&2; exit 2; }
[[ ! -e "$DEST" && ! -L "$DEST" ]] || { echo 'ERROR: destination exists, refusing overwrite.' >&2; exit 2; }
[[ -d "$(dirname "$DEST")" ]] || { echo 'ERROR: destination parent missing.' >&2; exit 2; }
for tool in lipo mktemp plutil sips cmp; do command -v "$tool" >/dev/null || { echo "ERROR: missing $tool" >&2; exit 2; }; done
lipo "$BIN" -verify_arch arm64 x86_64
[[ -s "$ROOT/Design/AppIcon.icns" ]] || { echo 'ERROR: icon not found.' >&2; exit 2; }
TMP="$(mktemp -d "$(dirname "$DEST")/.aichecker-stage.XXXXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
APP="$TMP/AI Checker.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AIChecker"
chmod 755 "$APP/Contents/MacOS/AIChecker"
cp "$ROOT/scripts/release/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Design/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Localizations must be in the signed app bundle; a raw SwiftPM executable
# does not establish macOS bundle language negotiation.
for LANGUAGE in en ja; do
    RESOURCE="$ROOT/Localization/$LANGUAGE.lproj/Localizable.strings"
    [[ -s "$RESOURCE" && ! -L "$RESOURCE" ]] || {
        echo "ERROR: missing $LANGUAGE localization." >&2; exit 3;
    }
    plutil -lint "$RESOURCE" >/dev/null
    mkdir -p "$APP/Contents/Resources/$LANGUAGE.lproj"
    cp "$RESOURCE" "$APP/Contents/Resources/$LANGUAGE.lproj/Localizable.strings"
    cmp "$RESOURCE" "$APP/Contents/Resources/$LANGUAGE.lproj/Localizable.strings"
done
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist"
sips -g pixelWidth -g pixelHeight "$APP/Contents/Resources/AppIcon.icns" >/dev/null
cmp "$ROOT/Design/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
lipo "$APP/Contents/MacOS/AIChecker" -verify_arch arm64 x86_64
[[ ! -e "$DEST" && ! -L "$DEST" ]] || { echo 'ERROR: destination appeared during stage.' >&2; exit 3; }
mv "$APP" "$DEST"
echo 'PASS: isolated Universal 2 app bundle staged (NOT signed or distributed).'
