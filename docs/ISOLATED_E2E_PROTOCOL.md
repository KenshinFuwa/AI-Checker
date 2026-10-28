# Isolated native macOS E2E protocol — Issue #15

**STATUS: NOT RUN.** The public v1.10.1-beta.2 is source-only.
Automated CI is not a substitute for real first-run GUI or first-party account validation.

## Mandatory isolation

Use a **separate physical test Mac** or a genuinely **separate disposable macOS
graphical user session** with its own home, Keychain and preferences. Never run
a second AI Checker in the maintainer's currently active user session.
Never overwrite /Applications/AI Checker.app, ~/Applications/AI Checker.app,
a production login item or a Codex/Claude profile.

Changing only HOME, an app identifier or a shell variable does NOT isolate
Keychain access or application settings. Running the preflight in a new
source checkout does NOT prove the user account is disposable.

## Read-only safety preflight

In a clean checkout pinned to the exact commit under test:

~~~sh
python3 scripts/verify-source-manifest.py
python3 scripts/preflight-isolated-e2e.py --ack-separate-user
~~~

No app launch, code signing, build, install, login, Keychain access or
settings change occurs. The script checks the OS-registered home rather
than trusting HOME alone; refuses root, missing acknowledgement, known
current-account app/CLI profile paths, an active AIChecker process, or
failed process inspection. It prints no account identity or private data.

**PRE-FLIGHT READY != E2E PASS.** A clean account cannot be proven
isolated by filesystem checks. If unsure, use a separate physical Mac.

## Manual evidence checklist (initial state: NOT RUN)

| Verification | Evidence required | Status |
| --- | --- | --- |
| Source integrity | pinned commit; source manifest pass | NOT RUN |
| macOS GUI | normal menu, labels, updates, quit behavior | NOT RUN |
| English | menus, troubleshooting, missing-data text | NOT RUN |
| Japanese | equivalent native views and labels | NOT RUN |
| Offline | missing/stale 5-hour and weekly quotas stay unknown | NOT RUN |
| Codex | explicit authorized test profile via official App Server | NOT RUN |
| Claude | optional official statusLine, time freshness, missing fields | NOT RUN |
| Notifications | opt-in permission; no false first-run alerts | NOT RUN |
| Login items | opt-in only; test account cleanup | NOT RUN |
| Release safety | Developer ID, notarization, Gatekeeper, migration | HOLD |

Document exact commit, OS version/architecture, each PASS/FAIL/NOT RUN,
test provenance (mock/packaged-smoke/authorized live), and limitations.
Do not publish personal account names, credential paths, usage values,
authentication redirects or raw logs containing tokens or cookies.

The four existing GitHub Actions jobs include native macOS/Intel bootstrap
and English/Japanese translations loaded from the packaged .app. They
do not validate normal GUI interaction, real account authorization,
Gatekeeper acceptance, signing, notarization or installed-app migration.

Leave Issue #15 open until the manual tests have genuinely occurred.
