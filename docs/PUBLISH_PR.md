# Updating the existing public GitHub repository

`KenshinFuwa/AI-Checker` already exists and its current published `main` is at initial source beta `v1.9.2-beta.3`. **Never rerun `scripts/publish-github.sh`** (that script attempts initial repository creation). The local private AI Checker app must remain unchanged.

1. On your Mac, unpack this public candidate in a **new folder**; do not install it over the existing app.
2. Run `bash scripts/propose-github-beta.sh`. It verifies the SHA-256 source manifest, runs macOS native checks, opens a temporary clone, stages source-only files, shows the diff and waits for explicit `PROPOSE` before pushing an isolated branch and opening a PR.
3. Verify the PR file diff, CI logs and license/privacy content. **Do not merge until macOS CI actually passes**. The first published workflow runs were cancelled before any test steps, so they are not evidence of passing. The portable Linux gate deliberately excludes the Codex RPC mock; that integration is verified in the native macOS gate.
4. Merge manually on GitHub after review, then decide on a new source-only tag. Do not publish a binary until the steps in [DISTRIBUTION.md](DISTRIBUTION.md) are completed.

The separate local build retains private experimental Claude Web functionality; the public candidate deliberately disables it. A successful source-build does **not** establish identical function or telemetry on both versions.
