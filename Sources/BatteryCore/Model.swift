import Foundation

/// One row in the popup.
public struct BatteryItem: Equatable, Identifiable {
    public enum Kind: String {
        case computer, audio, case_, keyboard, mouse, trackpad, other
    }

    public var id: String
    public var name: String
    public var kind: Kind
    /// 0...100, or nil when the device is known but its level isn't.
    public var percent: Int?
    public var charging: Bool?
    /// Short extra line, such as "1h 12m to full".
    public var note: String?

    public init(id: String, name: String, kind: Kind, percent: Int?,
                charging: Bool? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.percent = percent
        self.charging = charging
        self.note = note
    }
}

public func formatDuration(minutes: Int) -> String {
    let m = max(1, minutes)
    return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
}
