# v1.9.2 — adaptive status-item width validation

Final offline run: **PASS (exit 0)** on Linux. 103/103 Swift core tests, 40/40 Python regression checks (including installer simulation), mock Codex app-server handshake PASS, and Swift AppKit source parsing PASS. Linux checks native source syntax and core layout contracts. macOS real-time submenu tracking and content width changes remain **NOT VALIDATED** in the container.

macOS-only `--selftest-status-layout` (packaged; NOT RUN on Linux) compares measured layout widths for percentage-only, bars-only, combined, wide/compact bars, and one/two visible services.

---

# v1.9.1 validation scope

- Added offline contracts for immediate artwork preview, no mid-tracking status width changes, live checkmark redraw, and preserved notification hooks.
- `check.sh` runs the existing suite plus `Tests/test_live_settings_preview.py`.
- Local Linux `./scripts/check.sh` **exit 0** (2026-10-20): Swift core **103/103 PASS**, Python checks **38/38 PASS** (22 release + 5 consumer + 4 notification + 4 live preview + 3 installer), Codex mock handshake **PASS**, macOS Swift source syntax parse **PASS**.
- Linux `swiftc -frontend -parse` validates grammar; **AppKit native UI behavior requires Mac verification.**

---

# AI Checker v1.9.1 — validation record

Core quota notification transitions use deterministic Swift unit tests. Static
integration tests verify menu wiring and explicit permission request. The Linux
checks do not constitute a macOS UserNotifications delivery test.

To validate native macOS AppKit and notifications: run `./scripts/check.sh` on
macOS, install the app, enable a notification option, approve the system permission,
then use `通知設定 → テスト通知を送る…`. Test notifications do not imply actual quota
reset/depletion observations.

## Prior releases (historical; do not treat historical PASS as this release)

# AI Checker v1.9.1 — validation

This section reports only current-release checks; historical v1.8.1 results below are preserved as history.

- v1.8.1 log failure: old contract expected `addUnsupportedProviderSubmenu` after the function was renamed. Source and assertions corrected in v1.9.1.
- Additional source fix: helper-local `currentPeriod` for API report month check.
- Linux Swift parsing/core tests and offline Python tests: run with `./scripts/check.sh`.
- **Native macOS compilation, interactive menu actions, signed upgrade: NOT VERIFIED IN THIS ENVIRONMENT.** Run `./scripts/check.sh` on macOS before `install-local.sh`.

## v1.9.1 verified offline results (this package)

- `./scripts/check.sh`: **exit 0** (Linux).
- Swift AICheckerCore: **90/90 PASS**.
- Python release contracts: **22/22 PASS**.
- Python consumer UI contracts: **5/5 PASS**.
- Python offline installer: **3/3 PASS**.
- Codex mock handshake / quota: **PASS**.
- Swift source parse: **PASS**; AppKit build/typecheck: **NOT TESTED** (macOS required).

## Historical v1.8.1 release notes (superseded)

# Historical source: Validation — AI Checker v1.8.1

## Scope and proof status

- Existing v1.7.3 code used as base.
- Added 5 official web entry points + 5 isolated WebKit sessions and per-provider explicit erasure.
- Added manual observation notes, local timestamps, validation, and **no conversion into automatic quotas**.
- Linux: `swiftc -frontend -parse` checks syntax only; `swift test` checks AICheckerCore.
- `scripts/check.sh` includes Python static/behavior contract tests, Swift core tests, and native macOS checks when executed on Mac.
- NOT VALIDATED on Mac until the user runs the provided installer/check.sh.
- Consumer residual quota automatic fetch: NOT IMPLEMENTED; no official stable reader verified.

---

macOS Native menu click behavior: NOT YET VERIFIED, requires actual Mac.

## Base regression — AI Checker v1.7.1

## Independently observed (Linux)

- Swift core unit tests: **87 PASS / 0 FAIL** (`swift test --jobs 2`).
- Python release / security source assertions: **22 PASS / 0 FAIL**.
- Offline installer simulations: **3 PASS / 0 FAIL**.
- WebKit quota-script mock: **PASS** (Node.js, local mock only).
- Codex App Server mock handshake/login/quotas: **PASS** (offline).
- Shell syntax and Swift macOS-source syntax parsing: **PASS** (`swiftc -frontend -parse`).
- SHA256 source inventory and zip integrity: check during packaging.

`./scripts/check.sh` runs the above checks; `swift test --jobs 2` avoids resource contention from unlimited parallelism on the delivery environment.

## Not independently verified (requires the user's Mac)

- macOS AppKit/WebKit **typecheck**, native build, layout, window focus, menu behavior, signing and activation.
- Real connection to Codex, Claude, GitHub Copilot, OpenAI API, Cursor Team or xAI API.
- Real Keychain prompts, update-in-place and login item registration.

This release reuses v1.6.9 connection/adapters and credentials handling; it changes the user interface wiring only. No credentials or cookies are packaged. Testing all native UI interactions on macOS is required before calling this release fully validated.

## v1.7.1 regression update

- Restored omitted `changedClaudeProfile` identical to v1.6.9.
- Added explicit tests for callback presence/Claude cache reset and manual PNG packaging.
- PNGs excluded from SwiftPM target: installer still includes them in signed app bundle.
- Native macOS typecheck remains an external requirement (Linux `swiftc -frontend -parse` is syntax-only).

## Final offline validation (this package)

`./scripts/check.sh`: **exit 0**. Swift core 87/87 PASS, release/source regression 22/22 PASS, installer offline 3/3 PASS, Codex mocked handshake/login/quotas PASS. Native AppKit type checking is NOT verified on Linux.

## v1.7.3 interaction audit

- Regression checks cover custom root refresh, login-item settings handoff, in-place enabled state, service-catalog submenu hierarchy, Cmd+R fallback and unchanged secure account flow.
- In the developer's Linux environment, Swift syntax parsing and Swift core tests can pass but do **not** validate native AppKit action dispatch or menu tracking.
- User reports v1.7.2 branching display-settings click behavior worked; v1.7.3 extends the same mechanism. This is not evidence of v1.7.3 macOS runtime behavior.

## Historical v1.8.1 results (local container, 2026-10-20)

- `bash scripts/check.sh`: **exit 0**.
- Swift core tests: **90/90 PASS** (including 3 new first-party portal/note contracts).
- Python release static checks: **22/22 PASS**.
- Python five-portal safety/source checks: **5/5 PASS** (updated for v1.9.1).
- Offline installer simulations: **3/3 PASS**.
- Codex mock App Server: **PASS**.
- AppKit/WebKit native compilation, embedded Google/login compatibility, 5-site authenticated quota responses: **NOT TESTED**.
- User should report Swift errors from `check.sh` on macOS; no claim of five live auto-quota feeds.

## v1.9.1 local verification — 2026-10-20

- `./scripts/check.sh` **exit 0** on Linux (Swift 6.2.1, x86_64).
- **Swift AICheckerCore 103/103 PASS**, including 13 quota-notification transition tests.
- **Python 34/34 PASS** (22 release, 5 consumer, 4 notification, 3 installer).
- Swift syntax parse of `Sources/AIChecker/*.swift`: PASS.
- Codex app-server isolated mock: PASS.
- **macOS native AppKit/UserNotifications typecheck, OS permission dialog,
  actual reset/depletion banners, signing and runtime: NOT VERIFIED HERE.**
