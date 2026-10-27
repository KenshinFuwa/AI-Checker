# AI Checker v1.10.1-beta.1 — published source-only prerelease

**Published on 2026-10-27.** [GitHub Release](https://github.com/KenshinFuwa/AI-Checker/releases/tag/v1.10.1-beta.1) targets commit `9c371da7b4a362ec517e4b9a9b514eda915def48` (4/4 exact-commit CI success). Source code only: no Developer ID-signed/notarized DMG or supported end-user installer is included.

## What is included

- Native macOS menu bar dashboard for Codex and Claude 5-hour/weekly windows, when supported, fresh observations are available from official provider sources.
- macOS language-aware Japanese and English application UI, provider profile selection, optional quota notifications, multiple menu-bar layouts and a shortcut-accessible usage panel.
- Codex integration via the official Codex CLI App Server with separate account profiles; Claude quota via official Claude Code `statusLine` when available.
- Additional optional provider administrative cost/billing reports and manual consumer-service links/notes; administrative usage is **not** a consumer chat quota.
- Updated English-only repository documentation; Japanese application localization is retained.

## Security and limitations

- The public build has no automated undocumented Claude Web quota reader, and does not fabricate missing/stale usage data.
- Offline demo percentages are not authenticated quotas. Connecting real accounts is opt-in and must be tested separately.
- Existing signed AI Checker installs must not be replaced by an experimental preview. User profile, Keychain, login-item and notification migration has not been verified.
- Universal 2 compile and temporary-DMG layout QA are not equivalent to Gatekeeper, notarization, or a real clean installation.

## Validation evidence

On 2026-10-25 the owner-Mac **original RC2.2** QA passed eight recorded gates, all with zero exit status: 128-file source manifest, Python 115 tests, Swift core 111 tests, native macOS release build, Codex App Server isolated mock, and arm64/x86_64 Universal 2 disposable DMG structure. Original source archive SHA-256: `0af554fdcacd4e9c3d5b2fbdcd69dc9de4874626578fdda4b97ccfb1fecbe990`.

The historical `RC2.2-docsync1` candidate updated only documentation and its source SHA-256 manifest. It has a **different archive hash** and was not the binary that underwent Mac QA. Native UI interaction, authenticated public-source telemetry, safe upgrades and Developer ID notarization remain unvalidated.

### RC2.3 owner-Mac QA and restored GitHub access (2026-10-26)

The owner-Mac **RC2.3** QA report `AI_CHECKER_RC23_QA_RESULT_AI_CHECKER_RC23_QA_axdn0evb.zip` confirms eight PASS gates with zero exit codes, including 115 Python and 114 Swift core tests, native macOS release build, isolated Codex App Server mock, and arm64/x86_64 Universal 2 disposable DMG structure. Tested source archive SHA-256: `c3f2ce23e1cfb0d499a200dd9f24c80a6565c6c5392f5218b700865cbe386e4c`. Codex boolean-as-number rejection and capped Claude sanitized-cache reads are included in this tested candidate.

After PR #11 was merged, GitHub `main` advanced to `9c371da7b4a362ec517e4b9a9b514eda915def48`. All four exact-commit CI checks succeeded and source pre-release `v1.10.1-beta.1` was published on 2026-10-27. Documentation-only publication updates have a different source checksum from the original Mac-tested ZIP. Native UI/real-account behavior, signed installation, safe upgrades and notarization remain unvalidated for general-public binary distribution.

### RC2.1 prepublication safety guard (unreleased)

Historical GitHub publishing entry points refuse to run. No application runtime code or quota collection behavior changed. The subsequent RC2.3 source-only beta was published after owner review and exact-commit CI success.
