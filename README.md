> **Release status (2026-10-24 JST):** Open-source v1.10.1 source beta is merged into `main`. GitHub Actions run `39977688759` passed all four PR checks: portable Swift source/core, native macOS build/tests, unsigned Universal 2 temporary-DMG audit, and isolated packaged AppKit bootstrap on a native `macos-15-intel` x86_64 VM. The Intel check does **not** exercise a normal installation, Gatekeeper, real accounts, notifications, or the app event loop. **No Developer ID-signed/notarized public DMG exists.** An optional manual, explicitly unnotarized test-only DMG can be produced without Apple membership; it is not an official release and may be blocked by Gatekeeper. See [free preview cautions](docs/FREE_PREVIEW.ja.md). Clean installation on physical Apple Silicon and Intel Macs remains unverified.

# AI Checker

**Native macOS menu-bar usage monitor — source-only beta (`v1.10.1-beta.1`).**

[日本語ガイド](docs/README.ja.md) · [Security](SECURITY.md) · [Build & release checklist](PUBLICATION_CHECKLIST.md) · [Changelog](CHANGELOG.md)

AI Checker shows **Codex** and **Claude** usage windows in a compact menu-bar display. It supports native cascading menus, live appearance changes, three menu-bar densities, adjustable bar/number widths, reset/depletion notifications, multiple profiles, and explicit usage data sources.

The latest source includes guarded Universal 2 release building and read-only DMG content checks. These do not replace Developer ID signing, notarization, or clean-machine testing.

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

## When the menu bar is full

- Choose **Appearance → Space & shortcut → Menu-bar display** and switch between **Standard**, **Compact** (provider icons and numbers), and **Icon only** (the AI Checker gauge).
- Press **Control + Option + Command + A** (default) to open the separate usage panel even when AI Checker is hidden in an overfull macOS menu bar. You may disable it or choose **Control + Option + Command + U** if another app uses the shortcut. The shortcut is registered with the macOS system hotkey API and requests **no Accessibility permission**.
- Use **Space & shortcut → Menu-bar organization guide** for directions to macOS System Settings and other apps' own menu-bar preferences.
- AI Checker does **not** detect every other status item's visibility, move or hide other apps' icons, or require global keyboard event monitoring. Do not claim automatic available-width detection.
- The app ships its own navy-and-teal progress-ring/check `AppIcon.icns`, not any provider's trademarked icon.

## Requirements

- macOS 13 or newer (some optional local WebKit account-management features may require newer macOS).
- Xcode Command Line Tools or Xcode with Swift 5.9+ (`swift --version`).
- Official Codex CLI where Codex integration is desired; account login may require a browser.
- Internet access and valid provider accounts to retrieve live data.

## Build from source

```bash
git clone https://github.com/KenshinFuwa/AI-Checker.git
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

The script runs Swift unit tests, Python policy/regression tests, a local Codex App Server mock and macOS native checks when running on a Mac. GitHub Actions runs **four** checks: portable Linux source/core, native macOS build and tests, unsigned Universal 2 temporary-DMG layout and packaged AppKit smoke, and separate native Intel macOS VM packaged AppKit smoke. The Linux job excludes the Codex RPC integration test; only the macOS native job runs the full `check.sh`. All four passed for PR #7 (`39977688759`). CI smoke is not proof of clean end-user installation, notarization, or complete UI operation. Real provider logins, real notification delivery and macOS menu interaction require separate interactive testing.

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

## Feature preview / contributing

The source code is already public at `KenshinFuwa/AI-Checker`. The historical `scripts/publish-github.sh` is for the initial release only; **do not rerun it**. After local macOS native checks, maintainers can run `bash scripts/propose-github-beta.sh` from a fresh extracted candidate to create a feature branch and pull request. This does not push to `main` or publish an executable. Review the GitHub Actions results before merging.

## End-user distribution

See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for guarded Developer ID signing and notarization. **No signed DMG is currently available.** The author’s successful Spotlight test required restarting the Mac’s Spotlight indexing services; the app did not fix Spotlight by itself. After an official release exists, verify its `.sha256` alongside the downloaded DMG using `python3 scripts/verify-release-checksum.py /absolute/path/AI-Checker-v1.10.1-notarized.dmg /absolute/path/AI-Checker-v1.10.1-notarized.dmg.sha256`. A checksum only checks file integrity against the supplied digest; it does **not** establish who published either file, Apple notarization, or Gatekeeper approval.

## Spotlight app discovery

After installation, the installer explicitly registers AI Checker with macOS Launch Services.
To repair an existing signed installation without rebuilding, run:

```bash
bash scripts/repair-spotlight.sh
```

Search for **AI Checker** in Spotlight (not **AIChecker.QuotaStatus.v1**, which is a window title).
If the application is still missing, inspect macOS Spotlight Applications visibility and privacy settings.
The OS controls indexing and this helper cannot guarantee search placement.

## On-demand network speed and Spotlight discovery (v1.9.6 beta)

Opening **AI CHECKER / USAGE** automatically starts network-speed measurements. The first download/upload reading appears after about 0.5 seconds; subsequent readings update once per second while the menu is open. Closing the menu stops the sampler. There is no idle polling or generated test traffic. One interface is selected to avoid VPN/physical double counting; this is not a bandwidth benchmark.

If the app installed under `~/Applications` is not searchable in Spotlight, `scripts/diagnose-spotlight.sh` checks bundle metadata and indexes only that app. For persistent non-discovery, `scripts/migrate-spotlight-app.sh` optionally migrates the signed app to `/Applications` after explicit confirmation; it may require administrator authentication. It preserves the existing bundle identifier and signing identity. Do not run it with duplicate apps already installed. Verify Spotlight results on the Mac; the source cannot override the OS search database.


## v1.9.9: on-demand speed smoothing and Spotlight

Initial speed after 0.5s; one counter read per second; a weighted 2-second average is drawn only once per 2 seconds while the USAGE menu is open. When closed, throughput polling is stopped. Spotlight search remains dependent on macOS indexing: see `START_HERE.md`.


## Menu-bar provider selection (v1.10.1)

In Display Settings → メニューバーに表示するAI, choose Codex, Claude, or configured official billing/API report connections. Newly connected services are opt-in, and missing monthly reports are shown as `—`, not guessed percentages. ChatGPT, Gemini, Perplexity, Cursor consumer, and Grok consumer have no automated personal quota readers. GitHub Copilot and API usage reports are separate monthly counters, not 5h/Week quotas. Changing providers never modifies account tokens or authentication.

## Spotlight / Finder application icon (v1.10.1)

This release standardizes the signed `.app` bundle icon (`CFBundleIconFile=AppIcon.icns`, `PkgInfo=APPL????`) and explicitly supplies the icon to AppKit on startup. This protects source packaging without changing the Bundle ID, signed identity, account storage, startup item, or quota acquisition.

The earlier Mac diagnosis showed that the icon resource and importer were valid **but that the installed app was missing from the Spotlight search index**. This is not proof that the app can repair Spotlight itself. Run `bash scripts/diagnose-app-identity.sh` after installation: it separately checks the bundle icon, Launch Services, AppKit-resolved icon, and Spotlight indexing, including comparison with system apps. No automatic whole-disk Spotlight resets or disruptive cache kills are performed.

A macOS-native build, Finder icon, Notification Center icon, and actual Spotlight UI search all require final testing on a Mac. A passing Linux/Swift core test is not a claim that the OS indexing issue has been fixed.
