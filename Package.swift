// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryPeek",
    platforms: [.macOS(.v13)],
    targets: [
        // Reads batteries. No UI, so it can be tested and reused by the probe tool.
        .target(name: "BatteryCore"),
        // The app: hold a hotkey to show a battery popup, release to hide it.
        .executableTarget(name: "BatteryPeek", dependencies: ["BatteryCore"]),
        // Command-line experiment: ask a Logitech receiver for device batteries (HID++).
        .executableTarget(name: "hidpp-probe", dependencies: ["BatteryCore"]),
        // Plain checks program (run: swift run core-checks). The command-line Swift tools
        // don't ship XCTest or the Swift Testing macros, so this stands in for a test target.
        .executableTarget(name: "core-checks", dependencies: ["BatteryCore"]),
    ]
)
