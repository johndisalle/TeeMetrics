// MARK: - Course Auto-Detection
// Uses CoreLocation to suggest nearby courses from the user's library

import Foundation
import CoreLocation
import SwiftData

@MainActor @Observable
final class CourseDetectionManager: NSObject, CLLocationManagerDelegate {
    static let shared = CourseDetectionManager()

    var currentLocation: CLLocation?
    var nearbyCourses: [GolfCourse] = []
    var suggestedCourse: GolfCourse?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Request Location
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    // MARK: - Find Nearby Courses
    func findNearbyCourses(from courses: [GolfCourse]) {
        guard let location = currentLocation else { return }

        let maxDistance: CLLocationDistance = 50_000 // 50km radius

        nearbyCourses = courses
            .filter { $0.latitude != 0 && $0.longitude != 0 }
            .map { course in
                let courseLocation = CLLocation(latitude: course.latitude, longitude: course.longitude)
                let distance = location.distance(from: courseLocation)
                return (course, distance)
            }
            .filter { $0.1 <= maxDistance }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        suggestedCourse = nearbyCourses.first
    }

    // MARK: - Distance to course (human readable)
    func distanceTo(_ course: GolfCourse) -> String? {
        guard let location = currentLocation,
              course.latitude != 0, course.longitude != 0 else { return nil }
        let courseLocation = CLLocation(latitude: course.latitude, longitude: course.longitude)
        let meters = location.distance(from: courseLocation)
        let miles = meters / 1609.34
        if miles < 1 {
            return String(format: "%.0f ft", meters * 3.281)
        }
        return String(format: "%.1f mi", miles)
    }

    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently fail — location is optional
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }
}
