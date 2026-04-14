// MARK: - RoundLocationManager (Phase 1C)
// High-accuracy CoreLocation wrapper used during active rounds to drive the
// live distance-to-green HUD.
//
// Why a separate manager instead of reusing CourseDetectionManager:
// - CourseDetectionManager uses kCLLocationAccuracyHundredMeters (fine for
//   "which course am I at?") and is meant for one-shot requests.
// - RoundLocationManager uses kCLLocationAccuracyBest (needed for ±1 yard
//   distance-to-green), streams continuous updates, and is explicitly
//   round-scoped with start/stop semantics so battery isn't consumed when
//   the user isn't in a round.
//
// Start/stop contract:
// - LiveRoundView.onAppear calls startTracking() — but only when the round's
//   course has at least one hole with pins (see the `anyHoleHasPins` check
//   in LiveRoundView). No pins anywhere → no GPS.
// - LiveRoundView.onDisappear and finishRound() both call stopTracking().
// - Backgrounding the app is handled by iOS (updates pause automatically
//   via pausesLocationUpdatesAutomatically = true). When the app returns
//   to the foreground in the same round, delegate callbacks resume.

import Foundation
import CoreLocation

@MainActor @Observable
final class RoundLocationManager: NSObject {
    static let shared = RoundLocationManager()

    // MARK: - Observable State
    /// Most recent high-accuracy fix. Nil until the first update arrives
    /// (or after stopTracking clears it).
    var currentLocation: CLLocation?

    /// Mirrors `CLLocationManager.authorizationStatus` so views can
    /// observe permission changes without holding a reference to CLLM.
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// True while we're actively requesting location updates. Views can
    /// use this to distinguish "round idle" from "GPS acquiring".
    var isTracking: Bool = false

    // MARK: - Private
    private let manager = CLLocationManager()

    // MARK: - Init
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = true
        manager.distanceFilter = 2.0 // only notify on 2m+ moves; cheap idle
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Start Tracking
    /// Begin streaming high-accuracy location updates. Safe to call multiple
    /// times — idempotent when already tracking. Requests "When In Use"
    /// authorization on the first call if not already granted.
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true

        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // startUpdatingLocation still works after a delayed auth grant —
            // iOS queues the request until the user answers the prompt.
        }

        manager.startUpdatingLocation()
    }

    // MARK: - Stop Tracking
    /// Stop streaming and release battery. Clears `currentLocation` so the
    /// next round starts fresh rather than snapping to a stale fix from
    /// the last course.
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        manager.stopUpdatingLocation()
        currentLocation = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension RoundLocationManager: CLLocationManagerDelegate {
    /// Delegate callbacks land on the same thread the manager was created
    /// on (main). Swift 6 concurrency still requires explicit `nonisolated`
    /// + a `Task { @MainActor in }` hop to mutate observable state.
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let fix = locations.last else { return }
        // Discard stale cached readings older than 15 seconds — iOS
        // sometimes hands you a last-known-location on startup.
        guard abs(fix.timestamp.timeIntervalSinceNow) < 15 else { return }
        // Discard wildly inaccurate readings (>50m horizontal accuracy is
        // useless for a 20-yard green).
        guard fix.horizontalAccuracy > 0 && fix.horizontalAccuracy < 50 else { return }

        Task { @MainActor in
            self.currentLocation = fix
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // Silently fail. The view layer infers signal-lost from stale
        // `currentLocation.timestamp` and surfaces the user-facing error.
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            // If the user grants permission while we were waiting, kick
            // updates now so the user doesn't have to leave and re-enter
            // the round view.
            if self.isTracking {
                switch manager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    manager.startUpdatingLocation()
                default:
                    break
                }
            }
        }
    }
}
