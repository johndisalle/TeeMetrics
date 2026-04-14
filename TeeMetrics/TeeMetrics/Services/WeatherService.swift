// MARK: - WeatherService
// Thin wrapper around Apple's WeatherKit that exposes a single method for
// the on-course HUD: "what is the current wind at this coordinate?"
//
// Cache:
//   - One reading per process, keyed implicitly by location proximity
//   - 15-minute TTL (wind doesn't change fast enough to justify burning
//     WeatherKit quota on every TimelineView tick)
//   - Invalidated when the user moves more than ~1 km from the cached fix
//     (catches the rare case of starting a round in a new location)
//
// Failure:
//   - All errors (no network, denied entitlement, decode failure) produce
//     a nil return. Callers (PlaysLikeCalculator) treat nil as "no wind
//     data" and skip the wind adjustment.

import Foundation
import CoreLocation
@preconcurrency import WeatherKit

/// Compact wind reading used by `PlaysLikeCalculator`. Speed is mph
/// (TeeMetrics ships only imperial units); direction is meteorological —
/// the bearing the wind is COMING FROM, in degrees clockwise from north.
struct WindReading: Hashable {
    let speed: Double      // mph
    let direction: Double  // degrees, 0 = N, clockwise
}

@MainActor
final class WeatherService {
    static let shared = WeatherService()

    private struct CachedWind {
        let reading: WindReading
        let location: CLLocation
        let timestamp: Date
    }

    private var cached: CachedWind?

    /// 15 minutes — wind rarely shifts faster than this and WeatherKit
    /// quotas care about call volume more than freshness.
    private static let cacheTTL: TimeInterval = 15 * 60

    /// 1 kilometer — if the user has somehow walked this far from where we
    /// last fetched, treat the cached reading as stale.
    private static let cacheRadiusMeters: CLLocationDistance = 1_000

    private init() {}

    /// Returns the current wind reading at the given coordinate, or nil
    /// if WeatherKit is unavailable / the network is down / the user is
    /// offline. The result is cached per the rules above.
    func currentWind(at coordinate: CLLocationCoordinate2D) async -> WindReading? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Cache hit?
        if let cached {
            let age = Date().timeIntervalSince(cached.timestamp)
            let distance = cached.location.distance(from: target)
            if age < Self.cacheTTL && distance < Self.cacheRadiusMeters {
                return cached.reading
            }
        }

        // Cache miss — fetch from WeatherKit.
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: target)
            let wind = weather.currentWeather.wind

            // WeatherKit returns wind speed as Measurement<UnitSpeed> — we
            // explicitly convert to mph so the rest of the app stays in
            // the imperial units the user expects.
            let mph = wind.speed.converted(to: .milesPerHour).value

            // wind.direction is Measurement<UnitAngle> in degrees. WeatherKit
            // already uses meteorological "from" convention so we pass it
            // through unchanged.
            let degrees = wind.direction.converted(to: .degrees).value

            let reading = WindReading(speed: mph, direction: degrees)
            cached = CachedWind(reading: reading, location: target, timestamp: Date())
            return reading
        } catch {
            // Silently degrade — nil tells the caller to skip the wind
            // component of plays-like.
            return nil
        }
    }

    /// Drop the cached reading. Useful if the round changes courses or the
    /// user asks for a manual refresh. Currently unused — included for
    /// completeness so callers don't reach into the cache directly.
    func invalidate() {
        cached = nil
    }
}
