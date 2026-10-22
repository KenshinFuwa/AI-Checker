#!/bin/bash
# Read-only diagnosis. Does not change macOS Spotlight databases or the app.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS required'; exit 1; }
APP="${1:-/Applications/AI Checker.app}"
[[ -d "$APP/Contents" ]] || { echo "BUNDLE_MISSING: $APP"; exit 2; }
P="$APP/Contents/Info.plist"
echo "BUNDLE_PATH: $APP"
for KEY in CFBundleIdentifier CFBundleDisplayName CFBundleIconFile CFBundlePackageType LSUIElement; do
    VALUE="$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$P" 2>/dev/null || true)"
    echo "$KEY: ${VALUE:-MISSING}"
done
codesign --verify --strict "$APP" && echo 'SIGNATURE: VALID'
ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$P" 2>/dev/null || true)"
if [[ -n "$ICON_NAME" && -s "$APP/Contents/Resources/$ICON_NAME" ]]; then
    echo 'ICON_RESOURCE: PRESENT'
    sips -g pixelWidth -g pixelHeight "$APP/Contents/Resources/$ICON_NAME" 2>/dev/null || true
else
    echo 'ICON_RESOURCE: MISSING_OR_NAME_MISMATCH'
fi
LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
if [[ -x "$LSREGISTER" ]]; then
    # Registration check via the public NSWorkspace API below, not repeated LS DB resets.
    :
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo '=== AppKit / Launch Services icon resolution ==='
if command -v swift >/dev/null 2>&1; then
    swift "$SCRIPT_DIR/inspect-app-identity.swift" "$APP" || echo 'APPKIT_INSPECTION: UNAVAILABLE'
else
    echo 'APPKIT_INSPECTION: SWIFT_UNAVAILABLE'
fi
echo '=== Spotlight indexing comparison ==='
mdutil -s / || true
for CANDIDATE in "$APP" '/System/Applications/TextEdit.app' '/System/Applications/Safari.app'; do
    if [[ -d "$CANDIDATE" ]]; then
        RAW="$(mdls -raw -name kMDItemContentType "$CANDIDATE" 2>/dev/null || true)"
        echo "MDLS_CONTENT_TYPE [$CANDIDATE]: ${RAW:-NOT_INDEXED}"
    fi
done
FOUND="$(mdfind 'kMDItemCFBundleIdentifier == "dev.aichecker.localapp"' 2>/dev/null || true)"
if printf '%s\n' "$FOUND" | grep -Fxq "$APP"; then
    echo 'SPOTLIGHT_METADATA_MATCH: YES'
else
    echo 'SPOTLIGHT_METADATA_MATCH: NOT_CONFIRMED'
fi
# A missing Spotlight index for other Apple apps strongly indicates an OS-side
# index/search configuration issue, not a bundle-resource packaging issue.
echo 'Spotlight UI search remains an independent final check.'
