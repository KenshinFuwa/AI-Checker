# AI Checker — RC2.3 source-only publication gate (2026-10-26)

**Candidate:** RC2.3, documentation-only publication synchronization; tested runtime source unchanged.
**Owner-Mac QA:** 8/8 PASS on 2026-10-25 (115 Python, 114 Swift core tests, native release build, Codex mock, Universal 2/temporary DMG checks). Tested RC2.3 source ZIP SHA-256: `c3f2ce23e1cfb0d499a200dd9f24c80a6565c6c5392f5218b700865cbe386e4c`.
**GitHub repository:** restored; public `main` pinned to `c237d3fa74733414775a2808542508efd995783b` on 2026-10-26; exact proposed PR/commit CI pending.
**Source prerelease:** HOLD until human diff review, CI, and release authorization. **Notarized public installer:** HOLD.

---

## Historical RC2.2 and earlier gates (preserved for provenance)


**Candidate:** `RC2.2-docsync1` (documentation synchronization only; no changes to application runtime, localization, tests, packaging scripts, CI workflows or permissions).
**Status:** offline RC2.2 QA PASS; documentation-synchronized candidate verification pending/requiring exact-commit remote CI. GitHub source-only prerelease **HOLD** until account access is restored, owner diff review and GitHub CI. General-user DMG **HOLD**.

## Actual owner-Mac QA evidence — 2026-10-25

Evidence archive: `AI_CHECKER_RC22_QA_RESULT_AI_CHECKER_RC22_QA_q73o4vdq.zip`.
The report says `QA_PASS`, each of eight recorded gates exited `0`, and identifies the original RC2.2 source ZIP SHA-256 as `0af554fdcacd4e9c3d5b2fbdcd69dc9de4874626578fdda4b97ccfb1fecbe990`.

| Recorded gate | Outcome |
| --- | --- |
| Source archive structure and integrity | PASS |
| RC2.1 unchanged-file parity | PASS |
| Source SHA-256 manifest (128 files) | PASS |
| Python regression tests | PASS — 115 tests |
| Swift core tests | PASS — 111 tests |
| Native macOS release build | PASS |
| Codex isolated App Server mock | PASS |
| arm64/x86_64 Universal 2 build and disposable DMG structure | PASS |

These results **do not** establish native menu UI interactions, account login, actual RC2.2 Codex/Claude quota acquisition, macOS language switching, genuine Intel-hardware usage, installed-app upgrades, notification permissions, or Gatekeeper readiness. The maintainer's currently installed app differs from the public-source RC2.2 candidate; its Claude Web experimental data is not part of this release.

## Documentation synchronization and provenance

The source-only documentation refresh corrects prior RC1/RC2.1 release-gate descriptions. It intentionally leaves all executable/runtime source, tests, localization tables, packaging scripts and workflows byte-identical to the Mac-tested original RC2.2 source. Any changed documentation receives a **new source ZIP SHA-256 and updated `SOURCE_SHA256.json`**. The attached Mac evidence identifies the original source ZIP, not this documentation revision: do **not** relabel that QA as if it ran on the revised ZIP.

Re-run source-manifest and documentation/Python tests after this revision. Re-run the native macOS build/tests and GitHub Actions **on the exact eventual published tree** when access is restored; preserve results. Until then, exact-commit source publication is HOLD.

## Source-only beta release gate

- [x] Owner-Mac original RC2.2 offline QA evidence (8/8, with the bounds above).
- [x] Claude public-source reader restricts inputs and uses official Claude Code statusLine when provided; no undocumented Claude Web polling in the public build.
- [x] Historical GitHub publishing scripts exit `78` without a write.
- [ ] Review current remote `main`, tags, past PRs and CI when GitHub access is restored.
- [ ] Reconcile candidate to remote HEAD; owner reviews all source, tests, docs, license and binary artwork provenance.
- [ ] Exact-commit native + GitHub CI pass for the proposed change.
- [ ] Owner authorizes a specifically labeled **source-only prerelease** and verifies published source checksum.

## General-public binary distribution gate

Still NOT passed: Developer ID Application signing, hardened runtime, Apple notarization/stapling, Gatekeeper, clean-machine install/upgrade, Keychain/login item/notification flows and physical architecture tests. Do **not** upload the ad-hoc/unsigned temporary QA DMG as a user installer.

## Privacy and supported telemetry

- Codex rate limits: official Codex App Server, only after account authorization and fresh data.
- Claude: first-party Claude Code `statusLine` rate-limit windows **only when provided**. Missing windows and reset times are unknown; no fabricated 100%.
- Experimental Claude Web quota functionality visible in the maintainer's private app is disabled in this public-source candidate.
- The source archive and QA report are evidence, not credentials or an authorization to connect an account or modify `/Applications`.

## RC2.3 pre-publication hardening (local source candidate)

RC2.3 is a new candidate based on `RC2.2-docsync1`. It closes a type-validation
edge case in the Codex App Server quota decoder: JSON `true`/`false` is never a
percentage, window duration or Unix reset timestamp. Claude Code sanitized
quota cache reads now cap the file at 2 KiB **before** loading it.
Three Codex regression tests and a native Claude cache oversize self-test were
added. These changes are NOT covered by the historical RC2.2 Mac QA evidence.
RC2.3 owner-Mac native QA subsequently passed 8/8 on 2026-10-25 (115 Python, 114 Swift core tests, native release build, Codex mock, Universal 2 temporary DMG). Exact-commit GitHub CI and authenticated native GUI checks remain outstanding.
