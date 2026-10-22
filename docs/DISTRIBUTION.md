# General-public macOS distribution — guarded workflow

This is a **preparation**, not proof of a signed or notarized release. No downloadable DMG exists until a macOS machine with an eligible Apple Developer Program membership and a **Developer ID Application** certificate passes all gates below. No certificate, private key, API key or notary credential may enter GitHub.

## 1. Preparation on the owner's Mac

Verify Xcode/Command Line Tools, `codesign`, `hdiutil`, `xcrun notarytool`, `xcrun stapler`, and access to a valid **Developer ID Application** identity. Create a `notarytool` Keychain profile separately using Apple-supported authentication; do not store the credentials in repository files. If Developer ID and notarization are not available, keep distributing **source only**.

Check Apple guidance: [Developer ID](https://developer.apple.com/developer-id/) · [Notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 2. Isolated build (never overwrites an installed app)

```bash
export AI_CHECKER_DEVELOPER_ID='Developer ID Application: YOUR LEGAL CERTIFICATE NAME (TEAMID)'
export AI_CHECKER_NOTARY_PROFILE='YOUR_EXISTING_NOTARYTOOL_KEYCHAIN_PROFILE'
./scripts/build-notarized-dmg.sh
```

Both values above are **placeholders**; do not copy them without substituting your real Keychain identity/profile. The script refuses a missing or non-Developer-ID certificate. It runs source verification, offline tests, native macOS release build, hardened-runtime signing with Apple timestamp, notarization with `notarytool`, staples and validates the DMG, verifies the image, and finally writes `dist/AI-Checker-v1.10.1-notarized.dmg` plus a SHA-256 checksum. If any check fails, no release artifact is published. It never calls `gh release` or modifies `/Applications`.

## 3. Mandatory release gates

- [ ] Apple notary status **Accepted**, `stapler validate` PASS and signing chain/Team ID verified.
- [ ] Install the DMG on a second/clean Mac and verify Gatekeeper, Spotlight search, app icon, Accessibility-free shortcut and all notification permissions.
- [ ] Check Apple silicon and Intel behavior as supported (the DMG is built for the host Mac architecture unless universal packaging is independently implemented and tested).
- [ ] Review privacy and account connection behavior; no test keys or private Web session access in the public build.
- [ ] **Upgrade/migration**: prior locally signed apps may have a different designated requirement; their login item and Keychain storage might require explicit migration. Do not overwrite them silently or claim seamless upgrades.
- [ ] Verify security vulnerability reporting, README download instructions, checksums and release notes before a GitHub Release.

## Important distinction

`script/install-local.sh` is a maintainer-only **locally signed update** script. It is not the public installer; it intentionally checks existing designated requirements and keeps backups. Do not run it for general users. Shipping unsigned/adhoc binaries as 'notarized' is prohibited.
