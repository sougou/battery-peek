// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Peekaboo",
    platforms: [.macOS(.v13)],
    targets: [
        // Reads batteries. No UI, so it can be tested and reused by the probe tool.
        .target(name: "PeekabooCore"),
        // The app: hold a hotkey to show a battery popup, release to hide it.
        .executableTarget(name: "Peekaboo", dependencies: ["PeekabooCore"]),
        // Command-line experiment: ask a Logitech receiver for device batteries (HID++).
        .executableTarget(name: "hidpp-probe", dependencies: ["PeekabooCore"]),
        // Plain checks program (run: swift run core-checks). The command-line Swift tools
        // don't ship XCTest or the Swift Testing macros, so this stands in for a test target.
        .executableTarget(name: "core-checks", dependencies: ["PeekabooCore"]),
    ]
)
