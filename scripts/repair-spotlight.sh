#!/bin/bash
# Register an already installed AI Checker with macOS Launch Services.
# Does not rebuild, resign, stop, replace, or modify user settings.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
    echo 'ERROR: This helper requires macOS.' >&2
    exit 1
fi
APP="${1:-$HOME/Applications/AI Checker.app}"
if [[ ! -d "$APP/Contents" || ! -x "$APP/Contents/MacOS/AIChecker" ]]; then
    echo "ERROR: Installed app not found: $APP" >&2
    exit 2
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || true)" != 'dev.aichecker.localapp' ]]; then
    echo "ERROR: Unexpected bundle identifier; refusing to register: $APP" >&2
    exit 2
fi
LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
if [[ ! -x "$LSREGISTER" ]]; then
    echo 'ERROR: macOS Launch Services registration tool unavailable.' >&2
    exit 3
fi
"$LSREGISTER" -f "$APP"
echo "REGISTERED_WITH_LAUNCH_SERVICES: $APP"
echo 'Try Spotlight again: Command-Space -> AI Checker.'
echo 'If missing, check System Settings > Spotlight > Search Results (Applications) and Spotlight Privacy.'
echo 'If it remains absent, consider installing to /Applications using a separate reviewed migration (do not copy over the running app).'
