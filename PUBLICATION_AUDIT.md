# AI Checker public-source audit — 2026-10-20

## Evidence from this preparation pass (v1.9.2-beta.3)

- Base: locally supplied `AI-Checker-v1.9.2.zip` (original release retained separately by the user).
- Scope: repository-source preparation; public build excludes binary provider logos; app quota business logic unchanged.
- Automated Linux validation: `bash scripts/check.sh` **exit 0**.
- Swift core tests: **103/103 PASS**.
- Python suites: **47/47 PASS** (7 public release + 22 release invariants + 5 consumer + 4 quota notifications + 6 sizing/preview + 3 installer). Counts can be verified from the full log or by rerunning; do not treat them as macOS system integration tests.
- Codex mocked App Server integration: **PASS**.
- Swift AppKit source *parser* on Linux: PASS; native typecheck/build on macOS: **not performed for the modified public-source distribution**.
- Source privacy pattern scan: PASS for tested patterns, not a formal secrets audit.
- No vendor PNG files, no built binaries, no signing certificates, and no auth exports are included in the public ZIP.

## Open gates before public GitHub visibility

1. **CLEARED by author declaration (2026-10-20):** rights holder confirmed sole authorship/ownership and authorized the MIT notice `Copyright (c) 2026 Kenshin Fuwa`. Any third-party work added later must be checked separately.
2. Disable non-public Claude Web quota integration in public source and document behavior differences (addressed in beta.3). The public source now disables undocumented Claude Web polling; official Claude Code statusLine is retained.
3. Check on an actual Mac: `./scripts/check.sh`, Codex/Claude login, notification test, cascading menus, live resizing and Keychain behavior.
4. Make a deliberate visibility choice, review the staged diff and remote repository, and only then push publicly.
5. Developer ID signing and notarization must be addressed **before distributing a general-use macOS binary** (source-only beta does not include one).

## Publication status

**SOURCE PACKAGE VALIDATED ON LINUX; GITHUB NOT YET PUBLISHED.** Copyright attribution has been updated with author permission. The optional Claude integration terms and native macOS test remain open review gates; no GitHub repository was created or modified during this audit.

## beta.3 publication guard

- Current consumer terms: https://www.anthropic.com/legal/consumer-terms (section 3). Public build disables non-public Claude Web calls; the local private version is untouched.
- `scripts/publish-github.sh` checks macOS native build, active owner identity, empty target repo, staged paths, source hashes and explicit confirmation; publishes *source only*.
- GitHub repo is still not created at package time; publisher must run the script on the Mac. CI success cannot be asserted until GitHub Actions run.
