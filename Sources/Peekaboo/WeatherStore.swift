import Foundation
import PeekabooCore

/// Current weather for the popup. The place comes from config, else an approximate IP lookup
/// (cached 24 hours); the reading is cached 30 minutes. Both live in ~/Library/Caches/peekaboo
/// so a relaunch doesn't re-query.
final class WeatherStore: ObservableObject {
    @Published private(set) var reading: WeatherReading?
    @Published private(set) var placeName: String?
    let unit: TempUnit

    private let pinned: Place?
    private var place: Place?
    private var placeAt = Date.distantPast
    private var readingAt = Date.distantPast
    private var busy = false

    private struct Cache: Codable {
        var place: Place?
        var placeAt: Date?
        var reading: WeatherReading?
        var readingAt: Date?
    }

    private static var cacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/peekaboo/weather.json")
    }

    init(settings: Config.Settings) {
        unit = settings.units ?? .systemDefault
        pinned = settings.location
        if let data = try? Data(contentsOf: Self.cacheURL),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            place = cache.place
            placeAt = cache.placeAt ?? .distantPast
            // A cached reading is only valid for the place it was fetched for.
            if let cached = cache.place, cached == (pinned ?? cached) {
                reading = cache.reading
                readingAt = cache.readingAt ?? .distantPast
            }
        }
        placeName = (pinned ?? place)?.name
    }

    /// Re-reads the weather off the main thread if the cache is older than `maxAge`.
    func refresh(maxAge: TimeInterval = 30 * 60, completion: (() -> Void)? = nil) {
        guard !busy, Date().timeIntervalSince(readingAt) >= maxAge else { completion?(); return }
        busy = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let result = self.fetchBlocking()
            DispatchQueue.main.async {
                self.busy = false
                if let (place, reading) = result {
                    self.place = place
                    self.reading = reading
                    self.placeName = place.name
                    self.readingAt = Date()
                    self.saveCache()
                }
                completion?()
            }
        }
    }

    /// Blocking refresh (for --list and --snapshot).
    func refreshNow() {
        if let (place, reading) = fetchBlocking() {
            self.place = place
            self.reading = reading
            placeName = place.name
            readingAt = Date()
            saveCache()
        }
    }

    /// Resolves the place (config, cache, or IP lookup), then fetches. Not main-thread safe.
    private func fetchBlocking() -> (Place, WeatherReading)? {
        let resolved: Place?
        if let pinned { resolved = pinned }
        else if let place, Date().timeIntervalSince(placeAt) < 24 * 3600 { resolved = place }
        else { resolved = IPLocation.lookup() ?? place } // a stale place beats none
        guard let resolved else { return nil }
        if resolved != place { placeAt = Date() }
        guard let reading = Weather.fetch(place: resolved) else { return nil }
        return (resolved, reading)
    }

    private func saveCache() {
        let cache = Cache(place: place, placeAt: placeAt, reading: reading, readingAt: readingAt)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        let url = Self.cacheURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
