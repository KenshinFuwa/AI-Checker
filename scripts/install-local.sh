#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then echo 'This installer requires macOS.' >&2; exit 1; fi
cd "$(dirname "$0")/.."
ROOT="$PWD"
SIGN_FILE="$HOME/.config/menupilot/signing-identity.txt"
IDENTITY="${AI_CHECKER_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" && -s "$SIGN_FILE" ]]; then IFS= read -r IDENTITY < "$SIGN_FILE"; fi
if [[ -z "$IDENTITY" || "$IDENTITY" == '-' ]]; then
    echo 'ERROR: stable signing identity missing. Existing MenuPilot certificate can be reused.' >&2
    echo 'Run: security find-identity -v -p codesigning' >&2
    echo 'Set AI_CHECKER_SIGN_IDENTITY=<SHA1> if an existing valid identity is available.' >&2
    exit 2
fi
if ! security find-identity -v -p codesigning | grep -Fq "$IDENTITY"; then
    echo "ERROR: signing identity not in Keychain: $IDENTITY" >&2; exit 2
fi
DEST="$HOME/Applications/AI Checker.app"
STAGE="$HOME/Applications/.AI-Checker-stage.$$.app"
BACKUP="$HOME/Applications/AI Checker.previous.app"
mkdir -p "$HOME/Applications"
if [[ -e "$STAGE" ]]; then echo "Staging path already exists: $STAGE" >&2; exit 3; fi
cleanup() { if [[ -d "$STAGE" ]]; then rm -rf "$STAGE"; fi; }
trap cleanup EXIT
swift build --jobs 2 -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
mkdir -p "$STAGE/Contents/MacOS"
cp "$BIN_DIR/AIChecker" "$STAGE/Contents/MacOS/AIChecker"
chmod 755 "$STAGE/Contents/MacOS/AIChecker"
# Third-party logos are not distributed in the public source archive.
# ProviderIconArtwork uses built-in Swift vector fallbacks if PNGs are absent.
# A user's independently licensed local assets may optionally be bundled.
if [[ -d "$ROOT/Sources/AIChecker/Assets" ]]; then
    mkdir -p "$STAGE/Contents/Resources"
    for icon in codex claude; do
        if [[ -s "$ROOT/Sources/AIChecker/Assets/$icon.png" ]]; then
            cp "$ROOT/Sources/AIChecker/Assets/$icon.png" "$STAGE/Contents/Resources/$icon.png"
        fi
    done
fi
cat > "$STAGE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AIChecker</string>
<key>CFBundleIdentifier</key><string>dev.aichecker.localapp</string>
<key>CFBundleName</key><string>AI Checker</string>
<key>CFBundleDisplayName</key><string>AI Checker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.9.2</string>
<key>CFBundleVersion</key><string>192</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$STAGE/Contents/Info.plist"
codesign --force --sign "$IDENTITY" --timestamp=none "$STAGE"
codesign --verify --strict --verbose=2 "$STAGE"
get_req() { codesign --display --requirements - "$1" 2>&1 | sed -n 's/^designated => //p' | head -n 1; }
NEW_REQ="$(get_req "$STAGE")"
[[ -n "$NEW_REQ" ]] || { echo 'ERROR: new app has no designated requirement' >&2; exit 3; }
if [[ -d "$DEST" ]]; then
    OLD_REQ="$(get_req "$DEST")"
    [[ "$OLD_REQ" == "$NEW_REQ" ]] || { echo 'ERROR: existing AI Checker has different signing identity. Not replacing it.' >&2; exit 3; }
fi
# IMPORTANT: Finish building, signing, verifying and checking bundle identity
# *before* shutting down a running app. Never terminate unrelated AI Checker
# development copies (or other programs) using a wildcard pkill.
running_installed_app_pids() {
    local pid command
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        if [[ "$command" == "$DEST/Contents/MacOS/AIChecker"* ]]; then
            printf '%s\n' "$pid"
        fi
    done < <(pgrep -x AIChecker || true)
}

RUNNING_PIDS="$(running_installed_app_pids)"
if [[ -n "$RUNNING_PIDS" ]]; then
    echo 'Closing the installed AI Checker after successful staged signing...'
    while IFS= read -r pid; do
        [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
    done <<< "$RUNNING_PIDS"
    # Do not force-kill: abort without replacing if a process refuses to stop.
    for attempt in {1..80}; do
        [[ -z "$(running_installed_app_pids)" ]] && break
        sleep 0.1
    done
    if [[ -n "$(running_installed_app_pids)" ]]; then
        echo 'ERROR: Installed AI Checker did not exit; original app remains unchanged.' >&2
        exit 3
    fi
fi
# Stop rather than overwrite if a separate copy is still running.
if pgrep -x AIChecker >/dev/null 2>&1; then
    echo 'ERROR: Another AIChecker process is running from a different path. Please close it.' >&2
    exit 3
fi
if [[ -d "$BACKUP" ]]; then rm -rf "$BACKUP"; fi
if [[ -d "$DEST" ]]; then mv "$DEST" "$BACKUP"; fi
if ! mv "$STAGE" "$DEST"; then
    if [[ -d "$BACKUP" && ! -d "$DEST" ]]; then mv "$BACKUP" "$DEST"; fi
    echo 'ERROR: install failed; previous app restored if available.' >&2; exit 3
fi
codesign --verify --strict "$DEST"
echo "INSTALLED: $DEST"
echo 'No Accessibility permission or background helper is requested.'
echo 'Launch-at-login is registered by AI Checker on first launch using macOS SMAppService (subject to user approval).'
# The requested one-command workflow: update and launch automatically.
# If app activation fails, the signed installation remains intact.
if ! open "$DEST"; then
    echo 'WARNING: installation succeeded but automatic launch failed; run scripts/launch.sh.' >&2
    exit 4
fi
echo 'AI Checker was updated and launched automatically.'
