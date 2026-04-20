import Foundation

/// Wire format the iOS phone publishes to the watch over WatchConnectivity.
///
/// The phone sends a fresh `FleetSnapshot` (encoded as JSON in
/// `WCSession.updateApplicationContext`) whenever any tracker fix updates,
/// the user's location moves significantly, or the radio link state changes.
/// The watch caches the most recent snapshot and renders the compass directly
/// from it — bearing/distance are computed on-watch via `BearingMath`.
struct FleetSnapshot: Codable, Equatable {
    var trackers: [TrackerSnapshot]
    /// Phone's last-known location. Optional because location may not be
    /// authorized yet when the first snapshot is published.
    var userLocation: UserLocation?
    var linkState: RadioLinkState
    /// Mirror of the iOS `UnitSettings.useMetric` so the watch shows the
    /// same units without needing its own preferences screen.
    var useMetric: Bool
    var generatedAt: Date

    static let empty = FleetSnapshot(
        trackers: [],
        userLocation: nil,
        linkState: .disconnected,
        useMetric: false,
        generatedAt: .distantPast
    )
}

struct TrackerSnapshot: Codable, Equatable, Identifiable {
    var id: UInt32 { nodeNum }
    var nodeNum: UInt32
    var name: String
    var colorHex: String
    /// Thumbnail JPEG (~64x64) of the dog's photo, or nil if no photo set.
    /// Kept small so the whole FleetSnapshot fits in the 64KB
    /// `updateApplicationContext` budget.
    var photoThumbnail: Data?
    var lastFix: FixSnapshot?
    var batteryPercent: UInt32?
    var isBatteryLow: Bool
}

struct FixSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    /// GPS time of fix as reported by the tracker (Position.time).
    var fixTime: Date
    /// When the phone actually received the packet.
    var receivedAt: Date
}

struct UserLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// CLHeading.trueHeading from the phone's compass, if available.
    var trueHeading: Double?
    var capturedAt: Date
}

/// Phone↔radio link state, mirrored from `RadioController.connectionState`
/// but flattened to the cases the watch UI cares about.
enum RadioLinkState: String, Codable, Equatable {
    case disconnected
    case connecting
    case connected
}

// MARK: - Wire keys for WCSession message dictionaries

enum WatchWireKey {
    /// Application context dictionary key: JSON-encoded FleetSnapshot.
    static let snapshot = "snapshot"

    /// sendMessage payload key: operation name. Currently only "ping".
    static let op = "op"
    /// sendMessage payload key: tracker node number for a ping.
    static let nodeNum = "node"
    /// sendMessage reply key: bool indicating the request was queued on the phone.
    static let queued = "queued"
    /// sendMessage reply key: human-readable error string when queueing fails.
    static let error = "error"
}

enum WatchWireOp {
    static let ping = "ping"
}
