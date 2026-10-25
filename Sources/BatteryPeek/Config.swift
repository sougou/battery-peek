import Foundation
import BatteryCore

/// Optional settings in ~/.config/battery-peek/config.json, e.g. {"hotkey": "ctrl+opt+b"}.
enum Config {
    static func hotKey() -> HotKeySpec {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/battery-peek/config.json")
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["hotkey"] as? String {
            if let spec = HotKeySpec.parse(text) { return spec }
            NSLog("battery-peek: ignoring bad hotkey %@ in config.json", text)
        }
        return .default
    }
}
