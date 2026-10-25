import Foundation
import PeekabooCore

/// What the popup shows. Fast sources (this Mac, HID accessories) refresh on every
/// show. Bluetooth profiles and Logitech receivers are slower, so they're cached and
/// refreshed in the background.
final class BatteryStore: ObservableObject {
    @Published private(set) var items: [BatteryItem] = []
    private var profiler: Data?
    private var logitech: [BatteryItem] = []
    private var recentLogitech = RecentItems()
    private var profilerAt = Date.distantPast
    private var logitechAt = Date.distantPast
    private var profilerBusy = false
    private var logitechBusy = false

    /// Rebuilds the list from fast sources plus the cached slow ones.
    func refreshFast() {
        var others: [BatteryItem] = []
        if let profiler {
            others += Bluetooth.parse(profiler: profiler, accessories: Bluetooth.accessoryBatteries())
        }
        // A device on both paths (Bluetooth and a receiver) shows once.
        let names = Set(others.map(\.name))
        others += logitech.filter { !names.contains($0.name) }
        others.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var result: [BatteryItem] = []
        if let mac = MacBattery.read() { result.append(mac) }
        result += others
        if result != items { items = result }
    }

    /// Re-reads the slow sources off the main thread when their caches are older than `maxAge`.
    /// `completion` runs when a refresh finishes, or right away if nothing needed refreshing.
    func refreshSlow(maxAge: TimeInterval = 30, completion: (() -> Void)? = nil) {
        var started = false
        defer { if !started { completion?() } }
        if !profilerBusy, Date().timeIntervalSince(profilerAt) >= maxAge {
            started = true
            profilerBusy = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let json = Bluetooth.profilerJSON()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.profilerBusy = false
                    if let json { self.profiler = json; self.profilerAt = Date() }
                    self.refreshFast()
                    completion?()
                }
            }
        }
        if !logitechBusy, Date().timeIntervalSince(logitechAt) >= maxAge {
            started = true
            logitechBusy = true
            // Own thread: HID++ replies are delivered through that thread's run loop.
            Thread.detachNewThread { [weak self] in
                let found = Logitech.read()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.logitechBusy = false
                    // A sleeping device can miss one read; keep its last reading for a few minutes.
                    self.logitech = self.recentLogitech.update(found)
                    self.logitechAt = Date()
                    self.refreshFast()
                    completion?()
                }
            }
        }
    }

    /// Blocking refresh of everything (for --list and --snapshot).
    func refreshAllNow() {
        profiler = Bluetooth.profilerJSON()
        profilerAt = Date()
        logitech = Logitech.read()
        logitechAt = Date()
        refreshFast()
    }
}
