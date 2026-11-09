# AI Checker v1.11.0 — DRAFT source-only release notes

**Status: NOT PUBLISHED.** Prepared for owner review against GitHub draft
PR #19. Do not turn these notes into a release announcement until all source
release gates are satisfied.

## Changes since v1.10.1 source beta

- Identical six-row account menus for Codex and Claude, in Japanese and English.
- One global **Refresh Usage** action. No redundant per-provider refresh buttons.
- Codex reconnects the official App Server transport on forced refresh and can
  recover stopped transports on periodic refresh; no fabricated 0% or 100%.
- Provider-specific configuration stays behind **Advanced Settings**.
- Claude public source uses official Claude Code statusLine only; no unpublished
  Claude website quota endpoint is implemented. Its Disconnect action prompts
  for manual /logout instead of claiming automatic sign-out.
- Bundle version and future release tool filenames are aligned to 1.11.0.

## Verification scope

Automated source SHA-256 verification, Swift core unit tests, Codex mock
integration, macOS AppKit build, Intel x86_64 bootstrap and Universal 2
unsigned temporary DMG layout are required on the exact release commit.
Owner's recorded source QA of the earlier RC1 commit cannot be reused as
evidence that this version-alignment commit was natively tested.

**Not yet validated:** clean-user GUI interactions, authorized real Codex/
Claude Code E2E, user-driven logout, release signing, Apple notarization,
Gatekeeper, and clean-machine installation.

## Availability and security

Source only. There is no Developer ID-signed or notarized DMG, and no
approved install-over-private-build migration path. The maintainer's existing
private Claude Web build is intentionally separate from this public source.
No third-party provider PNG logos or credentials are included.

The previously published v1.10.1-beta tags, assets, and history are untouched.
