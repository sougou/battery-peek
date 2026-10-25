import Foundation
import PeekabooCore

/// Optional settings in ~/.config/peekaboo/config.json, e.g. {"hotkey": "ctrl+opt+b"}.
/// The old location, ~/.config/battery-peek/config.json (from before the rename), is read
/// when the new file doesn't exist.
enum Config {
    static func hotKey() -> HotKeySpec {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = [".config/peekaboo/config.json", ".config/battery-peek/config.json"]
            .map { home.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
            ?? home.appendingPathComponent(".config/peekaboo/config.json")
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["hotkey"] as? String {
            if let spec = HotKeySpec.parse(text) { return spec }
            NSLog("peekaboo: ignoring bad hotkey %@ in %@", text, url.path)
        }
        return .default
    }
}
