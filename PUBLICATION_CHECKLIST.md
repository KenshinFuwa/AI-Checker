# AI Checker — current publication checklist

This file supersedes the archived first-publication checklist. `KenshinFuwa/AI-Checker` has a recorded initial source publication. Historical publication scripts are disabled and fail closed; GitHub writes require restored access and explicit owner review.

## Source-only beta readiness

- [x] Project-author MIT license attribution present.
- [x] Public build disables undocumented Claude Web quota polling and excludes vendor logo bitmaps.
- [x] Original RC2.2 macOS native QA completed on 2026-10-25: eight PASS gates, 128-file manifest, Python 115 tests, Swift core 111 tests, release build, Codex mock and Universal 2 / disposable DMG layout. The original source ZIP SHA-256 is pinned in RELEASE_GATE.md.
- [x] This publication synchronization preserves the Mac-tested RC2.3 application Swift code, tests, localization, workflows and build scripts byte-for-byte. The manifest is regenerated for document changes.
- [x] On 2026-10-26 GitHub account/repository access was verified restored; `main` remains `c237d3fa`.
- [ ] Owner reviews the final proposed PR diff against current `main`, including README/security, source, permissions, and localization.
- [x] Original RC2.3 owner-Mac QA: 8/8 PASS; 115 Python / 114 Swift tests, build, Codex mock and Universal 2 checks.
- [ ] Confirm remote CI passes on the exact publication commit (which contains documentation-only changes relative to the Mac-tested RC2.3 ZIP).
- [ ] Validate actual native English/Japanese UI, Codex/Claude live data provenance and observed time using a deliberately authorized test profile.
- [ ] Create an explicitly marked **source-only prerelease**, with source archive checksum and release notes, following owner review.

## Public installer requirements (not met)

- [ ] Apple Developer ID Application signature with hardened runtime and timestamp.
- [ ] Apple notarization accepted and stapled; verify actual signed binary and DMG.
- [ ] Clean-machine tests on Apple Silicon and Intel, including Gatekeeper, login item, Keychain migration, notifications, and app behavior.
- [ ] Ensure downloads and installation instructions refer only to verified release assets.

Read [RELEASE_GATE.md](RELEASE_GATE.md), [docs/PUBLISH_PR.md](docs/PUBLISH_PR.md) and [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) before any release.
