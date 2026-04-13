import Foundation
@testable import DogTracker

/// In-memory `RadioTransport` used by tests. Lets a test feed synthetic
/// transport events into a `MeshtasticRadio` and inspect what the radio sends
/// back out via `writeToRadio`.
final class FakeRadioTransport: RadioTransport, @unchecked Sendable {

    let events: AsyncStream<TransportEvent>
    private let cont: AsyncStream<TransportEvent>.Continuation

    private let lock = NSLock()
    private var _writes: [Data] = []
    private(set) var startScanCalled = false
    private(set) var connectCalled: UUID?
    private(set) var disconnectCalled = false

    var writes: [Data] {
        lock.lock(); defer { lock.unlock() }
        return _writes
    }

    init() {
        var c: AsyncStream<TransportEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { c = $0 }
        cont = c
    }

    func feed(_ event: TransportEvent) {
        cont.yield(event)
    }

    // MARK: - RadioTransport

    func startScan() { startScanCalled = true }
    func stopScan()  {}
    func connect(peripheralID: UUID) { connectCalled = peripheralID }
    func disconnect() { disconnectCalled = true }

    func writeToRadio(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        _writes.append(data)
    }
}
