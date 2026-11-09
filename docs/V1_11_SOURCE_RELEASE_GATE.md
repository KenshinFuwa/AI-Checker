# v1.11.0 public source release gate (draft)

This change prepares **source-only** public release readiness. It does not
publish a tag, install an application, sign a DMG or notarize a binary.

- Codex and Claude show the same six account actions in the same order.
- One global Refresh Usage action; remove duplicate per-provider refresh rows.
- Codex continues to use the official app-server transport.
- Public Claude uses official Claude Code statusLine only. No unpublished
  Claude Web quota endpoint or private WebKit integration is included.
- Claude Code sign-out is guided through the official interactive /logout
  command, not falsely claimed as an automatic sign-out.

Release blockers before a stable tag:
1. Review complete diff and absence of credentials/private Claude code.
2. CI passes on the exact PR commit.
3. Verify native menu interactions and both localizations on macOS.
4. Test isolated Codex login/recovery and Claude Code statusLine (including
   stale/unknown data and unavailable providers).
5. Obtain owner approval for merge and source-only stable release.

The installed private Claude WebKit build is not feature-identical to this
public-source candidate. Developer ID signing/notarization are a separate gate.
