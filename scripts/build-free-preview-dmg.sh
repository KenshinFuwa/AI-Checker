#!/usr/bin/env bash
# Developer-ID-free, AD-HOC signed, UNNOTARIZED preview for isolated testing only.
# Never installs or updates an existing AI Checker.
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: macOS required.' >&2; exit 2; }
[[ $# -eq 1 && "$1" == '--acknowledge-unnotarized-preview' ]] || {
  echo 'HOLD: explicit --acknowledge-unnotarized-preview required.' >&2; exit 2;
}
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for tool in python3 codesign hdiutil lipo shasum mktemp; do
  command -v "$tool" >/dev/null || { echo "ERROR: missing $tool" >&2; exit 2; }
done
python3 scripts/verify-source-manifest.py
OUTPUT_DIR="$ROOT/dist"
NAME='AI-Checker-v1.10.1-UNNOTARIZED-PREVIEW.dmg'
DMG="$OUTPUT_DIR/$NAME"
CHECKSUM="$DMG.sha256"
NOTICE="$OUTPUT_DIR/README-UNNOTARIZED-PREVIEW.txt"
for target in "$DMG" "$CHECKSUM" "$NOTICE"; do
  [[ ! -e "$target" && ! -L "$target" ]] || { echo "HOLD: output already exists: $target" >&2; exit 3; }
done
TEMP="$(mktemp -d "${TMPDIR:-/tmp/}aichecker-unnotarized-preview.XXXXXXXX")"
created=0
complete=0
cleanup() {
  if [[ "$created" -eq 1 && "$complete" -eq 0 ]]; then
    rm -f "$DMG" "$CHECKSUM" "$NOTICE"
  fi
  rm -rf "$TEMP"
}
trap cleanup EXIT
bash scripts/build-universal-binary.sh "$TEMP/AIChecker"
mkdir -p "$TEMP/dmgroot"
APP="$TEMP/dmgroot/AI Checker.app"
bash scripts/stage-release-app.sh "$TEMP/AIChecker" "$APP"
# Ad-hoc signing is NOT Developer ID; it does not establish publisher identity.
codesign --force --sign - --options runtime "$APP"
codesign --verify --strict --verbose=2 "$APP"
DETAILS="$(codesign -dv --verbose=4 "$APP" 2>&1)"
grep -F 'Signature=adhoc' <<< "$DETAILS" >/dev/null || {
  echo 'ERROR: expected ad-hoc signature, not verified publisher identity.' >&2; exit 3;
}
if grep -F 'Authority=Developer ID Application:' <<< "$DETAILS" >/dev/null; then
  echo 'ERROR: this preview must not masquerade as a Developer ID release.' >&2; exit 3;
fi
lipo "$APP/Contents/MacOS/AIChecker" -verify_arch arm64 x86_64
ln -s /Applications "$TEMP/dmgroot/Applications"
cat > "$TEMP/dmgroot/READ-ME-UNNOTARIZED.txt" <<'NOTICE'
AI Checker v1.10.1 — UNNOTARIZED TEST PREVIEW / 未公証テスト版

This is NOT signed with Apple Developer ID and has NOT been notarized by Apple.
macOS Gatekeeper may refuse to open it. This preview must not be presented
as an Apple-verified app, an official release, or a safe general installer.

TEST ON AN ISOLATED MAC ONLY. Do not replace any existing AI Checker.app.
There is no auto-installer, login-item updater, nor automatic permission bypass.
Check sources and checksum independently before deciding whether to test.
Official Apple guidance: https://support.apple.com/ja-jp/102445

Apple Developer Program enrollment is NOT required to build this preview.
NOTICE
hdiutil create -quiet -volname 'AI Checker UNNOTARIZED Preview' \
  -srcfolder "$TEMP/dmgroot" -format UDZO "$TEMP/$NAME"
hdiutil verify "$TEMP/$NAME" >/dev/null
bash scripts/audit-release-dmg.sh --unsigned-preflight "$TEMP/$NAME"
mkdir -p "$OUTPUT_DIR"
[[ ! -e "$DMG" && ! -e "$CHECKSUM" && ! -e "$NOTICE" ]] || {
  echo 'ERROR: output appeared during build; refusing overwrite.' >&2; exit 3;
}
created=1
cp "$TEMP/$NAME" "$DMG"
(cd "$OUTPUT_DIR" && shasum -a 256 "$NAME" > "$NAME.sha256")
cp "$TEMP/dmgroot/READ-ME-UNNOTARIZED.txt" "$NOTICE"
python3 scripts/verify-release-checksum.py "$DMG" "$CHECKSUM"
complete=1
echo 'PASS: AD-HOC SIGNED, UNNOTARIZED TEST PREVIEW (NOT APPLE VERIFIED).'
echo "PREVIEW_DMG: $DMG"
echo "PREVIEW_CHECKSUM: $CHECKSUM"
echo 'No installed app was changed; no GitHub Release was published.'
