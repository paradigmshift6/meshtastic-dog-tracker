import WidgetKit
import Foundation
import CoreLocation

/// A single point in the complication's timeline. We expose the closest
/// dog (by straight-line distance to the last-known phone location) plus
/// the absolute compass bearing so the complication can render a
/// direction indicator (an arrow rotated relative to true north, with
/// an "N" marker so the user knows it isn't tracking their orientation).
///
/// Why absolute bearing instead of "relative to user's heading":
/// complications can't access live heading — the widget extension runs
/// in a separate process without a CLLocationManager, and WidgetKit
/// re-renders are rate-limited well below the 60Hz a live arrow would
/// need. A relative arrow would silently lie whenever the user rotated.
/// An absolute (north-anchored) arrow is always correct: the user
/// mentally translates "the dog is northeast" and acts on it.
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: FleetSnapshot
    /// The tracker with the shortest great-circle distance to the user,
    /// or nil if no trackers have a fix or no user location is available.
    let closest: TrackerSnapshot?
    let closestMeters: Double?
    /// True compass bearing from user → closest dog, 0..360 (0 = north).
    /// nil if we don't have a user location or no tracker has a fix yet.
    let closestBearing: Double?

    static let placeholder = ComplicationEntry(
        date: .now,
        snapshot: .empty,
        closest: nil,
        closestMeters: nil,
        closestBearing: nil
    )
}

enum ComplicationSelector {
    /// Pick the tracker with the smallest distance from the user that has
    /// a valid fix. Returns nil if there's no user location, or no
    /// tracker has reported a position yet.
    static func closest(in snapshot: FleetSnapshot)
        -> (tracker: TrackerSnapshot, meters: Double, bearing: Double)?
    {
        guard let user = snapshot.userLocation else { return nil }
        let userCoord = CLLocationCoordinate2D(
            latitude: user.latitude,
            longitude: user.longitude
        )
        var best: (TrackerSnapshot, Double, Double)?
        for t in snapshot.trackers {
            guard let fix = t.lastFix else { continue }
            let dogCoord = CLLocationCoordinate2D(
                latitude: fix.latitude,
                longitude: fix.longitude
            )
            let meters = BearingMath.distance(from: userCoord, to: dogCoord)
            let bearing = BearingMath.bearing(from: userCoord, to: dogCoord)
            if best == nil || meters < best!.1 {
                best = (t, meters, bearing)
            }
        }
        return best
    }
}
