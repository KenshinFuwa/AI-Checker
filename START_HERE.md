# AI Checker — published source beta

This archive contains the public-source beta and documentation for AI Checker v1.10.1. It is **not an installer**, and it must not replace any existing AI Checker app on the maintainer's Mac.

1. Read [README.md](README.md), [SECURITY.md](SECURITY.md) and [RELEASE_GATE.md](RELEASE_GATE.md).
2. On a Mac with Xcode/Swift installed, run `python3 scripts/verify-source-manifest.py` and `bash scripts/check.sh` in a clean extracted copy. Build outputs remain local.
3. The [v1.10.1-beta.1 source-only pre-release](https://github.com/KenshinFuwa/AI-Checker/releases/tag/v1.10.1-beta.1) is published. For future changes, use reviewed PRs as described in [docs/PUBLISH_PR.md](docs/PUBLISH_PR.md). Do **not** run `scripts/publish-github.sh`.
4. For future general-user DMG distribution, follow [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md). Signed and notarized distribution is **not** yet complete.

English documentation is published with Japanese and English **application localization resources** in `Localization/ja.lproj` and `Localization/en.lproj`. The public build has no automatic undocumented Claude Web quota reader.
