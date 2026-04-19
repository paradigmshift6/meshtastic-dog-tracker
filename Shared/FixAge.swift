import Foundation
import SwiftUI

/// Pure helper that converts a fix timestamp into a colored "X ago" label.
///
/// Same thresholds as the iOS Compass screen used inline (CompassScreen.fixAgeLabel).
/// Extracted so the watchOS Compass page can render the identical visual without
/// importing any of the iOS-only modules.
enum FixAge {

    enum Tier {
        case fresh        // ≤ 3 min — green
        case stale        // ≤ 10 min — yellow
        case old          // > 10 min — red
        case noFix        // never had a fix — red

        var color: Color {
            switch self {
            case .fresh: .green
            case .stale: .yellow
            case .old, .noFix: .red
            }
        }
    }

    /// Tier + display string for a tracker's last fix time.
    /// Pass `nil` for trackers that have never reported a fix.
    static func describe(_ fixTime: Date?, now: Date = .now) -> (tier: Tier, text: String) {
        guard let fixTime else { return (.noFix, "No fix") }
        let secs = max(0, now.timeIntervalSince(fixTime))
        if secs <= 180 {
            return (.fresh, "Fix \(Int(secs))s ago")
        } else if secs <= 600 {
            return (.stale, "Fix \(Int(secs / 60))m ago")
        } else {
            return (.old, "Fix \(Int(secs / 60))m ago")
        }
    }
}
