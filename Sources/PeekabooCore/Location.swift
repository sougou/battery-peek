import Foundation

/// Approximate location from the machine's IP address, for weather. Several providers are
/// tried in turn (HTTPS, no key). Only the IP address leaves the machine, as in any web request.
public enum IPLocation {
    static let providers = [
        "https://ipwho.is/",
        "https://ipapi.co/json/",
        "https://get.geojs.io/v1/ip/geo.json",
    ]

    /// All the providers report `latitude`, `longitude`, and `city`; geojs sends the numbers as strings.
    public static func parse(_ data: Data) -> Place? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        func number(_ key: String) -> Double? {
            if let n = root[key] as? NSNumber { return n.doubleValue }
            if let s = root[key] as? String { return Double(s) }
            return nil
        }
        guard let lat = number("latitude"), let lon = number("longitude"),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        let city = (root["city"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Current location"
        return Place(name: city, latitude: lat, longitude: lon)
    }

    /// Blocking. Call from a background thread.
    public static func lookup(timeout: TimeInterval = 6) -> Place? {
        for provider in providers {
            if let url = URL(string: provider), let data = httpGet(url, timeout: timeout),
               let place = parse(data) { return place }
        }
        return nil
    }
}

/// GET with a timeout; nil on any failure. Blocks the calling thread.
func httpGet(_ url: URL, timeout: TimeInterval) -> Data? {
    var request = URLRequest(url: url, timeoutInterval: timeout)
    request.setValue("Peekaboo", forHTTPHeaderField: "User-Agent")
    let done = DispatchSemaphore(value: 0)
    var result: Data?
    URLSession.shared.dataTask(with: request) { data, response, _ in
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) { result = data }
        done.signal()
    }.resume()
    _ = done.wait(timeout: .now() + timeout + 1)
    return result
}
