import Foundation

public enum TempUnit: String, Codable {
    case celsius = "C"
    case fahrenheit = "F"

    /// Fahrenheit in the US, Celsius elsewhere.
    public static var systemDefault: TempUnit {
        Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
    }
}

public struct Place: Equatable, Codable {
    public var name: String
    public var latitude: Double
    public var longitude: Double

    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// One hour of the forecast.
public struct HourForecast: Equatable, Codable {
    public var time: Date
    public var tempC: Double
    /// Chance of precipitation, 0...100, when the model gives one.
    public var precipChance: Int?
    public var code: Int
    public var isDay: Bool
}

public struct WeatherReading: Equatable, Codable {
    public var tempC: Double
    public var feelsC: Double?
    public var humidity: Double?
    public var windKmh: Double?
    public var windDeg: Double?
    public var cloud: Double?
    /// Precipitation in the last hour, in millimetres.
    public var precipMm: Double?
    public var code: Int
    public var isDay: Bool
    /// The next several hours, starting at the current hour. Absent in older cache files.
    public var hours: [HourForecast]?
    /// Offset of the place's time zone from UTC, so hours show in local time there.
    public var utcOffsetSeconds: Int?
}

/// Current conditions from Open-Meteo's free forecast API (no key).
public enum Weather {
    /// Rounded to about a kilometre, so the request doesn't carry a precise location.
    public static func url(for place: Place) -> URL {
        let lat = String(format: "%.2f", place.latitude)
        let lon = String(format: "%.2f", place.longitude)
        return URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
            + "wind_speed_10m,wind_direction_10m,cloud_cover,precipitation,weather_code,is_day"
            + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
            + "&forecast_hours=7&timeformat=unixtime&timezone=auto")!
    }

    public static func parse(_ data: Data) -> WeatherReading? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cur = root["current"] as? [String: Any],
              let temp = (cur["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (cur["weather_code"] as? NSNumber)?.intValue else { return nil }
        func num(_ key: String) -> Double? { (cur[key] as? NSNumber)?.doubleValue }
        return WeatherReading(tempC: temp, feelsC: num("apparent_temperature"),
                              humidity: num("relative_humidity_2m"), windKmh: num("wind_speed_10m"),
                              windDeg: num("wind_direction_10m"), cloud: num("cloud_cover"),
                              precipMm: num("precipitation"),
                              code: code, isDay: (cur["is_day"] as? NSNumber)?.intValue != 0,
                              hours: parseHours(root["hourly"] as? [String: Any]),
                              utcOffsetSeconds: (root["utc_offset_seconds"] as? NSNumber)?.intValue)
    }

    /// `hourly` holds parallel arrays; nulls are allowed, and an hour without a time,
    /// temperature, or weather code is skipped.
    static func parseHours(_ hourly: [String: Any]?) -> [HourForecast]? {
        guard let hourly, let times = hourly["time"] as? [NSNumber],
              let temps = hourly["temperature_2m"] as? [Any],
              let codes = hourly["weather_code"] as? [Any] else { return nil }
        let chances = hourly["precipitation_probability"] as? [Any] ?? []
        let days = hourly["is_day"] as? [Any] ?? []
        var hours: [HourForecast] = []
        for i in times.indices where i < temps.count && i < codes.count {
            guard let temp = (temps[i] as? NSNumber)?.doubleValue,
                  let code = (codes[i] as? NSNumber)?.intValue else { continue }
            hours.append(HourForecast(
                time: Date(timeIntervalSince1970: times[i].doubleValue), tempC: temp,
                precipChance: i < chances.count ? (chances[i] as? NSNumber)?.intValue : nil,
                code: code, isDay: i < days.count ? (days[i] as? NSNumber)?.intValue != 0 : true))
        }
        return hours
    }

    /// The next `count` hours that start after `now`.
    public static func nextHours(_ reading: WeatherReading, after now: Date = Date(), count: Int = 4) -> [HourForecast] {
        Array((reading.hours ?? []).filter { $0.time > now }.sorted { $0.time < $1.time }.prefix(count))
    }

    /// "11 AM" (or "11" on a 24-hour system), in the place's time zone when known.
    public static func formatHour(_ time: Date, utcOffsetSeconds: Int?) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("j")
        if let offset = utcOffsetSeconds, let zone = TimeZone(secondsFromGMT: offset) { f.timeZone = zone }
        return f.string(from: time)
    }

    /// Blocking (up to `timeout`). Call from a background thread.
    public static func fetch(place: Place, timeout: TimeInterval = 8) -> WeatherReading? {
        httpGet(url(for: place), timeout: timeout).flatMap(parse)
    }

    // MARK: Presentation

    /// SF Symbol name and label for a WMO weather code.
    public static func describe(code: Int, isDay: Bool) -> (symbol: String, label: String) {
        switch code {
        case 0: return (isDay ? "sun.max" : "moon.stars", "Clear")
        case 1, 2: return (isDay ? "cloud.sun" : "cloud.moon", "Partly cloudy")
        case 3: return ("cloud", "Cloudy")
        case 45, 48: return ("cloud.fog", "Fog")
        case 51, 53, 55, 56, 57: return ("cloud.drizzle", "Drizzle")
        case 61, 63, 65, 66, 67, 80, 81, 82: return ("cloud.rain", "Rain")
        case 71, 73, 75, 77, 85, 86: return ("cloud.snow", "Snow")
        case 95, 96, 99: return ("cloud.bolt.rain", "Thunderstorm")
        default: return ("cloud", "Weather")
        }
    }

    /// Direction the wind blows from, as an 8-point compass label ("" if unknown).
    public static func compass(_ degrees: Double?) -> String {
        guard let degrees, degrees.isFinite else { return "" }
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let index = Int(((wrapped < 0 ? wrapped + 360 : wrapped) / 45).rounded()) % 8
        return points[index]
    }

    public static func formatTemp(_ celsius: Double, unit: TempUnit) -> String {
        let v = unit == .fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(v.rounded()))°\(unit.rawValue)"
    }

    /// "None", "0.4 mm", or "0.02 in".
    public static func formatPrecip(_ mm: Double, unit: TempUnit) -> String {
        guard mm >= 0.05 else { return "None" }
        return unit == .fahrenheit ? String(format: "%.2f in", mm / 25.4) : String(format: "%.1f mm", mm)
    }

    public static func formatWind(_ kmh: Double, unit: TempUnit) -> String {
        unit == .fahrenheit ? "\(Int((kmh * 0.621371).rounded())) mph" : "\(Int(kmh.rounded())) km/h"
    }
}
