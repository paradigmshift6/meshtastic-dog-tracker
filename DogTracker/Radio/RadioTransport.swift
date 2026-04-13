import Foundation

/// Bytes-in/bytes-out abstraction over the Meshtastic BLE link. Lives below
/// `MeshtasticRadio`, which owns protocol semantics (handshake, packet decoding).
///
/// Two implementations exist: `BLERadioTransport` (real CoreBluetooth) and
/// `FakeRadioTransport` (in tests). The actor above can be exercised against
/// the fake without ever touching CoreBluetooth, which is essentially impossible
/// to drive from XCTest anyway.
protocol RadioTransport: AnyObject, Sendable {
    /// Stream of low-level transport events. Hot — start consuming before you
    /// trigger any operation, or you may miss the first events.
    var events: AsyncStream<TransportEvent> { get }

    func startScan()
    func stopScan()
    func connect(peripheralID: UUID)
    func disconnect()

    /// Enqueue a serialized `ToRadio` write. Non-blocking; failures surface via
    /// `TransportEvent.error` rather than throwing.
    func writeToRadio(_ data: Data)
}

/// Events the transport reports to its owner. Includes raw FROMRADIO byte
/// payloads — decoding to `FromRadio` happens in `MeshtasticRadio`.
enum TransportEvent: Sendable {
    case bluetoothStateChanged(isPoweredOn: Bool, reason: String)
    case discovered(DiscoveredPeripheral)
    case connecting(UUID)
    /// BLE link up AND all required Meshtastic characteristics discovered.
    /// Upper layer should now write `wantConfigID` to begin the handshake.
    case characteristicsReady(UUID, name: String)
    case disconnected(reason: String?)
    /// One drained FROMRADIO read. Each chunk is exactly one serialized
    /// `FromRadio` protobuf — drain logic lives in the transport.
    case fromRadioPayload(Data)
    case error(String)
}
