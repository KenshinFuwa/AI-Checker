# Claude usage source — public source beta

This public source beta uses **first-party Claude Code `statusLine` JSON**, not undocumented Claude Web browser usage endpoints. The Claude Web client in this public source has no network polling implementation. The privately installed AI Checker application and public source build may therefore show different Claude availability.

## Supported input

Claude Code optionally sends `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage`, and their Unix `resets_at` timestamps to a configured `statusLine` command. See [Claude Code's official statusLine documentation](https://code.claude.com/docs/en/statusline). These fields can be unavailable before an API response, for unsupported account types, or independently after a window reset. A `spend_limit` is a different meter and must never be interpreted as subscription remaining percentage.

AI Checker derives `remaining = 100 - used` only for numeric usage in `[0,100]`. Missing, expired or malformed windows are unknown (`—`), **not** 0% or 100%. A saved sanitized observation is only displayed as recent for a limited time; seeing `Connected` is not evidence that it is fresh. A first-party `statusLine` observation is not the same thing as a new server request every minute.

## Privacy and isolation

The statusLine helper accepts a dedicated profile UUID and extracts only percentages, reset timestamps and capture time. It does not persist the original JSON, session IDs, transcript paths or prompts. JSON input is bounded to 256 KiB. The helper's dedicated profile does not rewrite the user's global Claude Code statusLine settings. Invalid/oversized input must not replace the last valid cached record.

## Limitations and public claims

- Codex official App Server integration and Claude Code `statusLine` are **different data sources**.
- Public source beta **does not claim** parity with the private app's experimental Claude Web feature.
- Do not promise always-on Claude subscription quota updates, automatic recovery without a live Claude Code session, or model-specific limit data that is absent from `statusLine`.
- Tests with synthetic JSON prove parsing and sanitization, **not** live Claude authentication or official source availability on an end-user Mac.
- GitHub publication and notarized distribution remain on hold until their separate gates are met.
