#!/bin/bash
set -euo pipefail
./scripts/cleanup-legacy.sh --dry-run
if [[ "$(uname -s)" == Darwin ]] && command -v sfltool >/dev/null; then
  echo
  echo 'Old macOS background item records (read-only; excerpts may contain local paths):'
  sfltool dumpbtm 2>/dev/null | grep -i -C 4 -E 'MenuPilot|menupilot|dev\.menupilot' || true
  echo 'Old records may remain after deleting a bundle; this script does not modify BTM.'
fi
