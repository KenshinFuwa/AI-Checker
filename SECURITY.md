# Security policy

**Status:** source-only beta; current published main is `v1.9.2-beta.3`, and `v1.10.1` is a proposed update, not yet independently audited.

Please **do not open public issues containing credentials, cookies, tokens, server addresses, or private account details**. If you suspect a vulnerability, contact the repository maintainer privately using GitHub's private vulnerability reporting (when enabled) or another verified private contact method.

This public source archive does not include API keys, auth caches, local app bundles, or provider logo PNGs. The local source build still handles sensitive API administrator keys; use only on devices you trust.

## Authentication & security boundaries

- Codex uses official CLI App Server with an isolated account directory. This source distribution does not copy your `~/.codex` contents.
- The public source distribution **does not make Claude Web private/undocumented API calls**. Claude Code statusLine is the only Claude quota source shipped as active. The local experimental build is not identical.
- Copilot and OpenAI/Cursor Team/xAI official API reports may need high-privilege credentials. API usage reports **are not consumer chat limits**. Keys are stored in the macOS Keychain, and are not shipped with this repo.
- This is not a password manager. You are responsible for revoking keys at the issuing provider if compromised.
- ChatGPT, Gemini, Perplexity, Cursor consumer and Grok consumer usage remain **manual notes** and website links; there is no automated quota reader for these.
- Notifications require macOS permission and cannot deliver while the app is not running. Observations must be fresh; no invented quotas or reset-time-only notifications.
- No Accessibility permissions, synthetic mouse events, browser profile/cookie database imports, or background helper are required.

## Publishing boundaries

- Provider names refer to their respective owners and do not imply endorsement.
- Official provider logos and other proprietary artwork are deliberately **excluded** from the public repository. The public build uses bundled-source vector fallbacks.
- Do not publish signed builds from a personal Keychain or your signing-identity files.
- The project author has confirmed ownership and authorized the MIT copyright notice: **Copyright (c) 2026 Kenshin Fuwa**. This confirmation does not supersede any separate third-party rights.

## Responsible disclosure

Please share minimal reproduction steps and affected versions without attaching any secrets. Do not post screenshots exposing account identifiers or private URLs.
