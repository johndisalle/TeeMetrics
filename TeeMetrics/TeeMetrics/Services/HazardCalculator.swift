// MARK: - HazardCalculator (Phase 2 GPS)
// Pure-function service that picks the next hazard to display in the
// live HUD during a round. Matches the StatsCalculator pattern: stateless
// `enum`, all static methods, no dependencies on UI or SwiftUI.
//
// Garmin-style "next hazard" logic: we show ONE hazard at a time — the
// nearest bunker or water hazard that is in front of the player and
// within a tight cone of their aim line toward the green. Filters:
//
//   1. Distance: ≤ 350 yards (anything further is not actionable)
//   2. "In front of" the player: dot product of
//        (player → target)  ·  (player → hazard)  > 0
//      which is just "the angle between those two bearings is < 90°"
//   3. Cone: the angle between (player → target) and (player → hazard)
//      must be ≤ ±20° so we don't leak hazards from adjacent holes
//   4. Target: the green center pin if set, else the front pin, else
//      no result at all (we have no aim line to reference)
//
// Single-point hazard model: HazardPin has one lat/lng, so `carry` and
// `into` are identical in this phase. When we add polygon hazards later,
// the return type already has both fields ready to diverge.

import Foundation
import CoreLocation

// MARK: - NextHazard result struct
struct NextHazard {
    let kind: HazardKind
    /// Yards from the player to the near edge of the hazard. For
    /// single-point pins this equals the straight-line distance.
    let carryDistance: Int
    /// Yards from the player to the far edge of the hazard. For
    /// single-point pins this equals `carryDistance`. Polygon
    /// hazards in a future phase will make these diverge.
    let intoDistance: Int
}

@MainActor
enum HazardCalculator {

    // MARK: - Tunables
    /// Maximum distance in yards at which we'll show a hazard. Anything
    /// past this is not on the current shot.
    static let maxDistanceYards: Double = 350

    /// Half-angle in degrees of the forward cone. ±20° is tight enough
    /// to ignore hazards on adjacent holes (which are usually 30°+
    /// off-axis) while still catching dogleg hazards on the current hole.
    static let coneHalfAngleDegrees: Double = 20

    /// Meters → yards.
    private static let yardsPerMeter: Double = 1.09361

    // MARK: - Public API
    /// Returns the next hazard to display in the HUD, or nil if none
    /// qualifies. See file comment for the filter logic.
    static func nextHazard(
        in hole: HoleInfo,
        from playerLocation: CLLocation
    ) -> NextHazard? {
        // 1. Resolve the aim target (green center, falling back to front).
        guard let target = targetCoordinate(for: hole) else { return nil }

        // 2. Need at least one hazard to consider.
        let hazards = hole.hazards
        guard !hazards.isEmpty else { return nil }

        let player = playerLocation.coordinate

        // 3. Build the player→target vector in local meters.
        let targetVec = localVector(from: player, to: target)
        let targetMag = magnitude(targetVec)
        // If player is standing on the target coordinate (zero-length vector)
        // there's no sensible "ahead" direction — don't show anything.
        guard targetMag > 0.001 else { return nil }

        var best: NextHazard?
        var bestDistance = Double.greatestFiniteMagnitude

        for pin in hazards {
            guard let kind = pin.hazardKind else { continue }

            let hazardCoord = CLLocationCoordinate2D(
                latitude: pin.latitude,
                longitude: pin.longitude
            )
            let hazardVec = localVector(from: player, to: hazardCoord)
            let hazardMag = magnitude(hazardVec)

            // Degenerate: player is on top of the hazard. Carry = 0.
            // Not really "ahead" but we still want to alert the user.
            if hazardMag < 0.5 {
                let zero = NextHazard(kind: kind, carryDistance: 0, intoDistance: 0)
                if bestDistance > 0 {
                    best = zero
                    bestDistance = 0
                }
                continue
            }

            // Filter A: dot product > 0 means hazard is in front of the
            // player along the target axis.
            let dot = (targetVec.x * hazardVec.x) + (targetVec.y * hazardVec.y)
            guard dot > 0 else { continue }

            // Filter B: ±20° cone from the player→target line.
            // cos(θ) = dot / (|t| * |h|)
            let cosTheta = dot / (targetMag * hazardMag)
            // Clamp for arithmetic safety before acos.
            let clamped = max(-1.0, min(1.0, cosTheta))
            let thetaRadians = acos(clamped)
            let thetaDegrees = thetaRadians * 180 / .pi
            guard thetaDegrees <= coneHalfAngleDegrees else { continue }

            // Filter C: distance cap.
            let distanceMeters = playerLocation.distance(from: CLLocation(
                latitude: pin.latitude,
                longitude: pin.longitude
            ))
            let distanceYards = distanceMeters * yardsPerMeter
            guard distanceYards <= maxDistanceYards else { continue }

            // Track the nearest qualifying hazard.
            if distanceYards < bestDistance {
                let rounded = Int(distanceYards.rounded())
                best = NextHazard(
                    kind: kind,
                    carryDistance: rounded,
                    intoDistance: rounded   // single-point: carry == into
                )
                bestDistance = distanceYards
            }
        }

        return best
    }

    // MARK: - Target resolution
    /// Returns the green center if set, else the green front, else nil.
    /// The back pin is intentionally not used as a fallback — a "back"
    /// aim line would point past the pin and make the cone wrong.
    private static func targetCoordinate(for hole: HoleInfo) -> CLLocationCoordinate2D? {
        if let lat = hole.greenCenterLatitude, let lon = hole.greenCenterLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let lat = hole.greenFrontLatitude, let lon = hole.greenFrontLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }

    // MARK: - Planar vector math
    /// Convert a lat/lng offset into local meters using an equirectangular
    /// approximation. Accurate to within a yard or two at golf-course
    /// scale (< 1 km). Much simpler than full-blown geodesics and the
    /// error is well below the precision of a consumer GPS fix.
    private static func localVector(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> (x: Double, y: Double) {
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(origin.latitude * .pi / 180)
        let dx = (destination.longitude - origin.longitude) * metersPerDegLon
        let dy = (destination.latitude - origin.latitude) * metersPerDegLat
        return (x: dx, y: dy)
    }

    private static func magnitude(_ v: (x: Double, y: Double)) -> Double {
        sqrt(v.x * v.x + v.y * v.y)
    }
}
