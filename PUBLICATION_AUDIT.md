# AI Checker — release-candidate audit (updated 2026-10-26)

## Pinned evidence

A source archive named `AI-Checker-v1.10.1-localization-rc1-source.zip` was verified on the owner's Mac. Its independent QA result archive `AI_CHECKER_RC1_QA_RESULT_AI_CHECKER_RC1_QA_20261025_021829_6yR3aF.zip` reports seven PASS statuses and zero failures:

| Gate | Observed result |
| --- | --- |
| Source archive CRC and pinned hash | PASS |
| SHA-256 manifest, 131 source files | PASS |
| Python regression | PASS (115 tests) |
| Swift core | PASS (107 tests) |
| Native release build | PASS |
| Codex App Server mock | PASS |
| Universal 2 builds / disposable DMG layout audit | PASS (arm64 + x86_64) |

This is evidence about **RC1**, not an assertion that a documentation-modified candidate or a clean user installation was tested on a Mac. Runtime Swift files in this documentation candidate are unchanged; native build and repository CI must still be rechecked on its exact commit.

## Unverified or blocked

- Actual authenticated Codex/Claude quotas and statusLine freshness, native interactive Japanese/English appearance, account recovery, notifications and safe upgrade from locally signed installations.
- No Developer ID public binary signature, accepted Apple notarization, stapling or end-user clean installation.
- GitHub access was independently verified restored on 2026-10-26. The public default branch is `main`, at `c237d3fa74733414775a2808542508efd995783b` with a historical successful workflow; no open pull requests or releases were returned. The new RC2.3 commit and its CI are still pending.

## Safety

Do not publish private authentication stores, local experimental features, vendor logos, or a temporary unsigned DMG. Do not execute the historical initial-publication script. See [the release gate](RELEASE_GATE.md) and [the owner-reviewed publication instructions](docs/PUBLISH_PR.md).

## RC2.3 current Mac evidence

The owner-Mac RC2.3 QA report `AI_CHECKER_RC23_QA_RESULT_AI_CHECKER_RC23_QA_axdn0evb.zip` records eight gates with exit code zero, including 115 Python and 114 Swift core tests, native release build, isolated Codex mock, and Universal 2/temporary DMG checks. The tested source ZIP SHA-256 is `c3f2ce23e1cfb0d499a200dd9f24c80a6565c6c5392f5218b700865cbe386e4c`. Documentation-only changes prepared after this QA are **not** the same ZIP; runtime-source parity is maintained separately, and GitHub CI must pass on the exact proposed commit.
