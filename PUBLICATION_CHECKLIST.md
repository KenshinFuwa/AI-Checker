# Public repository release checklist

## Blocking decisions before making repository public

- [x] **Confirm LICENSE attribution/rights.** Project author confirmed sole copyright ownership and authorized the MIT notice **Copyright (c) 2026 Kenshin Fuwa** on 2026-10-20. Check any subsequently imported third-party code separately.
- [x] **Disable undocumented Claude Web quota polling in public source**. Current Anthropic Consumer Terms restrict automated access unless expressly permitted. The local experimental build is not published unchanged.
- [ ] **Run `./scripts/check.sh` on an actual Mac** and save the stdout/exit code. Linux parser/core tests do not establish AppKit runtime correctness.
- [ ] **Inspect `git diff --cached` and `git status`** before first push; avoid personal paths, screenshot metadata, secrets, `.build/`, Keychain content, logs, signing identities and local archives.
- [x] **Choose the GitHub repository visibility** (`public`) and owner/name (`KenshinFuwa/AI-Checker`). The guarded publish script refuses existing repositories and requires explicit confirmation.

## Strongly recommended before downloadable binary releases

- [ ] Developer ID + hardened runtime + Apple notarization + stapling, with clean Mac testing.
- [ ] Confirm third-party mark usage in promotional screenshots/artwork. This source package intentionally excludes provider PNGs.
- [ ] Review provider data semantics, throttling, caching and error states using test accounts.
- [ ] Validate first-launch, login-item approval, logout, notification permissions and upgrade from a separately signed build.
- [ ] Tag source beta version and enable GitHub Actions on macOS.
- [ ] Configure GitHub private vulnerability reporting and repository branch protection.

## First publication on macOS

Once the repository archive has been extracted, run:

```bash
bash scripts/publish-github.sh
```

The script verifies the active GitHub login is `KenshinFuwa`, checks that
`KenshinFuwa/AI-Checker` does not exist, performs the full macOS native
validation and source-manifest verification, stages only permitted source
files, previews the staged changes, and requires typing `PUBLISH` before
creating **a new public** repository. It commits and pushes only source and a
beta tag. It will never modify an already existing remote repository or local
installed app. The official GitHub CLI must be installed and authenticated.

The public source intentionally differs from the author's locally installed
v1.9.2: Claude's undocumented Web quota-fetching implementation is not
included. Claude Code statusLine remains available when it reports quotas.
