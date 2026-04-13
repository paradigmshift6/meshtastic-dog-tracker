import Foundation
import SwiftData

/// A Meshtastic node the user has assigned as a "dog tracker".
@Model
final class Tracker {
    /// Meshtastic node number (the `from` field on incoming MeshPackets).
    @Attribute(.unique) var nodeNum: UInt32

    /// User-assigned display name (e.g. "Maple").
    var name: String

    /// Hex color string ("#RRGGBB") used for the marker ring and compass arrow.
    var colorHex: String

    /// Optional dog photo, JPEG-compressed to ~256x256 by the assignment UI.
    /// Stored externally so SwiftData doesn't bloat its main store.
    @Attribute(.externalStorage) var photoData: Data?

    /// When the user first assigned this node as a dog.
    var assignedAt: Date

    /// Position history. Cascade so deleting a tracker drops its fixes.
    @Relationship(deleteRule: .cascade, inverse: \Fix.tracker)
    var fixes: [Fix] = []

    init(
        nodeNum: UInt32,
        name: String,
        colorHex: String,
        photoData: Data? = nil,
        assignedAt: Date = .now
    ) {
        self.nodeNum = nodeNum
        self.name = name
        self.colorHex = colorHex
        self.photoData = photoData
        self.assignedAt = assignedAt
    }
}
