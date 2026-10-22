#!/bin/bash
# Non-destructive app indexing diagnosis. Never resets the entire Spotlight DB.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Mac only' >&2; exit 1; }
if [[ -n "${1:-}" ]]; then
    APP="$1"
elif [[ -d '/Applications/AI Checker.app' ]]; then
    APP='/Applications/AI Checker.app'
else
    APP="$HOME/Applications/AI Checker.app"
fi
[[ -d "$APP/Contents" ]] || { echo "Missing bundle: $APP" >&2; exit 2; }
echo "BUNDLE_PATH: $APP"
echo "BUNDLE_ID: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
echo '=== Code signature ==='
codesign --verify --strict "$APP" && echo 'SIGNATURE_OK'
echo '=== Spotlight indexing status ==='
mdutil -s / || true
echo '=== Spotlight metadata ==='
mdls -name kMDItemContentType -name kMDItemDisplayName -name kMDItemCFBundleIdentifier "$APP" || true
echo '=== Spotlight metadata importer dry run (does not modify index) ==='
# A successful Launch Services registration is not the same as searchable
# Spotlight metadata. Test the bundle importer independently of the index DB.
import_log="$(mktemp -t aichecker-spotlight.XXXXXX)"
trap 'rm -f "$import_log"' EXIT
if mdimport -t -d2 "$APP" >"$import_log" 2>&1; then
    if grep -Eq 'kMDItemContentType|kMDItemCFBundleIdentifier|com.apple.application-bundle' "$import_log"; then
        echo 'SPOTLIGHT_IMPORTER_METADATA: RECOGNIZED'
    else
        echo 'SPOTLIGHT_IMPORTER_METADATA: NO_APP_FIELDS (inspect diagnostic below)'
    fi
else
    echo 'SPOTLIGHT_IMPORTER_METADATA: TEST_FAILED'
fi
# Print only the relevant importer diagnostics, not all indexed document content.
grep -E 'kMDItemContentType|kMDItemCFBundleIdentifier|kMDItemDisplayName|com.apple.application-bundle|error|Error' "$import_log" | head -n 15 || true
echo '=== Indexed AI Checker paths ==='
mdfind 'kMDItemCFBundleIdentifier == "dev.aichecker.localapp"' || true
echo '=== Targeted re-import and Launch Services registration ==='
LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
"$LSREGISTER" -f "$APP"
mdimport -i "$APP" || true
echo '=== Search index after import (may take time) ==='
mdfind 'kMDItemCFBundleIdentifier == "dev.aichecker.localapp"' || true
# Explicitly separate metadata registration from Spotlight search availability.
# Absence in this exact metadata query is not proof that the UI can never
# find the app, but it is a useful signal to investigate indexing exclusions.
indexed_paths="$(mdfind 'kMDItemCFBundleIdentifier == "dev.aichecker.localapp"' 2>/dev/null || true)"
if printf '%s\n' "$indexed_paths" | grep -Fxq "$APP"; then
    echo 'SPOTLIGHT_METADATA_MATCH: YES'
else
    echo 'SPOTLIGHT_METADATA_MATCH: NOT_CONFIRMED'
    echo 'Search results still missing: check Spotlight app-search settings and privacy exclusions.'
    echo 'Official Apple fix: add /Applications to Spotlight Search Privacy, wait, then remove it to reindex that folder.'
    echo 'Do not re-migrate or re-register the app repeatedly; avoid whole-disk index resets.'
fi
echo 'The final test is a real Command-Space app search; Launch Services registration alone is not enough.'
echo 'If it is still not indexed, check Spotlight app-search visibility/privacy exclusions.'
echo 'Apple recommends placing non-App-Store apps in /Applications. For safe migration:'
echo '  bash scripts/migrate-spotlight-app.sh'
