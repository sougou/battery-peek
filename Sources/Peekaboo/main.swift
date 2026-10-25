import AppKit
import SwiftUI
import PeekabooCore

let args = CommandLine.arguments

// Debug helpers: `--list` prints what the popup would show; `--snapshot out.png` renders it.
@MainActor func runDebug() {
    let settings = Config.load()
    let store = BatteryStore()
    let weather = WeatherStore(settings: settings)
    store.refreshAllNow()
    weather.refreshNow()
    if args.contains("--list") {
        if let r = weather.reading {
            let d = Weather.describe(code: r.code, isDay: r.isDay)
            print("\(weather.placeName ?? "weather")\t\(Weather.formatTemp(r.tempC, unit: weather.unit))\t\(d.label)")
        } else {
            print("(no weather)")
        }
        for i in store.items {
            print("\(i.name)\t\(i.percent.map { "\($0)%" } ?? "-")\t\(i.note ?? "")")
        }
    }
    if let at = args.firstIndex(of: "--snapshot"), at + 1 < args.count {
        let renderer = ImageRenderer(content: PopupView(store: store, weather: weather)
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
