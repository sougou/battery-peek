import Foundation

/// Remembers the last reading of each device, so one that misses a refresh doesn't vanish.
///
/// A Logitech device that's asleep can fail to answer in time, and the next read finds it
/// again. Without this, the popup would drop it for a minute. A device that stays silent
/// longer than `keepFor` is dropped, so a device that's really gone doesn't linger.
public struct RecentItems {
    private var seen: [String: (item: BatteryItem, at: Date)] = [:]

    public init() {}

    /// Records `found` (newer readings replace older ones) and returns every device seen
    /// within `keepFor` seconds: the ones in `found`, then any that were missed this time.
    public mutating func update(_ found: [BatteryItem], now: Date = Date(),
                                keepFor: TimeInterval = 600) -> [BatteryItem] {
        for item in found { seen[item.id] = (item, now) }
        seen = seen.filter { now.timeIntervalSince($0.value.at) <= keepFor }
        let foundIDs = Set(found.map(\.id))
        let missed = seen.values
            .filter { !foundIDs.contains($0.item.id) }
            .map(\.item)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return found + missed
    }
}
