import Foundation
import IOKit
import IOKit.hid

/// Live batteries of Logitech devices on a Bolt or Unifying receiver, over HID++ 2.0.
///
/// Opens only the receiver's vendor-defined interface (usage page 0xFF00), which carries
/// HID++ messages and never keystrokes, and sends read-only queries. Blocking: call from
/// a background queue. A sleeping device can take a couple of seconds to answer.
public enum Logitech {
    private static let vendorID = 0x046D
    private static let vendorUsagePage = 0xFF00

    public static func read(log: ((String) -> Void)? = nil) -> [BatteryItem] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: vendorID,
                                                kIOHIDPrimaryUsagePageKey: vendorUsagePage] as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        log?("IOHIDManagerOpen: \(String(format: "0x%08x", UInt32(bitPattern: opened)))")
        guard opened == kIOReturnSuccess else { return [] }
        defer {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        var items: [BatteryItem] = []
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        log?("receiver interfaces: \(devices.count)")
        for device in devices {
            guard let link = Link(device) else { log?("could not open receiver interface"); continue }
            for slot in UInt8(1)...UInt8(6) {
                if let item = link.battery(slot: slot, log: log) { items.append(item) }
            }
            link.close()
        }
        return items
    }

    /// One open HID++ interface. Replies arrive on a run-loop callback and land in `inbox`.
    private final class Link {
        let device: IOHIDDevice
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        var inbox: [[UInt8]] = []

        init?(_ device: IOHIDDevice) {
            self.device = device
            guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
                buffer.deallocate()
                return nil
            }
            let me = Unmanaged.passUnretained(self).toOpaque()
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, _, _, _, _, report, length in
                guard let context else { return }
                let link = Unmanaged<Link>.fromOpaque(context).takeUnretainedValue()
                link.inbox.append(Array(UnsafeBufferPointer(start: report, count: length)))
            }, me)
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }

        func close() {
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            buffer.deallocate()
        }

        func send(index: UInt8, feature: UInt8, function: UInt8, params: [UInt8] = [],
                  timeout: TimeInterval = 0.8) -> HIDPP.Reply? {
            let out = HIDPP.request(index: index, feature: feature, function: function, params: params)
            inbox.removeAll()
            guard IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(out[0]), out, out.count)
                    == kIOReturnSuccess else { return nil }
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                CFRunLoopRunInMode(.defaultMode, 0.02, true)
                for report in inbox {
                    if let reply = HIDPP.reply(to: report, index: index, feature: feature) { return reply }
                }
            }
            return nil
        }

        func featureIndex(slot: UInt8, id: UInt16) -> UInt8? {
            guard case .ok(let p)? = send(index: slot, feature: 0x00, function: 0,
                                          params: [UInt8(id >> 8), UInt8(id & 0xFF)]),
                  let index = p.first, index != 0 else { return nil }
            return index
        }

        func name(slot: UInt8) -> String? {
            guard let f = featureIndex(slot: slot, id: HIDPP.Feature.deviceName),
                  case .ok(let c)? = send(index: slot, feature: f, function: 0), let count = c.first.map(Int.init)
            else { return nil }
            var bytes: [UInt8] = []
            while bytes.count < count {
                guard case .ok(let p)? = send(index: slot, feature: f, function: 1, params: [UInt8(bytes.count)])
                else { break }
                let chunk = Array(p.prefix { $0 != 0 }.prefix(count - bytes.count))
                if chunk.isEmpty { break }
                bytes += chunk
            }
            return String(bytes: bytes, encoding: .utf8)
        }

        func battery(slot: UInt8, log: ((String) -> Void)?) -> BatteryItem? {
            // IRoot.GetProtocolVersion doubles as a ping: only a connected device answers with .ok.
            // A sleeping device can need a few seconds to wake, so retry once.
            let ping = send(index: slot, feature: 0x00, function: 1, params: [0, 0, 0x5A], timeout: 2.5)
                ?? send(index: slot, feature: 0x00, function: 1, params: [0, 0, 0x5A], timeout: 2.5)
            guard case .ok? = ping else { log?("slot \(slot): \(ping == nil ? "no reply" : "empty")"); return nil }

            var reading: HIDPP.BatteryReading?
            if let f = featureIndex(slot: slot, id: HIDPP.Feature.unifiedBattery),
               case .ok(let p)? = send(index: slot, feature: f, function: 1) {
                reading = HIDPP.parseUnifiedBattery(p)
            } else if let f = featureIndex(slot: slot, id: HIDPP.Feature.batteryStatus),
                      case .ok(let p)? = send(index: slot, feature: f, function: 0) {
                reading = HIDPP.parseBatteryStatus(p)
            }
            let name = name(slot: slot) ?? "Logitech device \(slot)"
            log?("slot \(slot): \(name) \(reading.map { "\($0.percent)%" } ?? "no battery feature")")
            guard let reading else { return nil }
            return BatteryItem(id: "logi-\(name)", name: name, kind: kind(of: name),
                               percent: reading.percent, charging: reading.charging,
                               note: reading.full ? "Fully charged" : (reading.charging ? "Charging" : nil))
        }

        private func kind(of name: String) -> BatteryItem.Kind {
            let s = name.lowercased()
            if s.contains("keyboard") || s.contains("keys") || s.contains("solar") { return .keyboard }
            if s.contains("trackpad") { return .trackpad }
            if s.range(of: "mouse|master|anywhere|lift|mx ", options: .regularExpression) != nil { return .mouse }
            return .other
        }
    }
}
