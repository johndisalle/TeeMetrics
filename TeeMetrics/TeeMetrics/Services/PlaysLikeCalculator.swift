// MARK: - PlaysLikeCalculator
// Pure math helper that converts a raw GPS yardage to the green into a
// "plays like" yardage by adjusting for elevation change and wind.
//
// Inputs and behavior are documented per-field. There is no I/O here —
// callers fetch wind from `WeatherService`, GPS from `RoundLocationManager`,
// and pin elevation from `HoleInfo`, then assemble a `PlaysLikeInputs`.
//
// Conventions:
// - All wind speeds are mph (US imperial — TeeMetrics ships only imperial)
// - All distances are yards
// - All elevations are meters above sea level (CLLocation native unit)
// - Bearings and wind directions are degrees, 0° = North, clockwise
// - Wind direction is **meteorological**: the direction the wind is
//   COMING FROM (so a 0° wind is a north wind blowing south)

import Foundation
import CoreLocation

// MARK: - Inputs / outputs

struct PlaysLikeInputs {
    /// Raw great-circle distance from the player to the target green pin,
    /// in yards.
    let rawDistanceYards: Double

    /// Bearing from the player to the target, degrees clockwise from north.
    let bearingToTarget: Double

    /// Player elevation in meters above sea level. nil disables the
    /// elevation adjustment.
    let userElevationMeters: Double?

    /// Target (pin) elevation in meters above sea level. nil disables the
    /// elevation adjustment.
    let targetElevationMeters: Double?

    /// Current wind reading at the course. nil disables the wind adjustment.
    let wind: WindReading?
}

struct PlaysLikeResult {
    /// Echo of the input raw distance in yards.
    let rawYards: Double

    /// Final "plays like" yardage = raw + elevation + wind. Always >= 0.
    let adjustedYards: Double

    /// Signed yards added to (positive) or subtracted from (negative) the
    /// raw distance because of elevation. Zero when no elevation data.
    let elevationAdjustYards: Double

    /// Signed yards added to (positive) or subtracted from (negative) the
    /// raw distance because of wind. Zero when no wind data.
    let windAdjustYards: Double

    /// True iff both player and target elevation were provided.
    let hasElevationData: Bool

    /// True iff a wind reading was provided.
    let hasWindData: Bool

    /// Convenience: was *any* adjustment applied? UI uses this to decide
    /// whether to render the "plays N" line at all.
    var hasAnyAdjustment: Bool {
        hasElevationData || hasWindData
    }
}

// MARK: - Calculator

enum PlaysLikeCalculator {

    /// Meters to feet conversion. Centralized here so a `grep` for
    /// elevation conversion finds exactly one site.
    static let metersToFeet = 3.28084

    /// 1% of raw distance per mph of headwind component.
    private static let headwindPerMph = 0.01
    /// 0.5% of raw distance per mph of tailwind component (tailwinds help
    /// less than headwinds hurt — the standard golf rule of thumb).
    private static let tailwindPerMph = 0.005

    /// Runs the elevation + wind math against the inputs and returns a
    /// fully populated result.
    static func compute(_ inputs: PlaysLikeInputs) -> PlaysLikeResult {

        // --- Elevation -------------------------------------------------
        // 1 yard adjustment per 1 foot of elevation delta. Up = longer
        // (positive yards), down = shorter (negative yards).
        var elevationYards: Double = 0
        let hasElevation: Bool
        if let user = inputs.userElevationMeters,
           let target = inputs.targetElevationMeters {
            let deltaMeters = target - user
            let deltaFeet = deltaMeters * metersToFeet
            elevationYards = deltaFeet
            hasElevation = true
        } else {
            hasElevation = false
        }

        // --- Wind ------------------------------------------------------
        // Headwind component (signed) = wind_speed * cos(bearing - wind_from)
        //   bearing - wind_from == 0   → wind from straight ahead = full headwind
        //   bearing - wind_from == 180 → wind from straight behind = full tailwind
        //   bearing - wind_from == 90  → pure crosswind = zero component
        var windYards: Double = 0
        let hasWind: Bool
        if let wind = inputs.wind {
            let diffDegrees = inputs.bearingToTarget - wind.direction
            let diffRadians = diffDegrees * .pi / 180.0
            let headwindComponent = wind.speed * cos(diffRadians)
            // Positive headwindComponent → headwind → +1% per mph
            // Negative headwindComponent → tailwind → +0.5% per mph (still
            // multiplies by the negative number, producing a negative yard
            // adjustment).
            if headwindComponent >= 0 {
                windYards = inputs.rawDistanceYards * headwindPerMph * headwindComponent
            } else {
                windYards = inputs.rawDistanceYards * tailwindPerMph * headwindComponent
            }
            hasWind = true
        } else {
            hasWind = false
        }

        let adjusted = max(0, inputs.rawDistanceYards + elevationYards + windYards)

        return PlaysLikeResult(
            rawYards: inputs.rawDistanceYards,
            adjustedYards: adjusted,
            elevationAdjustYards: elevationYards,
            windAdjustYards: windYards,
            hasElevationData: hasElevation,
            hasWindData: hasWind
        )
    }
}

// MARK: - Bearing extension

extension CLLocationCoordinate2D {
    /// Initial great-circle bearing from this coordinate to another, in
    /// degrees clockwise from north, normalized to 0..<360.
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
