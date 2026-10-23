import AppKit
import Foundation

/// Uses the app bundle's native macOS localization selection, including a
/// per-app language override in System Settings. English is the development
/// region; Japanese is an explicitly supported localization.
enum AppL10n {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    }

    /// Localizes a native menu recursively. AppKit otherwise keeps titles that
    /// were created directly using the original source strings.
    static func apply(to menu: NSMenu) {
        menu.title = text(menu.title)
        for item in menu.items {
            if item.view == nil {
                item.title = text(item.title)
            }
            if let child = item.submenu { apply(to: child) }
        }
    }

    /// Reserve formatted keys for future migration; never interpolate values
    /// into a localization key, because that prevents resource lookup.
    static func format(_ key: String, _ values: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: values)
    }
}
