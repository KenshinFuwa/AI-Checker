#!/usr/bin/env bash
# This historical publication entry point is intentionally disabled.
# The owner must review repository access, the current remote diff and CI
# before any GitHub write. This script never authenticates, pushes or creates PRs.
set -euo pipefail
printf '%s\n' 'BLOCKED: Historical GitHub publication automation is disabled.' 'Review docs/PUBLISH_PR.md after GitHub account access is restored.' >&2
exit 78
