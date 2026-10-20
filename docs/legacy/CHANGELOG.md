## v1.9.2 — native adaptive menu-bar width

- The highlighted status-item region now follows the actual image width, rather than retaining a previous long fixed width when switched to numbers-only.
- Uses Apple's `NSStatusItem.variableLength` and the measured `StatusArtwork.layout` for each combination of visible AI services, name format, bar width and metric style.
- Updates the button image and intrinsic content size immediately; removes the old reduced artwork in a fixed slot.
- Keeps the original native cascading submenus, in-place settings, quota alerts, connection logic, and credentials unchanged.
- Native AppKit layout smoke test `--selftest-status-layout` verifies natural widths on macOS.
- **Limitation:** AppKit may reposition the status item during an open native menu; submenu persistence when its anchor moves must be checked on a real Mac. Mac-native build and click testing are not verified in the Linux packaging environment.

## v1.9.1 — immediate in-menu appearance preview

- Updates status-bar artwork at every appearance change while the nested menu remains open, rather than waiting for its dismissal when the selected style needs a different width.
- Keeps `NSStatusItem.length` unchanged during native menu tracking to preserve the branch. When the newly rendered art is too wide, it is temporarily scaled to fit; final natural width is applied after menu closure. The visual change is immediate, but the physical status-item width is intentionally finalized upon menu close.
- Forces synchronous redraw of selected-row checks and image-only status-bar buttons.
- Adds 4 offline UI-contract tests; preserves quota notifications, account/session storage, refresh cadence and login behavior.
- Native macOS interaction remains an explicit final verification gate.

## v1.9.1 — optional native quota notifications

- Added native macOS notification menu with independent opt-in reset/depletion
  switches and a test action; keeps the stay-open native submenu architecture.
- Fresh observed Codex/Claude quota samples only, both 5-hour and weekly windows.
- Account-keyed, persisted, deduplicated observation state; no speculative alerts.
- No extra polling, cloud service, additional login or changes to Keychain tokens.
- Unit tests for depletion, reset-epoch change, stale/replayed data, permission
  defaults, account isolation and restart persistence.
- NOTE: native AppKit/UserNotifications build and permission flow require macOS.

---

## v1.9.1 — merged catalog hotfix and macOS scope repair

- Updated service-catalog regression contracts to assert the new `addConsumerProviderSubmenu` and `addExternalAPIProviderSubmenu`, not removed legacy menu names.
- Restored all 5 personal-site links via the system default browser only; no embedded-browser menu, no status-label clutter, and no duplicate API management entry.
- Fixed the `currentPeriod` reference inside the external API submenu by computing the UTC month locally; avoids an AppKit compile-time unresolved identifier.
- Updated documentation, release manifest, and safe re-extraction command (`unzip -oq`). No account/Keychain/Claude data migration or automatic clearing.
- Actual macOS UI/compilation still requires confirmation on the user's Mac.

## v1.8.0 — consumer AI official web portal and explicit manual observations (historical)

- Five first-party websites available in nested menus: ChatGPT, Gemini, Perplexity, Cursor and Grok.
- Opt-in provider-isolated WKWebView session, separate WebKit data stores on macOS 14+, ephemeral on macOS 13. No cookie reading, private API calls, or background polling.
- Explicit system-browser shortcut, separate user-transcribed 120-character observations with timestamps and expiry labels. No invented quota or integration into automatic usage bars.
- Delete a provider-specific embedded browser session on explicit confirmation. Original nested stay-open menus preserved.
- New offline unit and contract tests; still requires native macOS verification.

# AI Checker v1.7.3 — stay-open actions across sections

- Added stay-open root refresh and login-item handoff rows, plus dynamic availability for Codex/Claude/Copilot/API actions and nested connection/help catalog. Kept native Quit and essential OS/auth/confirmation dialogs.

- Reverts the v1.7.0 separate settings/accounts windows as an interaction choice.
- Restores native branching submenus for display settings and Codex/Claude/API/account management.
- In-place display options use custom NSMenuItem views, which receive mouse events without invoking normal menu selection/dismissal; the open submenu stays on screen for consecutive changes.
- Root menu replacement and status-item resizing are deferred during NSMenu tracking, avoiding menu dismissal on redraw or timer callbacks.
- Appearance checkmarks re-evaluate after choices, with immediate settings persistence.
- Connected-only GitHub Copilot management visibility and existing credentials unchanged.
- Authentication dialogs and external browser flows inherently open separate UI; this is not a separate preferences window.
- AppKit typecheck and actual menu interaction MUST be verified on macOS (Linux parsing/core tests cannot guarantee native behavior).

# AI Checker v1.7.1 — macOS compile fix

- Restored `changedClaudeProfile()` removed by mistake in v1.7.0: on selection/add/removal, reset Claude provider health, rebuild the correct isolated WebKit session, clear the previous profile's displayed snapshot, force refresh and redraw. Identical behavior to v1.6.9.
- Excluded `Assets` from the Swift Package executable target because these PNG files are manually copied to signed app `Contents/Resources` by the installer. No missing PNG assets at runtime.
- Added regression guards for the missing function, profile switching, and asset declarations.
- Capped release-build parallelism (`--jobs 2`) to make diagnostics less noisy.
- Same Bundle ID, signature policy, settings, credentials, and UI as v1.7.0.
- macOS AppKit **type checking / compilation still requires a Mac**; Linux tests are not evidence of a successful native build.

---

# AI Checker v1.7.0 — persistent settings & account manager

- GitHub Copilot account management is displayed in the main menu **only when** stored credentials exist and personal-billing API access is explicitly enabled. No inference of connection from a catalog entry.
- Removed the redundant “表示設定を続けて変更…” menu item.
- “表示設定” directly opens the existing modeless settings panel. Changes autosave, panel stays open, and login-at-startup can be changed in the same panel.
- Codex, Claude, Copilot, additional API account management, and “AIサービスを追加…” use a new modeless connection manager. Buttons reuse the previous security-sensitive connection and logout workflows, without changing Keychain or website storage.
- Original quota cards, icons, color mapping, 5h/weekly displays, provider polling, Keychain identifiers, bundle identity, and upgrade flow are unchanged.
- macOS native build and interactive rendering require testing on the user's Mac; Linux validates only syntax, core logic, and offline contracts.

---

# AI Checker v1.7.0 — additional official API usage connectors

- Kept v1.6.8's aligned, colorful Codex / Claude dashboard unchanged.
- Implemented opt-in official OpenAI API organization costs (month-to-date USD).
- Implemented opt-in Cursor Team Admin daily agent request reports (month-to-date requests).
- Implemented opt-in xAI API team usage analytics (month-to-date USD).
- Never interpret these reports as ChatGPT/Cursor/Grok consumer quota percentages.
- Separate Keychain services for each connection; no shared/default provider login.
- New native account configuration, manual refresh and disconnect controls.
- 15-minute polling, 1-hour report freshness threshold, existing sleep/wake handling.
- Strict parsing rejects incomplete pagination/limitReached and malformed values.
- Added 6 Swift core regression tests; existing visual, billing, installer and Codex tests retained.

# AI Checker v1.6.8 — precision-aligned quota dashboard

Base: **v1.6.7**, modified in place. Codex / Claude account acquisition,
profile isolation, login sessions, refresh scheduling, signing, bundle ID,
status-item bitmap, and macOS install-and-relaunch workflow are unchanged.

## New in v1.6.8

1. The `RESETS IN` column header and both duration values now share one
   **right edge** (`durationRightX`); the old 454pt independent header x
   coordinate is gone.
2. Codex and Claude title text and packaged icon rectangles now use the
   **same measured vertical centerline**. Text centering uses actual font
   layout-box height rather than guessed baselines.
3. Each row's label, bar, percentage and countdown share one row centerline;
   no independent text y offsets remain.
4. Shared alignment anchors live in `UsageMenuPresentation` with unit tests,
   and source-level regression checks guard against reintroducing magic offsets.
5. v1.6.7 bright lime/orange/yellow/red palette, 215pt meters, 580×120pt
   cards and safe automatic app upgrade are retained unchanged.

No service networking, authentication, persistence, permissions, or rate-limit
calculation code was changed. Native AppKit rendering and signing must be
confirmed on macOS; Linux tests cannot prove native visual output.

---

# AI Checker v1.6.8 — refined cards, vibrant colors, automatic safe upgrade

Base: **v1.6.6**. Existing provider networking, profile storage, passwords/cookies,
status-bar geometry, service manager integration, and one-minute power-aware
refresh code remain unchanged.

## Changes

1. One-card-per-provider layout now has exactly two aligned rows (5 hours and
   Week). Each row includes the full 215pt meter, independent percentage, and
   exact English reset countdown. Only a single `RESETS IN` caption appears.
2. Card is 580×120 pt. No 2-column provider split; no duplicate 5h/Week labels.
3. Replaced nearby-looking quota bands with high-chroma lime/orange/yellow/red.
   No provider tint settings affect the bars.
4. Native root menu gains unobtrusive account/appearance/sync section labels,
   SF Symbol navigation icons, and clearer details navigation.
5. Persistent settings panel now groups native controls on rounded cards with
   consistent alignments, stronger visual hierarchy and automatic saving.
6. `install-local.sh` now builds/signs/verifies before closing the installed app,
   then replaces and automatically reopens it. Does not use wildcard process
   kills, and preserves stable bundle signing requirement and previous app backup.
7. Offline mocked installer tests and pure Swift layout non-overlap invariants.

## Constraints

- Card menu width becomes **580pt** to preserve the readable right-column
  countdown *and* 215pt meter; this is distinct from the compact status-item
  width, which remains unchanged.
- The native NSMenu may close after a selection (macOS behavior); a dedicated
  modeless settings panel is still provided for consecutive choices.
- All native visual checks and actual codesign updates require user Mac testing.
