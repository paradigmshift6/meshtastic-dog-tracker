import Foundation

/// In-memory representation of a node seen on the mesh. Populated from
/// `NodeInfo` packets during the config handshake and kept up-to-date with
/// live `Position` and `MeshPacket` traffic.
struct MeshNode: Identifiable, Sendable {
    var id: UInt32 { num }

    /// Meshtastic node number — the `from` field on inbound `MeshPacket`s.
    let num: UInt32

    // User identity (from NodeInfo.user)
    var longName: String
    var shortName: String
    var hexID: String          // "!a1b2c3d4"
    var hwModel: HardwareModel

    // Most recent position
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var positionTime: Date?       // GPS time from the remote device
    var lastPositionUpdate: Date? // When we received this position

    // Link quality
    var snr: Float?
    var lastHeard: Date?
    var hopsAway: UInt32

    // Battery (from DeviceMetrics telemetry)
    /// 0–100 percentage, or nil if unknown. Values >100 mean externally powered.
    var batteryLevel: UInt32?
    /// Battery voltage in volts, or nil if unknown.
    var voltage: Float?

    /// True if battery is known and at or below 20%.
    var isBatteryLow: Bool {
        guard let level = batteryLevel, level <= 100 else { return false }
        return level <= 20
    }

    /// True if this node has a valid-looking position (not 0,0).
    var hasPosition: Bool {
        guard let lat = latitude, let lon = longitude else { return false }
        return !(lat == 0 && lon == 0)
    }
}
