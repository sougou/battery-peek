// Prints what the Logitech receiver reports, step by step. For debugging.
//
//   swift run hidpp-probe
import BatteryCore
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
let items = Logitech.read(log: { print($0) })
print("\nresult:")
for i in items {
    print("  \(i.name): \(i.percent.map { "\($0)%" } ?? "-")\(i.note.map { " (\($0))" } ?? "")")
}
