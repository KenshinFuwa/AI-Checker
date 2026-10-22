import AppKit
import Carbon.HIToolbox

/// Registers exactly one explicit Carbon system hotkey (no event taps,
/// keyboard monitoring, accessibility prompts, or synthetic events).
enum QuickPanelShortcut: String, CaseIterable {
    case defaultShortcut
    case alternativeShortcut

    var keyCode: UInt32 {
        switch self {
        case .defaultShortcut: return UInt32(kVK_ANSI_A)
        case .alternativeShortcut: return UInt32(kVK_ANSI_U)
        }
    }
}

final class GlobalUsageHotkey {
    var onActivate: (() -> Void)?
    private var registered: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private(set) var errorMessage: String?
    private let hotkeySignature: OSType = 0x41494348 // "AICH"

    func register(_ shortcut: QuickPanelShortcut) {
        unregister()
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, context in
            guard let eventRef, let context else { return OSStatus(eventNotHandledErr) }
            var received = EventHotKeyID()
            let status = GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &received)
            guard status == noErr, received.signature == 0x41494348, received.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            let manager = Unmanaged<GlobalUsageHotkey>.fromOpaque(context).takeUnretainedValue()
            manager.onActivate?()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else {
            errorMessage = "イベント登録 (\(result))"
            return
        }
        let identifier = EventHotKeyID(signature: hotkeySignature, id: 1)
        let flags = UInt32(controlKey | optionKey | cmdKey)
        let registration = RegisterEventHotKey(shortcut.keyCode, flags, identifier,
                                               GetApplicationEventTarget(), 0, &registered)
        guard registration == noErr else {
            errorMessage = "キーが使用中 (\(registration))"
            unregister()
            // The visible error is retained after unregister.
            errorMessage = "キーが使用中 (\(registration))"
            return
        }
        errorMessage = nil
    }

    func unregister() {
        if let registered { UnregisterEventHotKey(registered) }
        registered = nil
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        errorMessage = nil
    }

    deinit { unregister() }
}
