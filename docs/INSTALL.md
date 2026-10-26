# Installing the source-only beta

## Quick connection to Codex

After launching AI Checker, open **ACCOUNTS** and select the **ChatGPT quick-connect** action. The in-app menu label may be localized.
If the official Codex CLI is installed in a recognized location, AI Checker
creates or reuses its **isolated Codex profile**, opens the browser-based
ChatGPT login supplied by the official Codex App Server, and reads the
available Codex usage windows after authentication. No shell command, profile
name entry, or password entry inside AI Checker is required.

If the official CLI cannot be found, the app offers the
[official Codex installation instructions](https://github.com/openai/codex)
or the option to select an already installed CLI executable. **Installing
the CLI may still be required**; AI Checker does not silently download or
execute installer scripts, alter the default ~/.codex, or promise that
ordinary ChatGPT chat quotas can be read.

## A. Developer build without touching an existing installation (recommended first)

```bash
./scripts/check.sh
swift build -c release --jobs 2
```

The compiled executable is available under `$(swift build -c release --show-bin-path)/AIChecker`. Running that raw executable from Terminal is useful for development, but it is **not equivalent to a properly bundled/signed macOS app** (notification permissions and login items may differ).

## B. Existing signed installation — local maintainer only

`scripts/install-local.sh` builds, stages and signs `~/Applications/AI Checker.app`. It requires an existing stable signing identity, checks designated requirements before replacement, preserves a backup, and launches the replacement. Do **not** use this command to replace an app from a different publisher.

```bash
./scripts/check.sh && ./scripts/install-local.sh
```

Do not create or distribute fake Developer ID signatures. Distribution to general Mac users needs a separate Developer ID signed, hardened, notarized app build.

## C. Notarized binary release (NOT PROVIDED)

This source beta does not provide a DMG/PKG or notarized build. A future release needs a real Apple Developer ID signing certificate, hardened runtime, notarization, stapling, Gatekeeper verification, and a clean-machine installation test.

## Data safety

The public source ZIP contains **no external logo PNGs**, no Keychain exports, no tokens and no local account directories. A fresh source build will use source-defined fallback glyphs. No secrets should be entered into GitHub Actions logs or checked into the repo.

## Contributing a feature beta after publication

This repository is already public. Both historical publication entry points are disabled. **Do not run** `scripts/publish-github.sh` or `scripts/propose-github-beta.sh`. Once GitHub account access has been restored, follow `docs/PUBLISH_PR.md`: review current remote HEAD, compare the candidate diff, run native QA, inspect staged files for secrets, obtain explicit owner approval, and submit one reviewed PR through standard Git tools. Do not overwrite the installed app or push directly to `main`.

New installs should show a one-time usage panel with keyboard fallback instructions. The stable updater also copies the independent `Design/AppIcon.icns` into the signed app bundle before verifying the signature.

## D. Manually generated UNNOTARIZED test preview (not an end-user release)

For a controlled test on an isolated Mac, see [the explicit risk and build instructions](UNNOTARIZED_TEST_PREVIEW.md). It uses only an ad-hoc signature and cannot establish the publisher identity. Do not overwrite an existing AI Checker app or disable Gatekeeper globally.
