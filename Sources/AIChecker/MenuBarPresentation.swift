import AppKit

/// Only changes our own status item; does not discover or modify other apps.
enum MenuBarPresentation: String, CaseIterable {
    case standard, compact, iconOnly
}
