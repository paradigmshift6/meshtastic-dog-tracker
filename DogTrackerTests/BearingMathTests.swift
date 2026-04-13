import XCTest
import CoreLocation
@testable import DogTracker

final class BearingMathTests: XCTestCase {

    func testBearingNorth() {
        let from = CLLocationCoordinate2D(latitude: 44.0, longitude: -110.0)
        let to   = CLLocationCoordinate2D(latitude: 45.0, longitude: -110.0)
        let b = BearingMath.bearing(from: from, to: to)
        XCTAssertEqual(b, 0, accuracy: 1, "Due north should be ~0 degrees")
    }

    func testBearingEast() {
        let from = CLLocationCoordinate2D(latitude: 44.0, longitude: -110.0)
        let to   = CLLocationCoordinate2D(latitude: 44.0, longitude: -109.0)
        let b = BearingMath.bearing(from: from, to: to)
        XCTAssertEqual(b, 90, accuracy: 2, "Due east should be ~90 degrees")
    }

    func testBearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 45.0, longitude: -110.0)
        let to   = CLLocationCoordinate2D(latitude: 44.0, longitude: -110.0)
        let b = BearingMath.bearing(from: from, to: to)
        XCTAssertEqual(b, 180, accuracy: 1, "Due south should be ~180 degrees")
    }

    func testDistanceKnownPair() {
        // Yellowstone Lake to Old Faithful: ~27 km
        let lake = CLLocationCoordinate2D(latitude: 44.4547, longitude: -110.3282)
        let of   = CLLocationCoordinate2D(latitude: 44.4605, longitude: -110.8281)
        let d = BearingMath.distance(from: lake, to: of)
        XCTAssertEqual(d, 37_500, accuracy: 5_000, "Should be roughly 37 km")
    }

    func testDistanceStringMeters() {
        XCTAssertEqual(BearingMath.distanceString(237), "237 m")
    }

    func testDistanceStringKilometers() {
        XCTAssertEqual(BearingMath.distanceString(4_321), "4.3 km")
    }
}
