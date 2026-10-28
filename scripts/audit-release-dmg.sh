#!/usr/bin/env bash
# Inspect DMG contents read-only. Never install or modify /Applications.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: macOS required.' >&2; exit 2; }
[[ $# -eq 2 && ( "$1" == --unsigned-preflight || "$1" == --signed-release ) ]] || {
    echo 'USAGE: audit-release-dmg.sh --unsigned-preflight|--signed-release /absolute/path.dmg' >&2; exit 2;
}
MODE="$1"
DMG="$2"
[[ "$DMG" == /* && -f "$DMG" && ! -L "$DMG" ]] || { echo 'ERROR: DMG must be a local absolute regular file.' >&2; exit 2; }
for tool in hdiutil lipo codesign python3 mktemp; do command -v "$tool" >/dev/null || { echo "ERROR: missing $tool" >&2; exit 2; }; done
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
hdiutil verify "$DMG" >/dev/null
TMP="$(mktemp -d "${TMPDIR:-/tmp/}aichecker-dmg-audit.XXXXXXXX")"
MOUNT="$TMP/volume"
mkdir -p "$MOUNT"
MOUNTED=0
cleanup() {
    if [[ "$MOUNTED" -eq 1 ]]; then
        hdiutil detach -quiet "$MOUNT" || echo 'WARNING: DMG audit volume could not be detached.' >&2
    fi
    rmdir "$MOUNT" 2>/dev/null || true
    rmdir "$TMP" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$MOUNT" "$DMG"
MOUNTED=1
APP="$MOUNT/AI Checker.app"
[[ -d "$APP" && ! -L "$APP" ]] || { echo 'ERROR: AI Checker.app missing from DMG.' >&2; exit 3; }
[[ -L "$MOUNT/Applications" && "$(readlink "$MOUNT/Applications")" == /Applications ]] || {
    echo 'ERROR: expected Applications shortcut is missing or incorrect.' >&2; exit 3;
}
[[ "$(find "$MOUNT" -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')" == 1 ]] || {
    echo 'ERROR: unexpected app bundles found at DMG root.' >&2; exit 3;
}
EXE="$APP/Contents/MacOS/AIChecker"
[[ -f "$EXE" && -x "$EXE" && ! -L "$EXE" ]] || { echo 'ERROR: expected executable is missing.' >&2; exit 3; }
[[ -s "$APP/Contents/Resources/AppIcon.icns" ]] || { echo 'ERROR: AppIcon.icns missing.' >&2; exit 3; }
cmp "$ROOT/Design/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns" || {
    echo 'ERROR: packaged app icon differs from audited source.' >&2; exit 3;
}
for LANGUAGE in en ja; do
    RESOURCE="$APP/Contents/Resources/$LANGUAGE.lproj/Localizable.strings"
    [[ -f "$RESOURCE" && ! -L "$RESOURCE" ]] || {
        echo "ERROR: missing bundled $LANGUAGE localization." >&2; exit 3;
    }
    plutil -lint "$RESOURCE" >/dev/null
    cmp "$ROOT/Localization/$LANGUAGE.lproj/Localizable.strings" "$RESOURCE" || {
        echo "ERROR: $LANGUAGE bundle translation mismatch." >&2; exit 3;
    }
done
python3 - "$APP/Contents/Info.plist" "$APP/Contents/PkgInfo" <<'PYPLIST'
import plistlib,sys,pathlib
p=pathlib.Path(sys.argv[1])
info=plistlib.loads(p.read_bytes())
expected={
    'CFBundleIdentifier':'dev.aichecker.localapp',
    'CFBundleExecutable':'AIChecker',
    'CFBundleShortVersionString':'1.10.1',
    'CFBundleIconFile':'AppIcon.icns',
    'CFBundlePackageType':'APPL',
    'CFBundleDevelopmentRegion':'en',
    'CFBundleLocalizations':['en','ja'],
    'LSUIElement':True,
}
for k,v in expected.items():
    if info.get(k)!=v:
        raise SystemExit(f'ERROR: bundle Info.plist mismatch: {k}')
if pathlib.Path(sys.argv[2]).read_bytes()!=b'APPL????':
    raise SystemExit('ERROR: invalid PkgInfo')
print('PASS: DMG metadata, identity and icon')
PYPLIST
lipo "$EXE" -verify_arch arm64 x86_64
# CI-only, packaged executable AppKit bootstrap. Never install or start a
# normal account-connected app. The smoke switch is NOT an actual first-run,
# Gatekeeper/quarantine, notification or Intel-hardware validation.
if [[ "${AI_CHECKER_CI_BOOTSTRAP:-0}" == "1" ]]; then
    [[ "$MODE" == --unsigned-preflight ]] || {
        echo 'ERROR: packaged bootstrap is restricted to unsigned CI preflight.' >&2
        exit 3
    }
    "$EXE" --selftest-packaged-bootstrap
    # Language is selected only for these short-lived test processes; no persistent preferences or app installation.
    "$EXE" -AppleLanguages "(en)" --selftest-packaged-bootstrap --selftest-language en
    "$EXE" -AppleLanguages "(ja)" --selftest-packaged-bootstrap --selftest-language ja
fi
if [[ "$MODE" == --signed-release ]]; then
    codesign --verify --strict --verbose=2 "$APP"
    DETAILS="$(codesign -dv --verbose=4 "$APP" 2>&1)"
    grep -F 'Authority=Developer ID Application:' <<< "$DETAILS" >/dev/null || {
        echo 'ERROR: missing Developer ID Application authority.' >&2; exit 3;
    }
    grep -E '^TeamIdentifier=[A-Z0-9]+' <<< "$DETAILS" >/dev/null || {
        echo 'ERROR: missing TeamIdentifier.' >&2; exit 3;
    }
    grep -E '^flags=.*\(runtime\)' <<< "$DETAILS" >/dev/null || {
        echo 'ERROR: Hardened Runtime flag missing.' >&2; exit 3;
    }
    xcrun stapler validate -v "$DMG"
    echo 'PASS: signed and stapled DMG gate (not a second-Mac Gatekeeper test).'
else
    echo 'PASS: unsigned local DMG layout audit; DO NOT DISTRIBUTE.'
fi
