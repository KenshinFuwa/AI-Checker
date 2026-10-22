#!/usr/bin/env bash
# Push tested feature to a new PR branch; never modify public main or create a release.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'ERROR: run native checks on macOS before proposing.' >&2; exit 2; }
for tool in git gh swift python3; do command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 2; }; done
gh auth status >/dev/null || { echo 'First run: gh auth login' >&2; exit 2; }
[[ "$(gh api user --jq .login)" == "KenshinFuwa" ]] || { echo 'Wrong GitHub account' >&2; exit 2; }
[[ ! -d .git ]] || { echo 'ERROR: use a fresh extracted directory, not a working Git repository.' >&2; exit 2; }
python3 scripts/verify-source-manifest.py
# Git rejects whitespace errors in the final staged diff; catch these locally
# before the expensive native gate and before asking for PROPOSE.
python3 Tests/test_public_release.py
bash scripts/check.sh
BRANCH='release/v1.10.1-source-beta.1'
REPO='KenshinFuwa/AI-Checker'
if gh api "repos/$REPO/branches/$BRANCH" >/dev/null 2>&1; then
  echo 'Remote feature branch already exists. Refusing to overwrite.' >&2; exit 3
fi
printf '\nWill create branch %s and open a PR to %s/main (no binary release).\n' "$BRANCH" "$REPO"
read -r -p 'Type PROPOSE to continue: ' answer
[[ "$answer" == 'PROPOSE' ]] || { echo 'No remote changes made'; exit 4; }
# Perform Git operations only inside a temporary clone; source files and
# the installed app on this Mac remain completely untouched.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --quiet --depth 1 "https://github.com/$REPO.git" "$TMP/repo"
git -C "$TMP/repo" checkout -q -b "$BRANCH"
rsync -a --delete \
  --exclude='.git/' --exclude='.build/' --exclude='.swiftpm/' \
  --exclude='__pycache__/' --exclude='*.pyc' \
  ./ "$TMP/repo/"
git -C "$TMP/repo" add -A
python3 - "$TMP/repo" <<'PYAUDIT'
import re,subprocess,sys
repo=sys.argv[1]
names=subprocess.check_output(['git','-C',repo,'diff','--cached','--name-only','-z']).decode().split('\0')
for name in filter(None,names):
 lower=name.lower()
 if lower.startswith(('.build/','.swiftpm/','.git/','dist/')) or lower.endswith(('.pem','.key','.p12','.pfx','.dmg','.zip','.db','.sqlite','.pyc','.log')) or (lower.endswith(('.png','.icns')) and lower not in ('design/appicon.png','design/appicon.icns')) or re.search(r'(^|/)(auth.json|\.env|\.credentials.json)$',lower):
  raise SystemExit('Forbidden staged path: '+name)
print('PASS: staged file allowlist')
PYAUDIT
git -C "$TMP/repo" diff --cached --check
git -C "$TMP/repo" config user.name 'Kenshin Fuwa'
ACCOUNT_ID="$(gh api user --jq .id)"
git -C "$TMP/repo" config user.email "${ACCOUNT_ID}+KenshinFuwa@users.noreply.github.com"
git -C "$TMP/repo" commit -q -m 'Propose AI Checker v1.10.1 source update and distribution gates'
git -C "$TMP/repo" push -u origin "$BRANCH"
gh pr create --repo "$REPO" --base main --head "$BRANCH" \
 --title 'AI Checker v1.10.1: updated source, QA and notarization gates' \
 --body 'Adds a stay-open submenu for selecting connected Codex/Claude/Copilot/API usage meters. Administrative cost and request counts remain distinct from personal chat quotas; no fabricated quota percentages. Public source is source-only; native macOS tests and review required.'
echo 'PR created; main and published tags remain unchanged.'
