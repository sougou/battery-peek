import Foundation
import IOKit

/// Connected Bluetooth devices and their batteries.
///
/// `system_profiler` lists connected devices and reports AirPods' left, right,
/// and case levels. Keyboards, mice, and trackpads don't appear there with a
/// level, but their IORegistry entries carry `BatteryPercent`, keyed by address.
public enum Bluetooth {
    // MARK: Parsing (pure, tested)

    /// "38-09-fb-06-cd-7a" and "38:09:FB:06:CD:7A" both become "38:09:fb:06:cd:7a".
    static func normalize(address: String) -> String {
        address.lowercased().replacingOccurrences(of: "-", with: ":")
    }

    private static func percent(_ v: Any?) -> Int? {
        guard let s = v as? String, let n = Int(s.trimmingCharacters(in: CharacterSet(charactersIn: "% "))),
              (0...100).contains(n) else { return nil }
        return n
    }

    private static func kind(name: String, minorType: String?) -> BatteryItem.Kind {
        let s = "\(name) \(minorType ?? "")".lowercased()
        if s.range(of: "airpods|buds|headphone|headset|earbud", options: .regularExpression) != nil { return .audio }
        if s.contains("keyboard") { return .keyboard }
        if s.contains("mouse") { return .mouse }
        if s.contains("trackpad") { return .trackpad }
        return .other
    }

    /// `profiler` is the JSON from `system_profiler SPBluetoothDataType -json`.
    /// `accessories` maps normalized addresses to `BatteryPercent`.
    public static func parse(profiler: Data, accessories: [String: Int]) -> [BatteryItem] {
        guard let root = try? JSONSerialization.jsonObject(with: profiler) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]],
              let connected = sections.first?["device_connected"] as? [[String: Any]]
        else { return [] }

        var items: [BatteryItem] = []
        var seen = Set<String>()
        func add(_ item: BatteryItem) {
            // Earbuds show up twice (classic and BLE entries); keep the first row per name.
            if seen.insert(item.name).inserted { items.append(item) }
        }

        for entry in connected {
            for (name, value) in entry {
                guard let v = value as? [String: Any] else { continue }
                let k = kind(name: name, minorType: v["device_minorType"] as? String)
                let left = percent(v["device_batteryLevelLeft"])
                let right = percent(v["device_batteryLevelRight"])
                let box = percent(v["device_batteryLevelCase"])
                let main = percent(v["device_batteryLevelMain"])
                let buds = (left != nil && right != nil) ? min(left!, right!) : (left ?? right)
                if let buds { add(BatteryItem(id: "bt-\(name)", name: name, kind: k, percent: buds)) }
                if let box { add(BatteryItem(id: "bt-\(name)-case", name: "\(name) Case", kind: .case_, percent: box)) }
                if let main { add(BatteryItem(id: "bt-\(name)", name: name, kind: k, percent: main)) }
                if buds == nil, box == nil, main == nil,
                   let addr = v["device_address"] as? String,
                   let pct = accessories[normalize(address: addr)] {
                    add(BatteryItem(id: "bt-\(name)", name: name, kind: k, percent: pct))
                }
            }
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Live reads

    /// `BatteryPercent` of HID accessories, from the IORegistry. Fast.
    public static func accessoryBatteries() -> [String: Int] {
        var result: [String: Int] = [:]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("AppleDeviceManagementHIDEventService"),
                                           &iterator) == KERN_SUCCESS else { return result }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let pct = IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
            let addr = IORegistryEntryCreateCFProperty(service, "DeviceAddress" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            if let pct, let addr, (0...100).contains(pct) { result[normalize(address: addr)] = pct }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }

    /// Runs `system_profiler` (about a second). Call from a background queue.
    public static func profilerJSON() -> Data? {
        runProcess("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
    }

    public static func read() -> [BatteryItem] {
        guard let json = profilerJSON() else { return [] }
        return parse(profiler: json, accessories: accessoryBatteries())
    }
}

/// Runs a program and returns its standard output, or nil if it can't be run.
func runProcess(_ path: String, _ args: [String]) -> Data? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return p.terminationStatus == 0 ? data : nil
}
