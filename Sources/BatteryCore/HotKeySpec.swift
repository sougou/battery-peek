import Foundation

/// A global hotkey such as "ctrl+opt+b": a virtual key code plus Carbon modifier flags.
public struct HotKeySpec: Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    // Carbon modifier bits (cmdKey, shiftKey, optionKey, controlKey).
    static let cmd: UInt32 = 1 << 8
    static let shift: UInt32 = 1 << 9
    static let option: UInt32 = 1 << 11
    static let control: UInt32 = 1 << 12

    public static let `default` = HotKeySpec(keyCode: 11, modifiers: control | option) // ctrl+opt+b

    // US-layout virtual key codes.
    static let keys: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21,
        "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35,
        "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "space": 49,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]

    /// "⌃⌥B" style label for menus.
    public var label: String {
        var s = ""
        if modifiers & HotKeySpec.control != 0 { s += "⌃" }
        if modifiers & HotKeySpec.option != 0 { s += "⌥" }
        if modifiers & HotKeySpec.shift != 0 { s += "⇧" }
        if modifiers & HotKeySpec.cmd != 0 { s += "⌘" }
        return s + (HotKeySpec.keys.first { $0.value == keyCode }?.key ?? "?").uppercased()
    }

    /// Parses "ctrl+opt+b". Needs at least one modifier and exactly one key.
    public static func parse(_ text: String) -> HotKeySpec? {
        var mods: UInt32 = 0
        var key: UInt32?
        for part in text.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch part {
            case "cmd", "command": mods |= cmd
            case "ctrl", "control": mods |= control
            case "opt", "option", "alt": mods |= option
            case "shift": mods |= shift
            default:
                guard key == nil, let code = keys[part] else { return nil }
                key = code
            }
        }
        guard let key, mods != 0 else { return nil }
        return HotKeySpec(keyCode: key, modifiers: mods)
    }
}
