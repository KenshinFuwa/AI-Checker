# Security policy

**Status:** [v1.10.1-beta.1 source-only pre-release](https://github.com/KenshinFuwa/AI-Checker/releases/tag/v1.10.1-beta.1) published on 2026-10-27 from `9c371da7b4a362ec517e4b9a9b514eda915def48` with 4/4 GitHub CI checks successful. The original RC2.3 source passed eight owner-Mac offline QA gates on 2026-10-25 (Python 115, Swift 114, native release build, Codex mock, Universal 2/temporary DMG). Public-source GUI/account validation, safe upgrades and clean-machine installation remain outstanding. No general-public Developer ID-signed/notarized application or DMG exists.

Please **do not open public issues containing credentials, cookies, tokens, server addresses, or private account details**. To disclose a vulnerability, use GitHub private vulnerability reporting when enabled, or a verified private maintainer contact method. Never post access tokens in public tickets.

## Authentication and boundaries

- Codex usage is read from the official Codex CLI App Server using an isolated profile. The repository does not contain local Codex credentials or account files.
- The public source disables undocumented Claude Web quota polling. Claude Code's official `statusLine` is the only active Claude quota source, and it may not supply values in every session.
- Official administrative API reports for optional providers are distinct from consumer chat usage. Administrative API keys must never be committed; local storage uses macOS Keychain.
- ChatGPT, Gemini, Perplexity, Cursor consumer, and Grok consumer usage are manual notes or provider-site links, not automatically obtained quota telemetry.
- Missing, expired, or stale observations must not be reported as real remaining quota. The sample percentages shown in offline UI previews are not user measurements.
- The app does not require Accessibility privileges, synthetic clicks, browser cookie/profile imports, or a background privileged helper for normal functionality.

## Source and distribution

- The public source excludes official provider logo bitmaps and private experimental integrations; generic bundled artwork is used. Provider marks remain the property of their owners.
- The repository must not include Keychain contents, authentication caches, API keys, signing private keys, or notary credentials.
- The installed maintainer's app can differ from this public beta; **never overwrite it with a preview or a test build**.
- Do not describe temporary unsigned or ad-hoc signed DMGs as trusted or notarized. A general-public installer requires a separate release gate.

## Responsible reporting

Submit a concise reproduction and the affected version without posting sensitive data. See [the source release gate report](RELEASE_GATE.md) and [distribution requirements](docs/DISTRIBUTION.md).
