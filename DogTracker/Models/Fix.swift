import Foundation
import SwiftData

/// How a Fix was obtained.
enum FixSource: String, Codable {
    /// Tracker's normal scheduled position broadcast.
    case scheduled
    /// Reply to a user-initiated Ping (POSITION_APP request with want_response).
    case requested
}

/// One GPS position report from a tracker.
@Model
final class Fix {
    var tracker: Tracker?

    var latitude: Double
    var longitude: Double
    var altitude: Double?

    /// GPS time of fix as reported by the tracker (Position.time).
    var fixTime: Date

    /// When the phone actually received the packet.
    var receivedAt: Date

    var sats: Int?
    var precisionBits: Int?

    var source: FixSource

    init(
        tracker: Tracker? = nil,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        fixTime: Date,
        receivedAt: Date = .now,
        sats: Int? = nil,
        precisionBits: Int? = nil,
        source: FixSource
    ) {
        self.tracker = tracker
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.fixTime = fixTime
        self.receivedAt = receivedAt
        self.sats = sats
        self.precisionBits = precisionBits
        self.source = source
    }
}
