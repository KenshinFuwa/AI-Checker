# AI Checker

**Native macOS menu-bar usage monitor — source-only beta (`v1.9.2-beta.3`).**

[日本語ガイド](docs/README.ja.md) · [Security](SECURITY.md) · [Build & release checklist](PUBLICATION_CHECKLIST.md) · [Changelog](CHANGELOG.md)

AI Checker shows **Codex** and **Claude** usage windows in a compact menu-bar display. It supports native cascading menus, live appearance changes, adjustable bar/number widths, reset/depletion notifications, multiple profiles, and explicit usage data sources.

This is an **independent, unofficial project**. It is not affiliated with, sponsored by, or endorsed by OpenAI, Anthropic, or other providers.

## Capabilities

| Feature | Scope |
| --- | --- |
| Codex | 5-hour / weekly usage where the official Codex App Server provides it, using an isolated profile |
| Claude | 5-hour / weekly usage **only when official Claude Code statusLine supplies it**. Undocumented Claude Web quota polling is deliberately disabled in this public release |
| macOS notifications | Reset confirmed by new data; quota depleted. Opt-in; duplicate suppression |
| UI | Native menu-bar view, content-responsive width, stay-open cascading settings, distinct usage colors |
| GitHub Copilot | Optional personal **billing** usage; *not* 5-hour/weekly quota |
| OpenAI API / Cursor Team / xAI API | Optional official **administrative usage/cost** reports; not consumer chat quota |
| ChatGPT / Gemini / Perplexity / Cursor consumer / Grok consumer | Open provider sites in your default browser; optional manual notes. **No automated usage acquisition** |

Unknown or stale usage is not displayed as a fabricated percentage. Notifications only apply to monitored, automatically reported Codex/Claude account windows.

## Requirements

- macOS 13 or newer (some optional local WebKit account-management features may require newer macOS).
- Xcode Command Line Tools or Xcode with Swift 5.9+ (`swift --version`).
- Official Codex CLI where Codex integration is desired; account login may require a browser.
- Internet access and valid provider accounts to retrieve live data.

## Build from source

```bash
git clone https://github.com/KenshinFuwa/AI-Checker.git  # after this repository is published
cd AI-Checker
./scripts/check.sh
swift build -c release --jobs 2
```

**Run locally**: To use the app as a menubar bundle, follow the macOS installation instructions in [the Japanese/English install guide](docs/INSTALL.md). The maintainers' original `scripts/install-local.sh` is intended for **existing locally signed installs** and requires the same trusted code signing identity; it will not silently replace an app signed differently. Do not share API tokens or signing certificates.

There is **no notarized `.dmg` / public installer** in this source-only beta. Do not represent a local ad-hoc build as notarized.

## Verification

```bash
./scripts/check.sh
```

The script runs Swift unit tests, Python policy/regression tests, a local Codex App Server mock and macOS native checks when running on a Mac. CI also runs this script on GitHub-hosted macOS. Real provider logins, real notification delivery and macOS menu interaction require separate interactive testing.

## Data and privacy

- The source does not ship credential stores or authentication data.
- Sensitive official API tokens are explicitly entered by the user and stored locally in macOS Keychain; the UI does not print them.
- Separate provider account directories are used. Removing a local key does not revoke it on the provider.
- Manual notes are not official usage telemetry.

Read [SECURITY.md](SECURITY.md) before connecting administrative APIs or publishing forks.

## Branding and license

The public build uses source-defined generic vector glyphs, **not** bundled official provider logo images. Product names and marks belong to their owners.

Copyright © 2026 Kenshin Fuwa. Released under the [MIT License](LICENSE), as confirmed by the project author. Check [PUBLICATION_CHECKLIST.md](PUBLICATION_CHECKLIST.md) for the remaining publication gates.

## Public-source differences

The local/private v1.9.2 app and this source-only public beta are **not feature-identical**. This repository **does not** include live access to undocumented Claude Web quota endpoints. Official Claude Code `statusLine` remains available where its supplied fields permit quota reporting. A local install may display no Claude percentage until statusLine data is present. See the [provider terms](https://www.anthropic.com/legal/consumer-terms).

## Maintainer publication

On macOS, from the extracted source directory, run `bash scripts/publish-github.sh`. It performs macOS validation and a guarded `gh repo create` for `KenshinFuwa/AI-Checker`, using a GitHub-generated `noreply` author email (repository-local setting only). The process will explicitly request confirmation before creating a **public** repository and pushing its source-only beta tag.
