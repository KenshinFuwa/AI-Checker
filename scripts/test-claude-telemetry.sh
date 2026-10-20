#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == "Darwin" ]] || { echo 'SKIP: Claude CLI probe requires macOS'; exit 0; }
BIN="$(swift build -c release --show-bin-path)/AIChecker"
[[ -x "$BIN" ]]
PROFILE="$(uuidgen | tr '[:upper:]' '[:lower:]')"
ROOT="$HOME/Library/Application Support/AI Checker/ClaudeAccounts/$PROFILE"
[[ ! -e "$ROOT" ]] || { echo 'Unexpected UUID collision' >&2; exit 1; }
cleanup(){ rm -rf "$ROOT"; }
trap cleanup EXIT
python3 - "$BIN" "$PROFILE" "$ROOT" <<'PY'
import json, pathlib, subprocess, sys, time
binary, profile, root = sys.argv[1:4]
future = int(time.time()) + 7200
# A statusLine JSON may include confidential information. The cache MUST not.
input_data = {
  'session_id': 'DO-NOT-STORE-SESSION-ID',
  'transcript_path': '/tmp/DO-NOT-STORE-PATH',
  'model': {'display_name': 'TEST'},
  'rate_limits': {
      'five_hour': {'used_percentage': 21, 'resets_at': future},
      'seven_day': {'used_percentage': 40, 'resets_at': future+3600}
  }
}
p = subprocess.run([binary,'--ingest-claude-statusline','--profile',profile],
                   input=json.dumps(input_data).encode(), capture_output=True, timeout=10)
assert p.returncode == 0, p.stderr.decode()
assert b'79%' in p.stdout and b'60%' in p.stdout
cache = pathlib.Path(root)/'quota.json'
data = cache.read_text()
assert 'DO-NOT-STORE' not in data
assert 'fiveHourRemaining' in data and 'weeklyRemaining' in data
assert 'session_id' not in data and 'transcript_path' not in data
# Invalid UUID must fail without touching a real account.
invalid = subprocess.run([binary,'--ingest-claude-statusline','--profile','not-a-uuid'],
                         input=b'{}', capture_output=True, timeout=10)
assert invalid.returncode != 0
print('PASS: Claude official statusLine profile quota + privacy + invalid-profile guard')
PY
