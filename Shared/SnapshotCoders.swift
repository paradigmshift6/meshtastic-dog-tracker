import Foundation

/// JSON encoders/decoders for `FleetSnapshot` payloads sent over
/// WatchConnectivity. Defined in the shared module so the iOS and watchOS
/// targets agree on date encoding (ISO-8601) and any future tweaks.
extension JSONEncoder {
    static let snapshot: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let snapshot: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
