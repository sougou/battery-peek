import SwiftUI
import PeekabooCore

/// Weather on the left (when there is a reading), batteries on the right.
struct PopupView: View {
    @ObservedObject var store: BatteryStore
    @ObservedObject var weather: WeatherStore

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if let reading = weather.reading {
                WeatherPanel(reading: reading, place: weather.placeName, unit: weather.unit)
                    .frame(width: 250, alignment: .leading)
                    .padding(.trailing, 20)
                Divider()
                    .padding(.trailing, 20)
            }
            BatteryList(store: store)
                .frame(width: 360, alignment: .leading)
        }
        .padding(20)
        .fixedSize()
    }
}

private struct BatteryList: View {
    @ObservedObject var store: BatteryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("BATTERIES")
            if store.items.isEmpty {
                Text("No batteries found").foregroundStyle(.secondary)
            }
            ForEach(store.items) { item in
                Row(item: item)
            }
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(.secondary)
    }
}

private struct WeatherPanel: View {
    let reading: WeatherReading
    let place: String?
    let unit: TempUnit

    private var rows: [(String, String)] {
        var rows: [(String, String)] = []
        if let feels = reading.feelsC { rows.append(("Feels like", Weather.formatTemp(feels, unit: unit))) }
        if let precip = reading.precipMm { rows.append(("Precip.", Weather.formatPrecip(precip, unit: unit))) }
        if let wind = reading.windKmh {
            rows.append(("Wind", "\(Weather.formatWind(wind, unit: unit)) \(Weather.compass(reading.windDeg))"
                .trimmingCharacters(in: .whitespaces)))
        }
        if let humidity = reading.humidity { rows.append(("Humidity", "\(Int(humidity.rounded()))%")) }
        if let cloud = reading.cloud { rows.append(("Cloud cover", "\(Int(cloud.rounded()))%")) }
        return rows
    }

    var body: some View {
        let d = Weather.describe(code: reading.code, isDay: reading.isDay)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(place?.uppercased() ?? "WEATHER")
                .lineLimit(1)
            HStack(alignment: .center, spacing: 12) {
                Text(Weather.formatTemp(reading.tempC, unit: unit))
                    .font(.system(size: 46, weight: .light, design: .monospaced))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Image(systemName: d.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 34))
            }
            Text(d.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        Text(row.0.uppercased())
                            .font(.system(size: 10, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        Text(row.1)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
            }
            .padding(.top, 4)
            HourStrip(hours: Weather.nextHours(reading), offset: reading.utcOffsetSeconds, unit: unit)
        }
    }
}

/// The next few hours: time, condition icon, temperature, and chance of rain.
private struct HourStrip: View {
    let hours: [HourForecast]
    let offset: Int?
    let unit: TempUnit

    var body: some View {
        if !hours.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider().padding(.top, 6)
                SectionLabel("NEXT HOURS")
                HStack(alignment: .top, spacing: 0) {
                    ForEach(hours, id: \.time) { hour in
                        VStack(spacing: 4) {
                            Text(Weather.formatHour(hour.time, utcOffsetSeconds: offset))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: Weather.describe(code: hour.code, isDay: hour.isDay).symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 16))
                                .frame(height: 20)
                            Text(Weather.formatTemp(hour.tempC, unit: unit).replacingOccurrences(of: "°\(unit.rawValue)", with: "°"))
                                .font(.system(size: 13, design: .monospaced))
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill").font(.system(size: 7))
                                Text(hour.precipChance.map { "\($0)%" } ?? "–")
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
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
