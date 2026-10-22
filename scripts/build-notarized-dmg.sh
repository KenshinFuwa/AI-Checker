#!/usr/bin/env bash
# Build a DISTRIBUTION app separately from the user's installed AI Checker.
# Never modify ~/Applications, /Applications, login items, or user credentials.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: macOS required.' >&2; exit 2; }
cd "$(dirname "$0")/.."
ROOT="$PWD"
IDENTITY="${AI_CHECKER_DEVELOPER_ID:-}"
PROFILE="${AI_CHECKER_NOTARY_PROFILE:-}"
[[ "$IDENTITY" == 'Developer ID Application:'* ]] || {
    echo 'HOLD: set AI_CHECKER_DEVELOPER_ID to an installed Developer ID Application signing identity.' >&2
    exit 2
}
[[ -n "$PROFILE" ]] || { echo 'HOLD: set AI_CHECKER_NOTARY_PROFILE to a pre-existing notarytool Keychain profile.' >&2; exit 2; }
for tool in swift swiftc python3 codesign security xcrun hdiutil plutil sips shasum lipo; do
    command -v "$tool" >/dev/null || { echo "ERROR: missing $tool" >&2; exit 2; }
done
security find-identity -v -p codesigning | grep -F -- "$IDENTITY" >/dev/null || {
    echo 'HOLD: Developer ID Application identity not found in this Mac Keychain.' >&2; exit 2;
}
[[ -s Design/AppIcon.icns ]] || { echo 'ERROR: missing original AppIcon.icns.' >&2; exit 2; }
python3 scripts/verify-source-manifest.py
bash scripts/check.sh
TEMP="$(mktemp -d "${TMPDIR:-/tmp/}aichecker-public-release.XXXXXXXX")"
cleanup(){ rm -rf "$TEMP"; }
trap cleanup EXIT
APP="$TEMP/AI Checker.app"
# Shared staging path: identical app layout to the unsigned macOS CI preflight.
bash scripts/build-universal-binary.sh "$TEMP/AIChecker-universal"
bash scripts/stage-release-app.sh "$TEMP/AIChecker-universal" "$APP"
# --options runtime and a timestamp are required for notarizable Developer ID output.
codesign --force --sign "$IDENTITY" --options runtime --timestamp "$APP"
codesign --verify --strict --verbose=2 "$APP"
lipo "$APP/Contents/MacOS/AIChecker" -verify_arch arm64 x86_64
codesign -dv --verbose=4 "$APP" 2> "$TEMP/signing.txt"
grep -F 'Authority=Developer ID Application:' "$TEMP/signing.txt" >/dev/null || {
    echo 'ERROR: signed app is not identified by Developer ID Application.' >&2; exit 3;
}
grep -E '^TeamIdentifier=[A-Z0-9]+' "$TEMP/signing.txt" >/dev/null || {
    echo 'ERROR: signing team identifier is missing.' >&2; exit 3;
}
DMGROOT="$TEMP/dmgroot"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/AI Checker.app"
ln -s /Applications "$DMGROOT/Applications"
DMG="$TEMP/AI-Checker-v1.10.1-notarized.dmg"
hdiutil create -quiet -volname 'AI Checker' -srcfolder "$DMGROOT" -format UDZO -ov "$DMG"
hdiutil verify "$DMG" >/dev/null
# Submit without printing secrets. The Keychain profile must have been configured by the owner.
echo 'Submitting signed DMG to Apple notary service...'
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait --output-format json > "$TEMP/notary-result.json"
python3 - "$TEMP/notary-result.json" <<'PYVERIFY'
import json,sys
j=json.load(open(sys.argv[1], encoding='utf-8'))
status=j.get('status')
print('NOTARIZATION_STATUS:',status)
print('NOTARIZATION_ID:',j.get('id','unknown'))
if status != 'Accepted':
    raise SystemExit('HOLD: notarization was not accepted; do NOT distribute this DMG.')
PYVERIFY
xcrun stapler staple -v "$DMG"
xcrun stapler validate -v "$DMG"
hdiutil verify "$DMG" >/dev/null
# Independently mount and inspect the signed, notarized, stapled DMG.
bash scripts/audit-release-dmg.sh --signed-release "$DMG"
mkdir -p "$ROOT/dist"
OUTPUT="$ROOT/dist/AI-Checker-v1.10.1-notarized.dmg"
[[ ! -e "$OUTPUT" ]] || { echo 'ERROR: distribution artifact already exists; refuse overwrite.' >&2; exit 3; }
cp "$DMG" "$OUTPUT"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256")
python3 scripts/verify-release-checksum.py "$OUTPUT" "$OUTPUT.sha256"
echo "NOTARIZED_DMG: $OUTPUT"
echo 'NO_GITHUB_RELEASE_CREATED: true'
echo 'IMPORTANT: inspect the DMG on a clean Mac, and test upgrades from existing locally signed builds separately.'
