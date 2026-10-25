import Foundation

/// HID++ 2.0 message framing and decoding. Pure functions, no I/O (tested in core-checks).
///
/// A long message is 20 bytes: report ID 0x11, device index, feature index,
/// (function << 4 | software ID), then up to 16 parameter bytes.
public enum HIDPP {
    public static let longReportID: UInt8 = 0x11
    public static let softwareID: UInt8 = 0x0A

    public static func request(index: UInt8, feature: UInt8, function: UInt8, params: [UInt8] = []) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 20)
        out[0] = longReportID
        out[1] = index
        out[2] = feature
        out[3] = (function << 4) | softwareID
        for (i, p) in params.prefix(16).enumerated() { out[4 + i] = p }
        return out
    }

    public enum Reply: Equatable {
        case ok([UInt8])     // parameter bytes (report[4...])
        case error(UInt8)    // HID++ error code
    }

    /// Decides whether `report` answers the request `(index, feature)`; nil if it's unrelated.
    public static func reply(to report: [UInt8], index: UInt8, feature: UInt8) -> Reply? {
        guard report.count >= 7, report[1] == index else { return nil }
        if report[2] == feature, report[3] & 0x0F == softwareID { return .ok(Array(report[4...])) }
        if report[2] == 0xFF, report[3] == feature { return .error(report[5]) }  // HID++ 2.0 error
        if report[2] == 0x8F { return .error(report[5]) }                        // HID++ 1.0 error (e.g. empty slot)
        return nil
    }

    // MARK: Features

    public enum Feature {
        public static let deviceName: UInt16 = 0x0005
        public static let batteryStatus: UInt16 = 0x1000
        public static let unifiedBattery: UInt16 = 0x1004
    }

    public struct BatteryReading: Equatable {
        public var percent: Int
        public var charging: Bool
        public var full: Bool
    }

    /// Unified battery (0x1004) GetStatus: state of charge, level flags, charging status, external power.
    public static func parseUnifiedBattery(_ params: [UInt8]) -> BatteryReading? {
        guard params.count >= 3, params[0] <= 100 else { return nil }
        let status = params[2] // 0 discharging, 1 charging, 2 slow charging, 3 full, 4 error
        return BatteryReading(percent: Int(params[0]), charging: status == 1 || status == 2, full: status == 3)
    }

    /// Battery status (0x1000) GetBatteryLevelStatus: level, next level, status.
    public static func parseBatteryStatus(_ params: [UInt8]) -> BatteryReading? {
        guard params.count >= 3, params[0] <= 100 else { return nil }
        let status = params[2] // 0 discharging, 1 recharging, 2 almost full, 3 full, 4 slow recharge
        return BatteryReading(percent: Int(params[0]), charging: status == 1 || status == 4, full: status == 3)
    }
}
