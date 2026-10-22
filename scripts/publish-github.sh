#!/usr/bin/env bash
# One-command, guarded, first publication of source-only AI Checker beta.
set -euo pipefail
cd "$(dirname "$0")/.."

OWNER="KenshinFuwa"
NAME="AI-Checker"
REPOSITORY="$OWNER/$NAME"
TAG="v1.9.2-beta.3"  # historic INITIAL publisher only; do not reuse for updates

echo "AI Checker publication: $REPOSITORY ($TAG)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'ERROR: run the publication gate on macOS so AppKit native build is tested.' >&2
  exit 2
fi
for tool in git swift python3 gh; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: missing $tool" >&2
    if [[ "$tool" == gh ]]; then
      echo 'Install GitHub CLI via: brew install gh' >&2
      echo 'Then: gh auth login' >&2
    fi
    exit 2
  fi
done
if ! gh auth status >/dev/null 2>&1; then
  echo 'GitHub authentication required. Running: gh auth login' >&2
  gh auth login
fi
LOGIN="$(gh api user --jq '.login')"
if [[ "$LOGIN" != "$OWNER" ]]; then
  echo "ERROR: expected GitHub owner $OWNER; active account is $LOGIN. Nothing published." >&2
  exit 2
fi
if gh repo view "$REPOSITORY" --json name --jq '.name' >/dev/null 2>&1; then
  echo "ERROR: $REPOSITORY already exists. Refusing to overwrite or push without repository review." >&2
  exit 2
fi
# Preserve the user's local installation; never call install-local.sh from publishing.
echo '=== macOS full offline validation ==='
bash scripts/check.sh
python3 Tests/test_public_release.py
python3 scripts/verify-source-manifest.py

if [[ -d .git ]]; then
  if [[ -n "$(git remote)" ]]; then
    echo 'ERROR: refusing to publish a source directory already connected to a Git remote.' >&2
    exit 2
  fi
else
  git init -b main
fi
# Use a GitHub-generated no-reply address to avoid publishing a private
# personal email from the Mac's global git config. Local-repo-only config.
ACCOUNT_ID="$(gh api user --jq '.id')"
if [[ ! "$ACCOUNT_ID" =~ ^[0-9]+$ ]]; then
  echo 'ERROR: could not verify GitHub numeric account ID.' >&2
  exit 2
fi
git config --local user.name "Kenshin Fuwa"
git config --local user.email "${ACCOUNT_ID}+${LOGIN}@users.noreply.github.com"

git add --all
git diff --cached --check
# An allowlist of content categories prevents accidental local credentials and build exports.
python3 - <<'PY'
import subprocess,sys,re
names=subprocess.check_output(['git','diff','--cached','--name-only','-z']).decode().split('\0')
forbidden=[]
for n in filter(None,names):
    f=n.lower()
    if (f.startswith(('.build/','dist/','.swiftpm/','.auth/','__pycache__/')) or '/__pycache__/' in f or
        f.endswith(('.zip','.dmg','.pkg','.p12','.pfx','.pem','.key','.png','.jpg','.jpeg','.webp','.log','.db','.sqlite','.pyc','.pyo')) or
        f.split('/')[-1] in ('.ds_store','.env','auth.json','.credentials.json') or
        re.search(r'(^|/)(session[^/]*\.json|\.env\.[^/]+)$',f)):
        forbidden.append(n)
if forbidden:
    print('ERROR: disallowed staged files:', '\n'.join(forbidden),file=sys.stderr)
    sys.exit(3)
print('PASS: staged paths exclude local auth, binaries, archives and brand images')
PY
printf '\n=== Commit preview ===\n'
git diff --cached --stat
# User explicitly requested public release; the macOS script still states final side effects.
printf '\nPublishing creates a PUBLIC repository at https://github.com/%s\n' "$REPOSITORY"
printf 'No notarized DMG or signed executable is being uploaded.\n'
read -r -p 'Type PUBLISH to create this public repository and push source: ' ANSWER
if [[ "$ANSWER" != 'PUBLISH' ]]; then
  echo 'Stopped before remote creation. No GitHub repository was created.' >&2
  exit 4
fi
if ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  git commit -m "Publish AI Checker source beta $TAG"
elif ! git diff --cached --quiet; then
  git commit -m "Prepare AI Checker source beta $TAG"
fi
# `gh repo create` is the official GitHub CLI command for creating a new repo.
gh repo create "$REPOSITORY" --public --description \
  'Open-source macOS menu-bar AI usage monitor (source-only beta)' \
  --source=. --remote=origin --push
if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "AI Checker source-only beta $TAG (no signed app)"
fi
git push origin "$TAG"
URL="$(gh repo view "$REPOSITORY" --json url --jq '.url')"
printf '\nPUBLISHED: %s\nTAG: %s\n' "$URL" "$TAG"
printf 'Next: check GitHub Actions > macOS Swift validation, then enable private vulnerability reporting.\n'
