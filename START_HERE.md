# AI Checker v1.10.1 — selectable AI providers in the menu bar

## Local Mac update (retains existing signed installation, profile preferences and Keychain)

```bash
cd ~/Downloads
unzip -oq AI-Checker-v1.10.1-complete.zip
cd AI-Checker-v1.10.1/Public
./scripts/check.sh && ./scripts/install-local.sh
```

Select from **表示設定 → メニューバーに表示するAI**. The menu stays open when choosing.
- Codex / Claude: 5h and weekly remaining quotas, with existing icons (only the currently active profile per provider).
- GitHub Copilot: opt-in current-month request count, if a billing API account is configured.
- OpenAI API: current-month organization USD costs; Cursor Team: request counts; xAI API: current-month team USD costs. These are **not** consumer chat quotas. All are opt-in and disabled unless configured. No guessing.
- ChatGPT, Gemini, Perplexity, Cursor consumer and Grok consumer: official-site/manual-note access only, not selectable as an automatic live quota meter.
- If all data meters are switched off, a minimal AI Checker launcher icon stays accessible, and the keyboard shortcut still opens the usage panel.

The full menu continues to show Codex and Claude cards and connection settings. Choosing a provider for the menu bar does **not** modify login/connection credentials. No provider is added automatically.

## Verification and limitations

Local and public source retain their respective authentication/access policies. Public source intentionally excludes experimental Claude Web usage polling and third-party brand PNG assets. Neither build includes a notarized public macOS installer. macOS AppKit native build must be confirmed on a Mac before adoption.

The known Spotlight app-search issue is NOT fixed by provider selection. The current Mac reports an application bundle and valid signature but blank `mdls` output and no matching `mdfind` index result. Do not repeatedly move the app or re-register Launch Services; Spotlight indexing is outside the app's guaranteed control.

GitHub `main` is not changed. For a proposed public-source PR **after native macOS validation**, see `Public/scripts/propose-github-beta.sh`.

## FIX01: ZIP executable-bit repair (2026-10-22)

The first publication-kit ZIP unpacked many shell scripts and the Codex mock Python server with 0644 permissions. `check.sh` therefore stopped at `Permission denied` after Swift 107/107 PASS. This was a packaging error, NOT a Codex authentication failure. FIX01 preserves executable permissions in the ZIP, runs child shell scripts via `bash`, and executes a chmod-protected **temporary copy** of the mock server. No real account or API token is used.

Run `bash scripts/propose-github-beta.sh` from the fresh Public folder. It re-runs checks before offering the `PROPOSE` confirmation; main is untouched until a PR is reviewed and merged.
