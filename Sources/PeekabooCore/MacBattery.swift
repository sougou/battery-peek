import Foundation
import IOKit.ps

/// The computer's own battery, from the power-source API. Nil on a desktop.
public enum MacBattery {
    public static func read(computerName: String = Host.current().localizedName ?? "This Mac") -> BatteryItem? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let current = d[kIOPSCurrentCapacityKey] as? Int,
                  let max = d[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            let charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
            let pct = Swift.min(100, Int((Double(current) / Double(max) * 100).rounded()))
            let note: String?
            if charging {
                let t = d[kIOPSTimeToFullChargeKey] as? Int ?? -1
                note = pct >= 100 ? "Fully charged" : (t > 0 ? "\(formatDuration(minutes: t)) to full" : "Charging")
            } else {
                let t = d[kIOPSTimeToEmptyKey] as? Int ?? -1
                note = t > 0 ? "\(formatDuration(minutes: t)) remaining" : "On battery"
            }
            return BatteryItem(id: "mac", name: computerName, kind: .computer,
                               percent: pct, charging: charging, note: note)
        }
        return nil
    }
}
