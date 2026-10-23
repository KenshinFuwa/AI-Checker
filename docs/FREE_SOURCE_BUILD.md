# Build and test AI Checker for free on your own Mac

This repository can be built and tested with Apple's free Xcode tools.
**You do not need to purchase an Apple Developer Program membership to
develop or run your own source build.** No paid services, Developer ID
certificate, notarization credentials, or private signing keys are required
for the steps below.

## Prerequisites

- macOS 13 or later, with the Xcode or Command Line Tools Swift toolchain.
- Terminal, Git, and Python 3.
- Official Codex CLI if you want to use Codex account authentication.
- Official Claude Code if you want to use Claude Code's statusLine integration.

Obtain Xcode from Apple or install Command Line Tools using
`xcode-select --install`. These tools are available without paid developer
membership.

## Offline validation and source build

Clone the **published branch or release under test**, inspect the source,
and run the following commands from the checkout:

```bash
python3 scripts/verify-source-manifest.py
bash scripts/check.sh
swift build --jobs 2 -c release
```

To execute the **development binary only**, run:

```bash
"$(swift build -c release --show-bin-path)/AIChecker"
```

The raw executable is intended for development and is **not equivalent to
a bundled, Developer ID-signed and notarized macOS app**. In particular,
per-app language selection, native notification identity, and login items
need a proper `.app` bundle. Do not judge native language switching from
the raw development executable alone.

For non-installing AppKit and Universal 2 bundle checks, run:

```bash
bash scripts/check-universal-build.sh
```

This stages a temporary, unsigned application and disposable DMG, audits
their resources, and deletes the artifacts. It does **not** install a
second AI Checker or replace anything in `/Applications`.

## What is not included

There is no public, Developer ID-signed or Apple-notarized DMG in this
free source beta. macOS Gatekeeper cannot verify publisher identity for
an ad-hoc or unsigned build as it would for a Developer ID release.
Do not disable Gatekeeper globally or remove quarantine attributes as
an installation workaround. A source build is not a security audit.

In particular, do not run `scripts/install-local.sh` merely to test this
beta. That tool is for a maintainer with an existing stable local signing
identity and may replace an installed app after verifying its identity.
Existing app data, Keychain secrets, and account profiles should remain
untouched during source validation.

All repository documentation is written in English; Japanese content in
`Localization/ja.lproj` is part of the application's UI translation data.
