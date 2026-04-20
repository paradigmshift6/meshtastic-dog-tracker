import WidgetKit
import Foundation
import CoreLocation

/// A single point in the complication's timeline. We expose the closest
/// dog (by straight-line distance to the last-known phone location) and
/// the distance to it. No bearing or arrow — direction indicators in a
/// complication can't be live (separate process, no CoreLocation, and
/// WidgetKit re-renders are rate-limited) so the user is better served
/// by a simple distance readout plus an always-live arrow in the
/// in-app compass, which opens on tap.
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: FleetSnapshot
    /// The tracker with the shortest great-circle distance to the user,
    /// or nil if no trackers have a fix or no user location is available.
    let closest: TrackerSnapshot?
    let closestMeters: Double?

    static let placeholder = ComplicationEntry(
        date: .now,
        snapshot: .empty,
        closest: nil,
        closestMeters: nil
    )
}

enum ComplicationSelector {
    /// Pick the tracker with the smallest distance from the user that has
    /// a valid fix. Returns nil if there's no user location, or no
    /// tracker has reported a position yet.
    static func closest(in snapshot: FleetSnapshot)
        -> (tracker: TrackerSnapshot, meters: Double)?
    {
        guard let user = snapshot.userLocation else { return nil }
        let userCoord = CLLocationCoordinate2D(
            latitude: user.latitude,
            longitude: user.longitude
        )
        var best: (TrackerSnapshot, Double)?
        for t in snapshot.trackers {
            guard let fix = t.lastFix else { continue }
            let dogCoord = CLLocationCoordinate2D(
                latitude: fix.latitude,
                longitude: fix.longitude
            )
            let meters = BearingMath.distance(from: userCoord, to: dogCoord)
            if best == nil || meters < best!.1 {
                best = (t, meters)
            }
        }
        return best
    }
}
