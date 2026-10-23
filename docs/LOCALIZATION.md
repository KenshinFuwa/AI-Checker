# macOS UI localization: English and Japanese

AI Checker uses the native macOS application-bundle language selection.
English (`en`) is the development language, and Japanese (`ja`) is the
second supported language. macOS selects the preferred available language,
including per-app language preferences in System Settings, when the app is
relaunched. Other language preferences fall back to English.

The maintained translation assets are:
- `Localization/en.lproj/Localizable.strings`
- `Localization/ja.lproj/Localizable.strings`

The existing source UI strings are still used as localization lookup keys in
this incremental migration. `AppL10n.text` reads the localized values from
`Bundle.main`; it does not access network translation services and does not
change authentication or account state.

The scripts that stage Universal 2 release bundles and local maintenance builds
both copy and validate the translation resources before signing. The DMG
auditor independently verifies the resources in the mounted bundle.

## Current coverage and limitations

This branch migrates the common menu navigation, the Accounts panel, the
Preferences panel, and the Usage panel. Some provider-specific status messages,
complex interpolated messages, alerts and notifications are **not yet migrated**.
They may still appear in Japanese on an English-language Mac. This is a
tracked incomplete localization, **not a claim that the entire app is bilingual**.

Before shipping a fully localized release, migrate all remaining UI strings to
stable English message keys with localized Japanese counterparts, preserve
interpolation placeholders correctly, check layout lengths with English and
Japanese language preferences, and exercise first-run/login/notifications on
native macOS. CI bundle inspection does not replace interactive UI validation.

Repository documentation and pull-request communication are authored in
English. Localized Japanese strings are application resources, not repository
documentation.
