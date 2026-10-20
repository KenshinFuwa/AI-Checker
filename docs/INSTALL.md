# Installing the source-only beta / インストール

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

## First GitHub publication by repository owner

Run `bash scripts/publish-github.sh` from this extracted public-source folder.
It validates source and macOS compilation, previews staged files and, after
explicit confirmation, creates `KenshinFuwa/AI-Checker` and pushes the tag.
It does not install or overwrite the locally working AI Checker app.
