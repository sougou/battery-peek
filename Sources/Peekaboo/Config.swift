import Foundation
import PeekabooCore

/// Optional settings in ~/.config/peekaboo/config.json:
///
///     {
///       "hotkey": "ctrl+opt+b",
///       "units": "F",
///       "location": { "name": "San Jose", "latitude": 37.33, "longitude": -121.89 }
///     }
///
/// Every key is optional. Without `location`, weather uses an approximate location from your
/// IP address. The old location, ~/.config/battery-peek/config.json (from before the rename),
/// is read when the new file doesn't exist.
enum Config {
    struct Settings {
        var hotKey = HotKeySpec.default
        var location: Place?
        var units: TempUnit?
    }

    static func load() -> Settings {
        var settings = Settings()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = [".config/peekaboo/config.json", ".config/battery-peek/config.json"]
            .map { home.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        guard let url, let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return settings }

        if let text = json["hotkey"] as? String {
            if let spec = HotKeySpec.parse(text) { settings.hotKey = spec }
            else { NSLog("peekaboo: ignoring bad hotkey %@ in %@", text, url.path) }
        }
        if let text = json["units"] as? String {
            if let unit = TempUnit(rawValue: text.uppercased()) { settings.units = unit }
            else { NSLog("peekaboo: ignoring units %@ in %@ (use \"F\" or \"C\")", text, url.path) }
        }
        if let loc = json["location"] as? [String: Any] {
            if let lat = (loc["latitude"] as? NSNumber)?.doubleValue,
               let lon = (loc["longitude"] as? NSNumber)?.doubleValue,
               (-90...90).contains(lat), (-180...180).contains(lon) {
                settings.location = Place(name: (loc["name"] as? String) ?? "Weather", latitude: lat, longitude: lon)
            } else {
                NSLog("peekaboo: ignoring location in %@ (needs latitude and longitude)", url.path)
            }
        }
        return settings
    }
}
