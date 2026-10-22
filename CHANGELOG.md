## v1.10.1 — source release clarity and checksum integrity gate

- Corrected stale release-status claims in English/Japanese README after GitHub merges and green macOS CI.
- Added standalone SHA-256 asset checksum verification with strict path and record parsing, no network or disk writes.
- Added integrity tampering tests and invoked the verifier in the guarded notarized DMG builder.
- Checksum integrity does not prove publisher authenticity or Apple notarization; binary release remains HOLD.

## v1.10.1 — distribution QA hardening (source only)

- Added shared Universal 2 app staging and read-only mounted DMG layout audit.
- CI audits disposable **unsigned** app/DMG geometry without uploading installers.
- Signed distribution script re-audits the actual **notarized** and stapled DMG before copying to `dist/`.
- Does not change AI Checker runtime behavior, user settings, credentials, or bundle ID.
- Developer ID and notary credentials remain required; no public binary release created.

## v1.10.1 — Spotlight and icon recognition audit

- Standardized explicit `.icns` resource, conventional `PkgInfo`, and signed-bundle preflight.
- Load bundled icon in AppKit at startup.
- Added macOS read-only Launch Services/AppKit icon/Spotlight cross-check (includes system-app baseline).
- Keep same bundle ID and settings. Does not claim to override macOS indexing or cached notifications.

## v1.10.1: Select AI providers in menu bar

- Stay-open Display Settings → メニューバーに表示するAI selector. Codex/Claude are independent, with existing profiles unaffected.
- Opt-in connected official billing reports: GitHub Copilot, OpenAI API, Cursor Team and xAI API; values are monthly billing/requests, not 5h/week chat quota.
- API-only selection remains accessible; falls back to app launcher icon when no usable report is available.
- Public source still excludes experimental Claude Web quota access and third-party PNG logos.

## v1.9.9 — 2-second network averaging and notification diagnostics

- USAGE menu: first reading after 0.5 s; sample every second; publish weighted 2-second average after each two subsequent samples. Stop entirely when menu closes or Mac sleeps.
- Notification Settings: system permission, display style, sound and Notification Center diagnostics, plus test-delivery error reporting. Both alert kinds remain opt-in; do not fabricate quota events.
- Spotlight: no user-facing index-reset requirement; see user-facing troubleshooting notes. Search inclusion is managed by macOS and not guaranteed by an installer.

## v1.9.9 — weighted 2-second speed display and Spotlight diagnostics

- Root USAGE menu: initial network reading after ~0.5 seconds. Every 1 second thereafter the local interface counters are sampled. Every three intervals, a weighted 2-second average replaces the prior speed display. Close/sleep cancels the timer; no background speed polling.
- Changed/missing interfaces invalidate the averaged window rather than mixing counters.
- Spotlight diagnostic checks native application metadata importer output separately from indexed search results; macOS settings and Apple's targeted `/Applications` reindex procedure are documented. Spotlight search success is NOT presumed.
- Local/private Claude Web integration is retained only in the Local build; the GitHub Public build keeps it disabled.

## v1.9.7 — isolated installation regression tests and Spotlight verification

- Fixed offline installer tests to use a synthetic system Applications directory instead of reading the real Mac's `/Applications`.
- Verified user install, signed system install after migration, signature mismatch, build failure, and dual-install refusal without touching installed applications.
- The production installer still targets `/Applications/AI Checker.app` after migration, and preserves existing signing checks and backup/rollback behavior.
- Spotlight search is **not declared resolved** until the actual Mac shows AI Checker in application search results; successful Launch Services registration alone is insufficient.
- Retains v1.9.6 network speed measurement and all quota/notification behavior.

## v1.9.7-beta.1 — automatic menu-scoped network speed

- Measure automatically when the USAGE menu opens; first counter delta after ~0.5 s, then every 1 s while open.
- Stop sampling immediately when the root menu closes, on system sleep, or on app shutdown; ignore stale callbacks.
- Keep one timer for the menu session; no network-speed polling while idle or extra external traffic.
- Preserve Codex/Claude usage, macOS notifications, UI and safe app installer.
- macOS native menu tracking/type check requires validation on the user’s Mac.

## v1.9.7-beta.1 — macOS Carbon build fix

- Fixed `GetEventParameter` buffer size argument to use macOS Swift `Int` (`MemoryLayout<EventHotKeyID>.size`) instead of `UInt32`.
- Removed accidental `main.swift.orig` from the local SwiftPM target.
- Added regression checks for native Carbon import types and unhandled source backups.
- Preserved existing account IDs, Keychain state and `AIChecker.v193.*` settings keys.
- Native macOS AppKit build remains a required final check before installing or proposing a GitHub PR.

## v1.9.7-beta.1 — menu-bar overflow fallback & original app icon (candidate)

- User-selected Standard / Compact / Icon-only status item rendering without modifying other apps.
- Global macOS Carbon system hotkey (⌃⌥⌘A or ⌃⌥⌘U) opens an on-demand, independent usage panel. No Accessibility permission or keyboard event tap.
- One-time onboarding panel, keyboard shortcut opt-out, help for cleaning up the menu bar.
- Source-owned navy/teal AppIcon.icns and 1024px PNG added to the bundled app resources.
- No change to Codex usage source, public Claude Code statusLine, API authentication, or notification logic.
- macOS interactive verification and CI required before publishing a release.

## v1.9.2-beta.3 — public GitHub publication candidate

- Disabled non-public Claude Web usage polling from distributable source; retains Claude Code statusLine integration.
- Documented public/local feature differences and current provider terms.
- Added guarded GitHub publish script for the owner and macOS checks.
- Updated licensing, publication audit and public source tests.

# Changelog

## v1.9.2-beta.2 — author attribution confirmed

- Updated MIT copyright notice to `Copyright (c) 2026 Kenshin Fuwa` with the author’s explicit authorization.
- Updated publication documents and regression tests to reflect confirmed ownership.
- No runtime functionality changes.

## v1.9.2-beta.1 — first public-source preparation

- Public-source distribution separates the code from locally bundled third-party PNG assets; vector fallbacks keep the menu rendering operational.
- Added bilingual repository README, clear scope matrix, security policy, release checklist, and source-only install guide.
- Updated Swift package and local installer to tolerate absent optional assets.
- Preserved existing MIT attribution for rights-holder confirmation before publishing.
- No changes to quota parsing, authentication, notification logic, or layout geometry from v1.9.2.

## v1.9.2 — adaptive-width status item (historical local version)

- Content-dependent status item width; numeric-only, bar-only, and bar+number layouts.
- Cascading menus stay interactive with immediate updates.
- Reset/depletion notifications, opt-in API reports and per-provider manual notes retained.

Full historical development records: [docs/legacy/CHANGELOG.md](docs/legacy/CHANGELOG.md).
