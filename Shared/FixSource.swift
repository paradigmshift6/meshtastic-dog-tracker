import Foundation

/// How a Fix was obtained.
///
/// Lives in the Shared module so the watchOS target — which doesn't link
/// SwiftData / Fix.swift — can still type the same enum across the
/// WatchConnectivity boundary.
enum FixSource: String, Codable {
    /// Tracker's normal scheduled position broadcast.
    case scheduled
    /// Reply to a user-initiated Ping (POSITION_APP request with want_response).
    case requested
}
