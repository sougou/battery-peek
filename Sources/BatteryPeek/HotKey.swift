import Carbon
import BatteryCore

/// A global hotkey that reports key-down and key-up, via Carbon's hot key API.
/// It needs no Accessibility or Input Monitoring permission.
final class HotKey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init?(_ spec: HotKeySpec) {
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            switch GetEventKind(event) {
            case UInt32(kEventHotKeyPressed): hotKey.onPress()
            case UInt32(kEventHotKeyReleased): hotKey.onRelease()
            default: return OSStatus(eventNotHandledErr)
            }
            return noErr
        }
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), callback, specs.count, &specs, me, &handlerRef) == noErr
        else { return nil }
        let id = EventHotKeyID(signature: OSType(0x4250_4B31), id: 1) // "BPK1"
        guard RegisterEventHotKey(spec.keyCode, spec.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
        else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
