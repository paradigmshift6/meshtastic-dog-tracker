import Foundation
import CoreLocation
import Observation

/// Provides user location and heading updates via `CLLocationManager`.
/// `@MainActor @Observable` so SwiftUI views can bind directly.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var userLocation: CLLocation?
    var heading: CLHeading?
    var headingAccuracy: Double? { heading?.headingAccuracy }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 2  // degrees; avoids excessive updates
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        // Allow background location updates so the app continues
        // receiving dog positions while the screen is off.
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.userLocation = loc }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in self.heading = newHeading }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in self.startUpdating() }
        }
    }
}
