# Publishing an update to an existing GitHub repository

Repository: `KenshinFuwa/AI-Checker`. This is an **existing** repository. Both historical GitHub publishing scripts (`scripts/publish-github.sh` and `scripts/propose-github-beta.sh`) are intentionally **disabled** and exit nonzero without network or GitHub writes. Do not re-enable or bypass them during account review. Future publishing requires owner-reviewed changes and explicit manual Git operations after access is restored.

## Before repository access is restored

- Develop and test locally; keep the owner's working `/Applications/AI Checker.app`, login sessions, settings and Keychain untouched.
- Do not issue GitHub write actions, retry failed authentication in a loop, create replacement accounts to evade enforcement, or re-upload software to an alternate account to bypass a restriction.
- Keep the exact source archive and QA evidence; see [RELEASE_GATE.md](../RELEASE_GATE.md).

## After the owner independently confirms account restoration

1. Inspect the actual remote default branch, latest commit, tags, existing releases, and ongoing CI. The last historically recorded source merge is `c237d3fa74733414775a2808542508efd995783b`; **do not assume this is still HEAD**.
2. Review a **local candidate diff** against that remote branch. Inspect changes to source, test expectations, localization resources, security documentation, workflows and LICENSE. If other changes have landed, reconcile them rather than overwriting remote work.
3. Run the native source checks on the candidate (`python3 scripts/verify-source-manifest.py`, `bash scripts/check.sh`), and preserve the complete logs. Do not install the app to perform this gate.
4. Create a feature branch from the inspected remote base and open a pull request. Never push directly to `main` and never rewrite existing tags/releases. Verify no credentials or private files are staged.
5. Review the PR diff and successful GitHub Actions on the **exact commit** to be merged. Obtain the owner's explicit approval before merging or publishing.
6. For the initial documentation-corrected RC2 candidate, prefer a clearly identified **source-only prerelease** and attach its SHA-256. Never upload the temporary unsigned/adhoc DMG from CI as a general-use installer.

Developer ID-signing and notarization remain a separate, stricter release track: see [DISTRIBUTION.md](DISTRIBUTION.md).
