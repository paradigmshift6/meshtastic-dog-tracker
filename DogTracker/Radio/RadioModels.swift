import Foundation

/// Logical state of the link to a Meshtastic radio. Drives every "are we connected?"
/// indicator in the UI.
enum RadioConnectionState: Sendable, Equatable {
    case disconnected
    /// Bluetooth itself is unavailable (off, unauthorized, unsupported).
    case bluetoothUnavailable(reason: String)
    case scanning
    case connecting(name: String)
    /// BLE link is up; we're running the `wantConfigID` handshake (DESIGN §3.2).
    case configuring(name: String)
    case connected(name: String)
    case failed(reason: String)
}

/// A Meshtastic radio peripheral discovered during a scan.
struct DiscoveredPeripheral: Identifiable, Hashable, Sendable {
    let id: UUID            // CBPeripheral.identifier
    let name: String
    let rssi: Int
    let lastSeen: Date
}
