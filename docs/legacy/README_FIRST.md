# AI Checker v1.9.2 — adaptive menu-bar width

The macOS menu-bar region automatically fits the selected content. `数字のみ` is shorter than `バーのみ`, and `バーと数字` uses the necessary bar and percentage space. Turning a provider off or changing the bar width also changes the status item's natural width.

The existing native cascading submenus and in-place setting changes remain in use. Menu-bar width now uses Apple's `NSStatusItem.variableLength`, not a fixed-width status-item. On a native menu Mac can reposition its anchor; verify that the open branch remains active during width changes.

## Install from Downloads

```bash
cd ~/Downloads
unzip -oq AI-Checker-v1.9.2.zip
cd AI-Checker-v1.9.2
./scripts/check.sh && ./scripts/install-local.sh
```

Build/sign/verify are performed before replacing the installed app. Preserve the existing stable signing identity and current settings. Run with no credentials passed as command arguments.

## Verify on the Mac

1. Open `表示設定 → 表示形式` and choose `数字のみ`. The highlighted menu-bar region should become compact without closing the settings hierarchy.
2. Toggle `バーのみ` and `バーと数字`; test `バー幅` short/long.
3. Verify the region contracts/expands, click targets remain correct, and Codex/Claude data and notifications remain intact.

Mac-native click results are unverified by the development container. The status item may relocate while a tracked native menu is open; report that separately if it disrupts the cascade.

## Usage-source distinction

Codex / Claude quota numbers are automatically obtained where a connected provider permits it. The five consumer chat portal entries (ChatGPT, Gemini, Perplexity, Cursor, Grok) remain official-link/manual-note only: 自動取得 is not implemented for those accounts. This UI-width release does not alter provider integrations or create fabricated quotas.
