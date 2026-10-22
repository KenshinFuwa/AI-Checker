#!/bin/bash
# Explicit, signed-bundle preserving migration to /Applications.
# No change to the bundle ID or its local Keychain/UserDefaults identity.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Mac only' >&2; exit 1; }
SOURCE="$HOME/Applications/AI Checker.app"
DEST='/Applications/AI Checker.app'
STAGE="/Applications/.AI-Checker-migrate-$$.app"
BACKUP="$HOME/Applications/AI Checker.before-system-migration"
[[ -d "$SOURCE" ]] || { echo "Missing: $SOURCE" >&2; exit 2; }
[[ ! -e "$DEST" && ! -e "$STAGE" && ! -e "$BACKUP" ]] || {
    echo 'Destination or backup already exists; refusing overwrite.' >&2; exit 2;
}
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")" == 'dev.aichecker.localapp' ]] || exit 2
codesign --verify --strict "$SOURCE"
echo "Moving the signed app from $SOURCE to $DEST."
echo 'Requires admin authorization; running app will be stopped after staging is verified.'
echo 'Note: Login Items approval may need to be refreshed after the move.'
read -r -p 'Type MOVE to continue: ' answer
[[ "$answer" == 'MOVE' ]] || { echo 'Canceled'; exit 0; }
sudo ditto "$SOURCE" "$STAGE"
if ! sudo codesign --verify --strict "$STAGE"; then
    sudo rm -rf "$STAGE"
    echo 'Staged signature verification failed; original untouched.' >&2
    exit 3
fi
signature_requirement() { codesign --display --requirements - "$1" 2>&1 | sed -n 's/^designated => //p' | head -n 1; }
SOURCE_REQ="$(signature_requirement "$SOURCE")"
STAGE_REQ="$(signature_requirement "$STAGE")"
if [[ -z "$SOURCE_REQ" || "$SOURCE_REQ" != "$STAGE_REQ" ]]; then
    sudo rm -rf "$STAGE"
    echo 'Signature identity changed; original untouched.' >&2
    exit 3
fi
running_source_pids() {
    local pid cmd
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        [[ "$cmd" == "$SOURCE/Contents/MacOS/AIChecker"* ]] && printf '%s\n' "$pid"
    done < <(pgrep -x AIChecker || true)
}
while IFS= read -r pid; do [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true; done <<< "$(running_source_pids)"
for attempt in {1..80}; do
    [[ -z "$(running_source_pids)" ]] && break
    sleep 0.1
done
if [[ -n "$(running_source_pids)" ]] || pgrep -x AIChecker >/dev/null 2>&1; then
    sudo rm -rf "$STAGE"
    echo 'An AIChecker process is still running; no migration performed.' >&2
    exit 3
fi
mv "$SOURCE" "$BACKUP"
if ! sudo mv "$STAGE" "$DEST"; then
    mv "$BACKUP" "$SOURCE"
    sudo rm -rf "$STAGE" 2>/dev/null || true
    echo 'Migration failed; original bundle restored.' >&2
    exit 3
fi
if ! codesign --verify --strict "$DEST"; then
    echo 'ERROR: Destination verification failed. Backup preserved at:' >&2
    echo "  $BACKUP" >&2
    exit 4
fi
LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
"$LSREGISTER" -u "$SOURCE" 2>/dev/null || true
"$LSREGISTER" -f "$DEST"
mdimport -i "$DEST" || true
open "$DEST"
echo "MIGRATED_TO_SYSTEM_APPLICATIONS: $DEST"
echo "Original signed backup (NOT an app bundle): $BACKUP"
echo 'Future updates via scripts/install-local.sh detect this location automatically.'
