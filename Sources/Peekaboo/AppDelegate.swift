import AppKit
import PeekabooCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = BatteryStore()
    private lazy var popup = PopupController(store: store)
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?
    private var spec = HotKeySpec.default
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        spec = Config.hotKey()
        store.refreshFast()
        store.refreshSlow(maxAge: 0)

        hotKey = HotKey(spec)
        if let hotKey {
            hotKey.onPress = { [weak self] in self?.showPopup() }
            hotKey.onRelease = { [weak self] in self?.popup.hide() }
        } else {
            NSLog("peekaboo: could not register hotkey %@ (already taken?)", spec.label)
        }

        setUpStatusItem()

        // `Peekaboo --show 4`: show the popup for 4 seconds, then quit (for testing).
        let args = CommandLine.arguments
        if let at = args.firstIndex(of: "--show"), at + 1 < args.count, let secs = Double(args[at + 1]) {
            store.refreshSlow(maxAge: 0) { [weak self] in self?.showPopup() }
            DispatchQueue.main.asyncAfter(deadline: .now() + secs) { NSApp.terminate(nil) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.store.refreshSlow()
        }
    }

    private func showPopup() {
        store.refreshFast()
        popup.show()
        store.refreshSlow() // updates the open popup if the cache was stale
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "Peekaboo")
        let menu = NSMenu()
        let hint = NSMenuItem(title: hotKey == nil ? "Hotkey unavailable" : "Hold \(spec.label) to peek",
                              action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(NSMenuItem(title: "Show for 3 seconds", action: #selector(showBriefly), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Peekaboo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { if $0.action == #selector(showBriefly) { $0.target = self } }
        item.menu = menu
        statusItem = item
    }

    @objc private func showBriefly() {
        showPopup()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.popup.hide() }
    }
}
