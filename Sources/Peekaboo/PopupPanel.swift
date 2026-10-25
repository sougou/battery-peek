import AppKit
import SwiftUI
import Combine

/// A borderless floating panel that never takes focus, so the app you were using stays active.
final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PopupController {
    private let panel: PopupPanel
    private let hosting: NSHostingView<PopupView>
    private var cancellable: AnyCancellable?
    private var failsafe: Timer?

    private let makeRoot: () -> PopupView

    init(store: BatteryStore, weather: WeatherStore) {
        makeRoot = { PopupView(store: store, weather: weather) }
        hosting = NSHostingView(rootView: PopupView(store: store, weather: weather))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.layer?.masksToBounds = true
        blur.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: blur.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])

        panel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 140),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.contentView = blur
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar // after isFloatingPanel, which resets the level
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        // Resize when the list changes while the popup is up.
        cancellable = store.objectWillChange.merge(with: weather.objectWillChange).sink { [weak self] in
            DispatchQueue.main.async { self?.layoutAndCenter() }
        }
    }

    private func layoutAndCenter() {
        let size = hosting.fittingSize
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    func show(autoHideAfter seconds: TimeInterval = 30) {
        hosting.rootView = makeRoot() // re-evaluates "next hours" against the current time
        layoutAndCenter()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        // If a key-up is ever missed, don't leave the popup stuck on screen.
        failsafe?.invalidate()
        failsafe = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        failsafe?.invalidate()
        failsafe = nil
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.1; panel.animator().alphaValue = 0 },
                                             completionHandler: { [panel] in panel.orderOut(nil) })
    }
}
