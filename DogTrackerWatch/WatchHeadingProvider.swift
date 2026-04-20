import Foundation
import CoreLocation
import Observation

/// Reads the Apple Watch's own magnetometer heading so the compass arrow
/// re-orients as the user turns their wrist.
///
/// We intentionally do NOT request location updates — the phone is already
/// publishing its location via WatchConnectivity and that's the source of
/// truth for where the user is. The watch only needs `trueHeading`.
///
/// Apple Watch Series 5+ and all Ultra models have the compass hardware.
/// On older watches without one, `CLLocationManager.headingAvailable()`
/// returns false and we leave `trueHeading` nil; the page falls back to
/// the phone's pushed heading.
@MainActor
@Observable
final class WatchHeadingProvider: NSObject, CLLocationManagerDelegate {

    /// Current true-north heading in degrees, or nil until the user grants
    /// permission / the first heading sample arrives / hardware unavailable.
    private(set) var trueHeading: Double?
    /// Raw CLHeading accuracy. Large values (>40°) indicate the user should
    /// do the figure-8 calibration dance.
    private(set) var accuracy: Double?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // 2° filter keeps SwiftUI updates cheap — the arrow animation
        // smooths between samples anyway.
        manager.headingFilter = 2
    }

    func start() {
        guard CLLocationManager.headingAvailable() else {
            return
        }
        // WhenInUse is enough — we're only using the compass, not location.
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingHeading()
        default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in self.manager.startUpdatingHeading() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        // CLHeading isn't Sendable; cross isolation carefully.
        nonisolated(unsafe) let h = newHeading
        Task { @MainActor in
            // trueHeading is -1 when magnetic north is unavailable
            // (e.g. no GPS lock yet). Prefer magneticHeading in that case.
            if h.trueHeading >= 0 {
                self.trueHeading = h.trueHeading
            } else if h.magneticHeading >= 0 {
                self.trueHeading = h.magneticHeading
            }
            self.accuracy = h.headingAccuracy
        }
    }
}
