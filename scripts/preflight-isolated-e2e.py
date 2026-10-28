#!/usr/bin/env python3
"""Read-only eligibility preflight. READY is never proof of macOS E2E success."""
import argparse
import os
from pathlib import Path
import platform
import pwd
import subprocess
import sys

# Check path presence only; NEVER open the contents of accounts or credentials.
USER_FOOTPRINTS = (
    "Library/Application Support/AI Checker",
    "Library/Preferences/dev.aichecker.localapp.plist",
    "Library/Containers/dev.aichecker.localapp",
    "Applications/AI Checker.app", ".codex", ".claude",
)


def assess(*, os_name, uid, euid, acknowledged, home_matches, footprints, process_result):
    """Fail closed on all known collisions or unverified conditions."""
    reasons = []
    if os_name != "Darwin":
        reasons.append("This preflight requires macOS.")
    if uid == 0 or euid != uid:
        reasons.append("Root or mismatched effective user is not permitted.")
    if not acknowledged:
        reasons.append("Separate test-account acknowledgement is missing.")
    if not home_matches:
        reasons.append("HOME differs from the OS-registered account home.")
    if footprints:
        reasons.append("Existing application or provider profile paths detected.")
    if process_result != 1:
        reasons.append("AIChecker is running for this user, or process inspection failed.")
    return reasons


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ack-separate-user", action="store_true",
                    help="I am logged into a disposable macOS account or test Mac.")
    args = ap.parse_args(argv)
    uid, euid = os.getuid(), os.geteuid()
    try:
        recorded = Path(pwd.getpwuid(uid).pw_dir).resolve(strict=True)
        envhome = Path(os.environ.get("HOME", "")).resolve(strict=True)
        home_matches = recorded == envhome
        found = [p for p in USER_FOOTPRINTS
                 if (recorded / p).exists() or (recorded / p).is_symlink()]
    except (KeyError, OSError, RuntimeError, ValueError):
        home_matches, found = False, ["HOME_NOT_VERIFIED"]
    try:
        # Exact executable name for this OS user; discard all PIDs and output.
        rc = subprocess.run(["pgrep", "-u", str(uid), "-x", "AIChecker"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            check=False, timeout=5).returncode
    except (OSError, subprocess.TimeoutExpired):
        rc = -1
    failures = assess(os_name=platform.system(), uid=uid, euid=euid,
                      acknowledged=args.ack_separate_user, home_matches=home_matches,
                      footprints=found, process_result=rc)
    print("AI CHECKER — READ-ONLY E2E SAFETY PRE-FLIGHT")
    print("No app start, build, install, settings write, Keychain query or provider login.")
    if failures:
        print("HOLD: DO NOT START MANUAL E2E IN THIS SESSION.")
        for reason in failures:
            print("- " + reason)
        return 2
    print("PRE-FLIGHT READY — no known current-user collision.")
    print("NOT E2E PASS. OS-user isolation and real UI/account tests remain unverified.")
    print("Read docs/ISOLATED_E2E_PROTOCOL.md before any manual test.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
