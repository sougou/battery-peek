import AppKit
import SwiftUI
import PeekabooCore

let args = CommandLine.arguments

// Debug helpers: `--list` prints what the popup would show; `--snapshot out.png` renders it.
@MainActor func runDebug() {
    let store = BatteryStore()
    store.refreshAllNow()
    if args.contains("--list") {
        for i in store.items {
            print("\(i.name)\t\(i.percent.map { "\($0)%" } ?? "-")\t\(i.note ?? "")")
        }
    }
    if let at = args.firstIndex(of: "--snapshot"), at + 1 < args.count {
        let renderer = ImageRenderer(content: PopupView(store: store)
            .background(Color(nsColor: .windowBackgroundColor)))
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            do { try png.write(to: URL(fileURLWithPath: args[at + 1])); print("wrote \(args[at + 1])") }
            catch { print("could not write snapshot: \(error)"); exit(1) }
        } else {
            print("could not render snapshot")
            exit(1)
        }
    }
}

if args.contains("--list") || args.contains("--snapshot") {
    MainActor.assumeIsolated { runDebug() }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
