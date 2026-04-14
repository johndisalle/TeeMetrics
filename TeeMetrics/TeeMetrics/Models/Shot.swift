// MARK: - Shot Model (manual-tap GPS shot tracking)
// Captures one shot during a round as a pair of GPS points: the start
// (where the player struck the ball) and the end (where the ball came
// to rest, or where the next shot was struck). Shots chain together —
// the end of shot N is set when shot N+1 is recorded, or when the
// player advances holes / finishes the round.
//
// This is independent from the existing `ShotEntry` model on HoleEntry,
// which is a manual-form shot logger (lie/result/club typed by hand).
// `Shot` is the GPS-driven capture flow added in the Pro shot tracker
// session — both can coexist on the same round without interference.
//
// Pro-gated at the UI layer (see `ProFeature.shotTracking` in
// GatingManager). Non-Pro users never see the capture button so no Shot
// rows ever land in the database for them.

import Foundation
import SwiftData
import CoreLocation

@Model
final class Shot {
    var id: UUID

    /// 1-18. Stored on the shot itself rather than going through HoleEntry
    /// so that fetching shots for a hole is a simple predicate without a
    /// relationship traversal.
    var holeNumber: Int

    /// 1-indexed shot ordinal within the hole.
    var shotNumber: Int

    // MARK: - Start (always set)
    var startLatitude: Double
    var startLongitude: Double
    /// Meters above sea level. nil when the GPS fix had verticalAccuracy
    /// < 0 at the moment of capture, matching the green-pin elevation
    /// convention used by HoleInfo.
    var startElevation: Double?
    var startedAt: Date

    // MARK: - End (filled in later)
    /// Set when the *next* shot on this hole is recorded, when the user
    /// advances holes, or when the round finishes. nil means the shot is
    /// still "open".
    var endLatitude: Double?
    var endLongitude: Double?
    var endElevation: Double?
    var endedAt: Date?

    /// Free-form club name, expected to match `Club.name` from the user's
    /// bag but not a hard relation — "Driver", "7 Iron", or nil for
    /// no-club captures (penalty drops, provisionals, etc.).
    var clubName: String?

    var round: GolfRound?

    init(
        holeNumber: Int,
        shotNumber: Int,
        startLatitude: Double,
        startLongitude: Double,
        startElevation: Double? = nil,
        startedAt: Date = Date(),
        clubName: String? = nil,
        round: GolfRound? = nil
    ) {
        self.id = UUID()
        self.holeNumber = holeNumber
        self.shotNumber = shotNumber
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.startElevation = startElevation
        self.startedAt = startedAt
        self.clubName = clubName
        self.round = round
    }

    /// Great-circle distance from the start point to the end point, in
    /// yards. nil while the shot is still open. Uses CLLocation's built-in
    /// distance(from:) so we don't ship a second haversine implementation.
    /// 1 meter = 1.09361 yards.
    var distanceYards: Double? {
        guard let endLat = endLatitude, let endLon = endLongitude else { return nil }
        let start = CLLocation(latitude: startLatitude, longitude: startLongitude)
        let end = CLLocation(latitude: endLat, longitude: endLon)
        return start.distance(from: end) * 1.09361
    }

    /// True when the shot has both endpoints filled in. Convenience for
    /// the UI's "chain" detection.
    var isClosed: Bool {
        endLatitude != nil && endLongitude != nil
    }
}
