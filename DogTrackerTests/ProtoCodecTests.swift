import XCTest
import SwiftProtobuf
@testable import DogTracker

/// Round-trip tests against the vendored Meshtastic protobuf schema.
///
/// These don't talk to a real radio — they verify the Swift types we generated
/// from `Vendor/meshtastic-protobufs/` actually wire encode/decode correctly,
/// using the message shapes we'll rely on most: an inbound `Position` carried
/// inside a `MeshPacket` inside a `FromRadio`, and the outbound Ping request
/// (a `ToRadio` carrying a `MeshPacket` with a `POSITION_APP` `DataMessage`
/// and `wantResponse = true`).
///
/// If a future protobuf version renames or renumbers any of these fields,
/// these tests fail loudly.
final class ProtoCodecTests: XCTestCase {

    /// Decode a synthetic position broadcast as if it had come from a tracker.
    func testInboundPositionRoundTrip() throws {
        // Yellowstone, just because. 1e-7 degrees fixed point per Position spec.
        var position = Position()
        position.latitudeI = 444_280_000     // 44.4280°
        position.longitudeI = -1_105_885_000 // -110.5885°
        position.altitude = 2_400            // meters MSL
        position.time = UInt32(Date().timeIntervalSince1970)
        position.satsInView = 9
        position.precisionBits = 32

        var data = DataMessage()
        data.portnum = .positionApp
        data.payload = try position.serializedData()

        var packet = MeshPacket()
        packet.from = 0xa1b2c3d4   // tracker node num
        packet.to = 0xffffffff     // broadcast
        packet.id = 12345
        packet.decoded = data

        var fromRadio = FromRadio()
        fromRadio.id = 1
        fromRadio.packet = packet

        // Wire round trip
        let bytes = try fromRadio.serializedData()
        let decoded = try FromRadio(serializedBytes: bytes)

        // Pull the inner Position back out the way the real receive path will
        guard case .packet(let decodedPacket) = decoded.payloadVariant else {
            return XCTFail("expected .packet variant in FromRadio")
        }
        XCTAssertEqual(decodedPacket.from, 0xa1b2c3d4)
        XCTAssertEqual(decodedPacket.decoded.portnum, .positionApp)

        let decodedPosition = try Position(serializedBytes: decodedPacket.decoded.payload)
        XCTAssertEqual(decodedPosition.latitudeI, 444_280_000)
        XCTAssertEqual(decodedPosition.longitudeI, -1_105_885_000)
        XCTAssertEqual(decodedPosition.altitude, 2_400)
        XCTAssertEqual(decodedPosition.satsInView, 9)
        XCTAssertEqual(decodedPosition.precisionBits, 32)
    }

    /// Build the exact "Ping" packet shape spec'd in DESIGN.md §3.4 and confirm
    /// it encodes without losing fields. The radio's response correlator on the
    /// other end will be looking for `wantResponse = true` and `portnum =
    /// POSITION_APP` — both must survive the round trip.
    func testOutboundPingPacketRoundTrip() throws {
        var data = DataMessage()
        data.portnum = .positionApp
        data.payload = Data()           // empty payload = "give me yours"
        data.wantResponse = true

        var packet = MeshPacket()
        packet.to = 0xa1b2c3d4
        packet.wantAck = true
        packet.id = 0xdead_beef
        packet.decoded = data

        var toRadio = ToRadio()
        toRadio.packet = packet

        let bytes = try toRadio.serializedData()
        let decoded = try ToRadio(serializedBytes: bytes)

        guard case .packet(let p) = decoded.payloadVariant else {
            return XCTFail("expected .packet variant in ToRadio")
        }
        XCTAssertEqual(p.to, 0xa1b2c3d4)
        XCTAssertEqual(p.id, 0xdead_beef)
        XCTAssertTrue(p.wantAck)
        XCTAssertEqual(p.decoded.portnum, .positionApp)
        XCTAssertTrue(p.decoded.wantResponse)
        XCTAssertEqual(p.decoded.payload.count, 0)
    }

    /// `wantConfigID` is the very first message we send on connect (DESIGN §3.2
    /// step 3). The radio replies with NodeDB dump + ConfigComplete. Verify the
    /// field is wired up correctly so we don't get stuck in handshake.
    func testWantConfigIDEncodes() throws {
        var toRadio = ToRadio()
        toRadio.wantConfigID = 0x1234_5678

        let bytes = try toRadio.serializedData()
        let decoded = try ToRadio(serializedBytes: bytes)

        guard case .wantConfigID(let id) = decoded.payloadVariant else {
            return XCTFail("expected .wantConfigID variant")
        }
        XCTAssertEqual(id, 0x1234_5678)
    }
}
