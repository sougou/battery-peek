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

// Weather parsing and formatting.
do {
    let json = """
    {"current":{"temperature_2m":18.5,"apparent_temperature":17.6,"relative_humidity_2m":58,
    "wind_speed_10m":14,"wind_direction_10m":300,"cloud_cover":25,"weather_code":1,"is_day":1}}
    """
    let r = Weather.parse(Data(json.utf8))
    check(r?.tempC == 18.5 && r?.code == 1 && r?.isDay == true, "weather fields")
    check(r?.feelsC == 17.6 && r?.humidity == 58 && r?.windKmh == 14 && r?.cloud == 25, "weather extras")
    check(Weather.parse(Data(#"{"current":{"weather_code":1}}"#.utf8)) == nil, "missing temperature")
    check(Weather.parse(Data("nope".utf8)) == nil, "garbage weather json")
    let night = Weather.parse(Data(#"{"current":{"temperature_2m":5,"weather_code":0,"is_day":0}}"#.utf8))
    check(night?.isDay == false && night?.feelsC == nil, "night, no optional fields")
    check(Weather.describe(code: 0, isDay: true).label == "Clear" && Weather.describe(code: 0, isDay: false).symbol == "moon.stars", "clear day/night")
    check(Weather.describe(code: 63, isDay: true).label == "Rain", "rain code")
    check(Weather.formatTemp(20, unit: .fahrenheit) == "68°F" && Weather.formatTemp(21.4, unit: .celsius) == "21°C", "temperature format")
    check(Weather.formatTemp(-0.2, unit: .celsius) == "0°C", "negative zero")
    check(Weather.formatWind(19, unit: .celsius) == "19 km/h" && Weather.formatWind(19, unit: .fahrenheit) == "12 mph", "wind format")
    check(Weather.compass(0) == "N" && Weather.compass(315) == "NW" && Weather.compass(359) == "N" && Weather.compass(-45) == "NW" && Weather.compass(nil) == "", "compass")
    let url = Weather.url(for: Place(name: "x", latitude: 40.712812, longitude: -74.006015)).absoluteString
    check(url.hasPrefix("https://api.open-meteo.com/") && url.contains("latitude=40.71&longitude=-74.01"), "rounded coordinates in the request")
}

// IP location parsing (providers differ in number vs string coordinates).
do {
    let ipwho = IPLocation.parse(Data(#"{"success":true,"latitude":37.3394,"longitude":-121.895,"city":"San Jose"}"#.utf8))
    check(ipwho == Place(name: "San Jose", latitude: 37.3394, longitude: -121.895), "ipwho.is shape")
    let geojs = IPLocation.parse(Data(#"{"latitude":"51.5","longitude":"-0.12","city":""}"#.utf8))
    check(geojs == Place(name: "Current location", latitude: 51.5, longitude: -0.12), "geojs string coordinates, no city")
    check(IPLocation.parse(Data(#"{"latitude":123,"longitude":0}"#.utf8)) == nil, "latitude out of range")
    check(IPLocation.parse(Data(#"{"city":"x"}"#.utf8)) == nil, "no coordinates")
}

check(HotKeySpec.default.label == "⌃⌥B", "hotkey label")
check(formatDuration(minutes: 45) == "45m", "short duration")
check(formatDuration(minutes: 72) == "1h 12m", "long duration")

print(failures == 0 ? "ok: \(count) checks passed" : "\(failures) of \(count) checks FAILED")
exit(failures == 0 ? 0 : 1)
