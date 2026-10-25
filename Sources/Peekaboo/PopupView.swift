import SwiftUI
import PeekabooCore

struct PopupView: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BATTERIES")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(.secondary)
            if store.items.isEmpty {
                Text("No batteries found")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.items) { item in
                Row(item: item)
            }
        }
        .padding(20)
        .frame(width: 400, alignment: .leading)
    }
}

private struct Row: View {
    let item: BatteryItem

    private var symbol: String {
        switch item.kind {
        case .computer: return "laptopcomputer"
        case .audio: return "headphones"
        case .case_: return "case"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .other: return "dot.radiowaves.left.and.right"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                if let note = item.note {
                    Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let pct = item.percent {
                Text("\(pct)%")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                BatteryGauge(percent: pct, charging: item.charging ?? false)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}

private struct BatteryGauge: View {
    let percent: Int
    let charging: Bool

    private var fill: Color {
        if charging { return .accentColor }
        return percent <= 20 ? .red : .green
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5)
                    .strokeBorder(Color.secondary, lineWidth: 1.2)
                    .frame(width: 26, height: 12)
                RoundedRectangle(cornerRadius: 1.8)
                    .fill(fill)
                    .frame(width: max(2, CGFloat(percent) / 100 * 21), height: 7.4)
                    .padding(.leading, 2.6)
            }
            RoundedRectangle(cornerRadius: 1).fill(Color.secondary).frame(width: 2, height: 4.5)
        }
    }
}
