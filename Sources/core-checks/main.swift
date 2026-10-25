import Foundation
@testable import PeekabooCore

var failures = 0
var count = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    count += 1
    if !ok { failures += 1; print("FAIL (line \(line)): \(what)") }
}

func profiler(_ devices: [[String: Any]]) -> Data {
    let root: [String: Any] = ["SPBluetoothDataType": [["device_connected": devices]]]
    return try! JSONSerialization.data(withJSONObject: root)
}

// Earbuds split into buds and case, and the BLE twin entry is dropped.
do {
    let data = profiler([
        ["AirPods Pro": ["device_batteryLevelCase": "89%", "device_batteryLevelLeft": "100%",
                         "device_batteryLevelRight": "92%"]],
        ["AirPods Pro": ["device_batteryLevelCase": "89%"]],
    ])
    let items = Bluetooth.parse(profiler: data, accessories: [:])
    check(items.map(\.name) == ["AirPods Pro", "AirPods Pro Case"], "earbud names")
    check(items.map(\.percent) == [92, 89], "buds use the lower side")
    check(items.first?.kind == .audio && items.last?.kind == .case_, "earbud kinds")
}

// Accessory levels come from the registry by address; devices with no level are skipped.
do {
    let data = profiler([
        ["Magic Keyboard": ["device_address": "38:09:FB:06:CD:7A", "device_minorType": "Keyboard"]],
        ["Speaker": ["device_address": "AA:BB:CC:DD:EE:FF"]],
    ])
    let items = Bluetooth.parse(profiler: data, accessories: ["38:09:fb:06:cd:7a": 96])
    check(items == [BatteryItem(id: "bt-Magic Keyboard", name: "Magic Keyboard",
                                kind: .keyboard, percent: 96)], "accessory by address")
}

check(Bluetooth.normalize(address: "38-09-FB-06-CD-7A") == "38:09:fb:06:cd:7a", "address normalization")
check(Bluetooth.parse(profiler: Data("not json".utf8), accessories: [:]).isEmpty, "garbage json")
check(Bluetooth.parse(profiler: profiler([]), accessories: [:]).isEmpty, "no devices")

check(HotKeySpec.parse("ctrl+opt+b") == HotKeySpec.default, "default hotkey")
check(HotKeySpec.parse(" Cmd + Shift + F1 ")
      == HotKeySpec(keyCode: 122, modifiers: HotKeySpec.cmd | HotKeySpec.shift), "cmd+shift+f1")
check(HotKeySpec.parse("b") == nil, "letters need a modifier")
check(HotKeySpec.parse("f16") == HotKeySpec(keyCode: 106, modifiers: 0), "f16 stands alone")
check(HotKeySpec.parse("F16")?.label == "F16", "f16 label")
check(HotKeySpec.parse("shift+f13") == HotKeySpec(keyCode: 105, modifiers: HotKeySpec.shift), "modifier with f13")
check(HotKeySpec.parse("f21") == nil, "f21 is not a key")
check(HotKeySpec.parse("ctrl+opt") == nil, "needs a key")
check(HotKeySpec.parse("ctrl+b+c") == nil, "one key only")
check(HotKeySpec.parse("ctrl+banana") == nil, "unknown key")

// HID++ framing and decoding.
do {
    let req = HIDPP.request(index: 2, feature: 0x05, function: 1, params: [7])
    check(req.count == 20 && req[0] == 0x11 && req[1] == 2 && req[2] == 5, "request header")
    check(req[3] == 0x1A && req[4] == 7, "function and software id")
    var ok = [UInt8](repeating: 0, count: 20); ok[0] = 0x11; ok[1] = 2; ok[2] = 5; ok[3] = 0x1A; ok[4] = 9
    check(HIDPP.reply(to: ok, index: 2, feature: 5) == .ok(Array(ok[4...])), "matching reply")
    check(HIDPP.reply(to: ok, index: 3, feature: 5) == nil, "other slot ignored")
    check(HIDPP.reply(to: ok, index: 2, feature: 6) == nil, "other feature ignored")
    var other = ok; other[3] = 0x1B
    check(HIDPP.reply(to: other, index: 2, feature: 5) == nil, "other software id ignored")
    let empty: [UInt8] = [0x10, 1, 0x8F, 0x00, 0x1A, 0x09, 0x00]
    check(HIDPP.reply(to: empty, index: 1, feature: 0) == .error(9), "HID++ 1.0 error for an empty slot")
    var e2 = [UInt8](repeating: 0, count: 20); e2[0] = 0x11; e2[1] = 2; e2[2] = 0xFF; e2[3] = 5; e2[5] = 4
    check(HIDPP.reply(to: e2, index: 2, feature: 5) == .error(4), "HID++ 2.0 error")
    check(HIDPP.parseUnifiedBattery([0x5F, 8, 0, 0]) == HIDPP.BatteryReading(percent: 95, charging: false, full: false), "unified 95%")
    check(HIDPP.parseUnifiedBattery([0x64, 8, 3, 0]) == HIDPP.BatteryReading(percent: 100, charging: false, full: true), "unified full")
    check(HIDPP.parseUnifiedBattery([50, 4, 1, 1])?.charging == true, "unified charging")
    check(HIDPP.parseUnifiedBattery([200, 0, 0]) == nil, "unified out of range")
    check(HIDPP.parseBatteryStatus([80, 70, 0])?.percent == 80, "legacy battery status")
}

check(HotKeySpec.default.label == "⌃⌥B", "hotkey label")
check(formatDuration(minutes: 45) == "45m", "short duration")
check(formatDuration(minutes: 72) == "1h 12m", "long duration")

print(failures == 0 ? "ok: \(count) checks passed" : "\(failures) of \(count) checks FAILED")
exit(failures == 0 ? 0 : 1)
