import SwiftUI

extension Color {
    /// Parse "#RRGGBB" or "RRGGBB" hex string. Returns nil on bad input.
    init?(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red:   Double((v >> 16) & 0xff) / 255,
            green: Double((v >> 8)  & 0xff) / 255,
            blue:  Double( v        & 0xff) / 255
        )
    }
}
