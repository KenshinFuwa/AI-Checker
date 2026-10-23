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
# Respect an already migrated system-wide app. Never create a competing
# ~/Applications copy that would confuse Spotlight or Launch Services.
# The offline test fixture must not inspect the developer's REAL /Applications.
# This override is only for the explicitly opted-in hermetic installer tests.
SYSTEM_APPLICATIONS_DIR='/Applications'
if [[ "${AI_CHECKER_INSTALL_TESTING:-0}" == '1' ]]; then
    [[ -n "${AI_CHECKER_TEST_SYSTEM_APPLICATIONS_DIR:-}" ]] || {
        echo 'ERROR: installer test fixture missing synthetic Applications directory' >&2
        exit 3
    }
    SYSTEM_APPLICATIONS_DIR="$AI_CHECKER_TEST_SYSTEM_APPLICATIONS_DIR"
fi
SYSTEM_INSTALL=false
if [[ -d "$SYSTEM_APPLICATIONS_DIR/AI Checker.app" ]]; then
    if [[ -d "$HOME/Applications/AI Checker.app" ]]; then
        echo 'ERROR: Both system and user AI Checker bundles exist. Resolve duplicates first.' >&2
        exit 3
    fi
    SYSTEM_INSTALL=true
    DEST="$SYSTEM_APPLICATIONS_DIR/AI Checker.app"
    BACKUP="$SYSTEM_APPLICATIONS_DIR/AI Checker.previous.app"
else
    DEST="$HOME/Applications/AI Checker.app"
    BACKUP="$HOME/Applications/AI Checker.previous.app"
fi
STAGE="$HOME/Applications/.AI-Checker-stage.$$.app"
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
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundleDisplayName</key><string>AI Checker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleSignature</key><string>????</string>
<key>CFBundleShortVersionString</key><string>1.10.1</string>
<key>CFBundleVersion</key><string>11001</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Original application icon (no provider logos). Copy before signing.
if [[ -s "$ROOT/Design/AppIcon.icns" ]]; then
    mkdir -p "$STAGE/Contents/Resources"
    cp "$ROOT/Design/AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
else
    echo 'ERROR: original AI Checker AppIcon.icns is missing.' >&2
    exit 3
fi
# Ship the same localized resources in both local and distributable bundles.
# Fail before touching the running installation if any localization is missing.
for LANGUAGE in en ja; do
    RESOURCE="$ROOT/Localization/$LANGUAGE.lproj/Localizable.strings"
    [[ -s "$RESOURCE" && ! -L "$RESOURCE" ]] || {
        echo "ERROR: missing $LANGUAGE localization." >&2; exit 3;
    }
    plutil -lint "$RESOURCE" >/dev/null
    mkdir -p "$STAGE/Contents/Resources/$LANGUAGE.lproj"
    cp "$RESOURCE" "$STAGE/Contents/Resources/$LANGUAGE.lproj/Localizable.strings"
    cmp "$RESOURCE" "$STAGE/Contents/Resources/$LANGUAGE.lproj/Localizable.strings"
done
# Standard macOS application bundle marker. Written before signing.
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
plutil -lint "$STAGE/Contents/Info.plist"
# Reject malformed icon resources before touching any installed application.
if [[ "${AI_CHECKER_INSTALL_TESTING:-0}" != '1' ]]; then
    if ! sips -g pixelWidth -g pixelHeight "$STAGE/Contents/Resources/AppIcon.icns" >/dev/null; then
        echo 'ERROR: AppIcon.icns cannot be decoded by macOS.' >&2
        exit 3
    fi
fi
codesign --force --sign "$IDENTITY" --timestamp=none "$STAGE"
codesign --verify --strict --verbose=2 "$STAGE"
# Check the icon and bundle identity after signing but before the old app stops.
[[ -s "$STAGE/Contents/Resources/AppIcon.icns" && -s "$STAGE/Contents/PkgInfo" ]] || {
    echo 'ERROR: signed bundle missing icon or PkgInfo' >&2; exit 3;
}
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
if $SYSTEM_INSTALL; then
    # Only /Applications requires admin privileges; staging and signing remain
    # unprivileged. Preserve previous installed app for recovery.
    if [[ -d "$BACKUP" ]]; then sudo rm -rf "$BACKUP"; fi
    if [[ -d "$DEST" ]]; then sudo mv "$DEST" "$BACKUP"; fi
    if ! sudo mv "$STAGE" "$DEST"; then
        if [[ -d "$BACKUP" && ! -d "$DEST" ]]; then sudo mv "$BACKUP" "$DEST"; fi
        echo 'ERROR: system install failed; previous app restored if possible.' >&2
        exit 3
    fi
else
    if [[ -d "$BACKUP" ]]; then rm -rf "$BACKUP"; fi
    if [[ -d "$DEST" ]]; then mv "$DEST" "$BACKUP"; fi
    if ! mv "$STAGE" "$DEST"; then
        if [[ -d "$BACKUP" && ! -d "$DEST" ]]; then mv "$BACKUP" "$DEST"; fi
        echo 'ERROR: install failed; previous app restored if available.' >&2; exit 3
    fi
fi
codesign --verify --strict "$DEST"
echo "INSTALLED: $DEST"
# Explicitly refresh Launch Services because CLI-installs to ~/Applications
# are not necessarily discovered promptly by Spotlight. Do not modify the
# running process, code signature, or other applications.
if ! bash "$ROOT/scripts/repair-spotlight.sh" "$DEST"; then
    echo 'WARNING: Launch Services registration failed; app installation remains intact.' >&2
    echo "Run: bash '$ROOT/scripts/repair-spotlight.sh'" >&2
fi
echo 'No Accessibility permission or background helper is requested.'
echo 'Launch-at-login is registered by AI Checker on first launch using macOS SMAppService (subject to user approval).'
# The requested one-command workflow: update and launch automatically.
# If app activation fails, the signed installation remains intact.
if ! open "$DEST"; then
    echo 'WARNING: installation succeeded but automatic launch failed; run scripts/launch.sh.' >&2
    exit 4
fi
echo 'AI Checker was updated and launched automatically.'
