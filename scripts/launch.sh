#!/bin/bash
set -euo pipefail
APP="$HOME/Applications/AI Checker.app"
if [[ ! -x "$APP/Contents/MacOS/AIChecker" ]]; then
    echo 'AI Checker is not installed. Run ./scripts/install-local.sh first.' >&2
    exit 1
fi
# Do not build, re-sign, change TCC, or modify any Keychain on launch.
# install-local.sh already launches the new app. Do not create another
# process or touch the code signature when this helper runs afterwards.
if pgrep -x AIChecker >/dev/null 2>&1; then
    echo 'AI Checker is already running.'
    exit 0
fi
open "$APP"
