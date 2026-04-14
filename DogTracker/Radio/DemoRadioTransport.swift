import Foundation
import OSLog

/// A simulated `RadioTransport` that feeds synthetic Meshtastic packets for
/// demo/review purposes. Allows the full app to function without real BLE
/// hardware — the map shows moving dog markers, compass works, trails build up.
///
/// Activated via Settings → Demo Mode or the `DEMO_MODE` launch argument.
final class DemoRadioTransport: RadioTransport, @unchecked Sendable {

    let events: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation
    private let log = Logger(subsystem: "com.levijohnson.DogTracker", category: "Demo")
    private var updateTask: Task<Void, Never>?

    // MARK: - Demo node configuration

    /// Companion node (the user's Meshtastic radio)
    static let companionNodeNum: UInt32 = 0xDE000001
    static let companionName = "Demo Companion"

    /// Demo dog trackers
    struct DemoDog {
        let nodeNum: UInt32
        let longName: String
        let shortName: String
        let colorHex: String
        /// Base latitude/longitude (Yellowstone area)
        let baseLat: Double
        let baseLon: Double
    }

    static let demoDogs: [DemoDog] = [
        DemoDog(nodeNum: 0xDE000101, longName: "Maple",  shortName: "MPL", colorHex: "#E74C3C",
                baseLat: 44.4605, baseLon: -110.8281),
        DemoDog(nodeNum: 0xDE000102, longName: "Bear",   shortName: "BER", colorHex: "#2ECC71",
                baseLat: 44.4598, baseLon: -110.8265),
        DemoDog(nodeNum: 0xDE000103, longName: "Scout",  shortName: "SCT", colorHex: "#3498DB",
                baseLat: 44.4612, baseLon: -110.8300),
    ]

    /// The "user" location for demo — near Old Faithful, Yellowstone
    static let userLat = 44.4600
    static let userLon = -110.8280

    init() {
        var c: AsyncStream<TransportEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { c = $0 }
        continuation = c
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - RadioTransport

    func startScan() {
        log.info("demo: startScan")
    }

    func stopScan() {
        log.info("demo: stopScan")
    }

    func connect(peripheralID: UUID) {
        log.info("demo: connect \(peripheralID)")
        // Simulate connection after a short delay
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await beginDemoSession()
        }
    }

    func disconnect() {
        log.info("demo: disconnect")
        updateTask?.cancel()
        updateTask = nil
        continuation.yield(.disconnected(reason: "Demo disconnected"))
    }

    func writeToRadio(_ data: Data) {
        // Parse the ToRadio to capture wantConfigID for the handshake
        captureWrite(data)
    }

    // MARK: - Demo session

    /// Simulates the full Meshtastic handshake and then starts periodic position updates.
    @Sendable
    private func beginDemoSession() async {
        let demoUUID = UUID(uuidString: "00000000-DE00-DE00-DE00-000000000000")!

        // 1. BLE connected
        continuation.yield(.bluetoothStateChanged(isPoweredOn: true, reason: ""))
        try? await Task.sleep(for: .milliseconds(200))
        continuation.yield(.characteristicsReady(demoUUID, name: Self.companionName))

        // 2. Wait for wantConfigID to be sent (MeshtasticRadio will write it)
        try? await Task.sleep(for: .milliseconds(300))

        // 3. Send MyNodeInfo
        var myInfo = MyNodeInfo()
        myInfo.myNodeNum = Self.companionNodeNum

        var fr1 = FromRadio()
        fr1.myInfo = myInfo
        emitFromRadio(fr1)
        try? await Task.sleep(for: .milliseconds(100))

        // 4. Send companion NodeInfo
        emitNodeInfo(
            num: Self.companionNodeNum,
            longName: Self.companionName,
            shortName: "DEM",
            hwModel: .heltecV3
        )
        try? await Task.sleep(for: .milliseconds(100))

        // 5. Send dog tracker NodeInfos
        for dog in Self.demoDogs {
            emitNodeInfo(
                num: dog.nodeNum,
                longName: dog.longName,
                shortName: dog.shortName,
                hwModel: .trackerT1000E
            )
            try? await Task.sleep(for: .milliseconds(50))
        }

        // 6. Send channel configs
        emitChannel(index: 0, role: .primary, name: "", psk: Data([1]))
        try? await Task.sleep(for: .milliseconds(50))
        emitChannel(index: 1, role: .secondary, name: "DogTrk", psk: Data(repeating: 0xAB, count: 32))
        try? await Task.sleep(for: .milliseconds(100))

        // 7. Complete handshake — echo back the wantConfigID that MeshtasticRadio
        //    sent us (captured in writeToRadio → captureWrite).
        //    Wait briefly for the radio actor to process characteristicsReady and
        //    call writeToRadio with the wantConfigID.
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            if readConfigID() > 0 { break }
        }

        let configID = readConfigID()

        var fr7 = FromRadio()
        fr7.configCompleteID = configID
        emitFromRadio(fr7)
        log.info("demo: sent configCompleteID=\(configID)")

        try? await Task.sleep(for: .milliseconds(200))

        // 8. Send initial positions for all dogs
        for dog in Self.demoDogs {
            emitPosition(nodeNum: dog.nodeNum, lat: dog.baseLat, lon: dog.baseLon, alt: 2250)
        }

        log.info("demo: initial handshake complete, starting position updates")

        // 9. Start periodic position updates (simulates 2-minute broadcast interval)
        startPeriodicUpdates()
    }

    private var lastCapturedConfigID: UInt32 = 0
    private let lock = NSLock()

    /// Thread-safe read of the captured config ID. Extracted to a non-async
    /// method so NSLock doesn't trigger Swift 6 warnings.
    private nonisolated func readConfigID() -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        return lastCapturedConfigID
    }

    // MARK: - Helpers

    private func emitFromRadio(_ msg: FromRadio) {
        guard let data = try? msg.serializedData() else { return }
        continuation.yield(.fromRadioPayload(data))
    }

    private func emitNodeInfo(num: UInt32, longName: String, shortName: String, hwModel: HardwareModel) {
        var user = User()
        user.id = String(format: "!%08x", num)
        user.longName = longName
        user.shortName = shortName
        user.hwModel = hwModel

        var nodeInfo = NodeInfo()
        nodeInfo.num = num
        nodeInfo.user = user
        nodeInfo.lastHeard = UInt32(Date().timeIntervalSince1970)

        var fr = FromRadio()
        fr.nodeInfo = nodeInfo
        emitFromRadio(fr)
    }

    private func emitChannel(index: Int32, role: Channel.Role, name: String, psk: Data) {
        var modSettings = ModuleSettings()
        modSettings.positionPrecision = role == .primary ? 0 : 32

        var settings = ChannelSettings()
        settings.name = name
        settings.psk = psk
        settings.moduleSettings = modSettings

        var channel = Channel()
        channel.index = index
        channel.role = role
        channel.settings = settings

        var fr = FromRadio()
        fr.channel = channel
        emitFromRadio(fr)
    }

    private func emitPosition(nodeNum: UInt32, lat: Double, lon: Double, alt: Int32) {
        var position = Position()
        position.latitudeI = Int32(lat * 1e7)
        position.longitudeI = Int32(lon * 1e7)
        position.altitude = alt
        position.time = UInt32(Date().timeIntervalSince1970)
        position.satsInView = UInt32.random(in: 8...14)
        position.precisionBits = 32

        var data = DataMessage()
        data.portnum = .positionApp
        data.payload = (try? position.serializedData()) ?? Data()

        var packet = MeshPacket()
        packet.from = nodeNum
        packet.to = 0xFFFFFFFF  // broadcast
        packet.channel = 1     // DogTrk channel
        packet.decoded = data
        packet.rxSnr = Float.random(in: 5...12)

        var fr = FromRadio()
        fr.packet = packet
        emitFromRadio(fr)
    }

    // MARK: - Periodic updates

    /// Simulates dogs moving around their base positions every 15 seconds
    /// (compressed from the real 2-minute interval for demo purposes).
    private func startPeriodicUpdates() {
        updateTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self else { return }

                tick += 1

                // Move each dog slightly — simulate natural wandering
                for dog in Self.demoDogs {
                    let angle = Double(tick) * 0.3 + Double(dog.nodeNum) * 1.5
                    let radius = 0.0005 + 0.0003 * sin(Double(tick) * 0.1 + Double(dog.nodeNum))
                    let lat = dog.baseLat + radius * sin(angle)
                    let lon = dog.baseLon + radius * cos(angle)
                    let alt = Int32(2250 + Int(20 * sin(Double(tick) * 0.15 + Double(dog.nodeNum))))

                    self.emitPosition(nodeNum: dog.nodeNum, lat: lat, lon: lon, alt: alt)
                }

                self.log.info("demo: emitted position update tick=\(tick)")
            }
        }
    }
}

// MARK: - Capture wantConfigID

extension DemoRadioTransport {
    /// Called from a custom override to capture the wantConfigID the radio sends.
    /// Since RadioTransport.writeToRadio doesn't return anything, we parse
    /// the ToRadio protobuf here to extract it.
    func captureWrite(_ data: Data) {
        if let toRadio = try? ToRadio(serializedBytes: data) {
            if toRadio.wantConfigID > 0 {
                lock.lock()
                lastCapturedConfigID = toRadio.wantConfigID
                lock.unlock()
                log.info("demo: captured wantConfigID=\(toRadio.wantConfigID)")
            }
        }
    }
}
