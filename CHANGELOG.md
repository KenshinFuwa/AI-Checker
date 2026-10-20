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
