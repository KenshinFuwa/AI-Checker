#!/bin/bash
# Dry-run by default. Archives only old MenuPilot .app bundles, never source projects.
# macOS may retain historical Background Items entries until a restart or OS maintenance.
set -euo pipefail
mode="${1:---dry-run}"
if [[ "$mode" != '--dry-run' && "$mode" != '--apply' ]]; then
    echo 'Usage: ./scripts/cleanup-legacy.sh [--dry-run|--apply]' >&2; exit 2
fi
paths=()
for path in "$HOME/Applications/MenuPilot.app" "$HOME/Applications/MenuPilot.previous.app" \
            "$HOME/Applications/MenuPilotAX.app"; do
    [[ -d "$path" ]] && paths+=("$path")
done
# Restrict to known archived project folders; do not touch arbitrary other apps.
shopt -s nullglob
for path in "$HOME"/Downloads/MenuPilot-v*/dist/MenuPilot.app \
            "$HOME"/Downloads/MenuPilot-v*/dist/MenuPilotAX.app \
            "$HOME"/Downloads/MenuPilot-v*/dist/MenuPilot.previous.app; do
    [[ -d "$path" ]] && paths+=("$path")
done
shopt -u nullglob
echo 'Legacy MenuPilot app bundles (Swift project source folders are NOT removed):'
if ((${#paths[@]} == 0)); then echo '  none found'; else printf '  %s\n' "${paths[@]}"; fi
echo 'macOS Background Items records are managed by macOS and are not automatically reset.'
if [[ "$mode" == '--dry-run' ]]; then
    echo 'No changes made. After reviewing, run: ./scripts/cleanup-legacy.sh --apply'
    exit 0
fi
if ((${#paths[@]} == 0)); then exit 0; fi
read -r -p 'Archive these OLD .app bundles as ZIP backups, then remove originals? Type ARCHIVE: ' answer
[[ "$answer" == ARCHIVE ]] || { echo 'Cancelled; no changes.'; exit 2; }
# Gracefully stop only the retired utility (not unrelated apps).
pkill -x MenuPilot 2>/dev/null || true
pkill -x MenuPilotAX 2>/dev/null || true
sleep 1
if pgrep -x MenuPilot >/dev/null 2>&1; then echo 'MenuPilot did not quit. Stop it manually.' >&2; exit 3; fi
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$HOME/Documents/AI-Checker-Legacy-Backup/$STAMP"
mkdir -p "$BACKUP"
for path in "${paths[@]}"; do
    # Archive old bundles so we don't create a new duplicate discoverable .app in backup.
    sub="${path#"$HOME"/}"
    zip_path="$BACKUP/$sub.zip"
    mkdir -p "$(dirname "$zip_path")"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$path" "$zip_path"
    /usr/bin/unzip -tqq "$zip_path" || { echo "Archive verification failed for $path; original retained" >&2; exit 3; }
    rm -rf -- "$path"
    echo "ARCHIVED: $path -> $zip_path"
done
echo "ZIP backups: $BACKUP"
echo 'If MenuPilot still appears in Login Items & Extensions, restart macOS and inspect it again.'
echo 'Historical background registrations may remain even with no app; they are not reset here.'
echo 'Do NOT run sfltool resetbtm; it also resets other apps background registrations.'
