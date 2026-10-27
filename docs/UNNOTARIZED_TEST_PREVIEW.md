# AI Checker — unnotarized macOS test preview (not a release)

**This is not a verified public installer.** Any test DMG produced by the optional workflow is ad-hoc signed, not signed with a Developer ID Application certificate, and has not been notarized by Apple. Gatekeeper may prevent launching it. Do **not** instruct users to bypass macOS protection or to overwrite a working installation.

## Optional GitHub Actions test workflow

1. On an authorized repository, open the `unnotarized-preview.yml` workflow manually.
2. Choose the intended branch and enter the required acknowledgement exactly as `UNNOTARIZED_TEST_ONLY`.
3. If successful, inspect its **temporary, seven-day** test artifact and the associated checksum and warning files.
4. Use it only on a separate, deliberately isolated test Mac, not as an official download. Workflow execution may consume GitHub Actions usage minutes.

The workflow does not automatically execute, publish a GitHub Release, or install the app. Do not run it while GitHub account access is restricted.

## Optional local test generation

`bash scripts/build-free-preview-dmg.sh --acknowledge-unnotarized-preview` builds a test-only artifact in `dist/` after checking for conflicting existing files. It does not install anything to `/Applications`. The source-level guard verifies an ad-hoc signature; it cannot establish publisher identity or Apple notarization.

The public source disables experimental, undocumented Claude Web usage polling. Claude Code `statusLine` data is the supported source where supplied. Temporary DMG CI layout tests and packaged AppKit bootstrap smoke tests do not validate real account acquisition, login-item approval, notifications, normal app execution, or Gatekeeper success.

To produce an official general-user binary, use the separate Developer ID notarization and clean-install release gates described in [DISTRIBUTION.md](DISTRIBUTION.md).
