import Carbon.HIToolbox
import Foundation

/// Global shortcut. An `NSEvent` global monitor requires Accessibility permission, while Carbon's
/// `RegisterEventHotKey` does not. It is old but not deprecated, and is the right choice when the
/// only alternative asks the user for another permission.
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// A C function pointer cannot capture context, so the action lives in static storage.
    /// There is only one shortcut, therefore one slot is sufficient.
    private static var action: (() -> Void)?

    /// Default: ⌥⌘V
    init(keyCode: UInt32 = UInt32(kVK_ANSI_V),
         modifiers: UInt32 = UInt32(optionKey | cmdKey),
         action: @escaping () -> Void) {
        Self.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.action?()
            return noErr
        }, 1, &spec, nil, &handler)

        let id = EventHotKeyID(signature: OSType(0x564D_5820), id: 1)  // 'VMX '
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &reference)
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
