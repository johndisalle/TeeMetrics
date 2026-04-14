// MARK: - GolfCourse Model
// Course with 18 holes, location data, and offline MapKit region support

import Foundation
import SwiftData
import CoreLocation

@Model
final class GolfCourse {
    var id: UUID
    var name: String
    var city: String
    var state: String
    var latitude: Double
    var longitude: Double
    var totalPar: Int
    var totalYardage: Int
    var slopeRating: Double
    var courseRating: Double
    var createdAt: Date
    var isFavorite: Bool

    // MARK: - Provenance (Phase 1B)
    // Tracks where this course came from so we can gate pin-editing for
    // non-user-created courses behind Pro. nil = legacy/user-created.
    // Values: "user", "bundled", "community".
    var courseSource: String?

    // CloudKit record name for community-imported courses.
    // Used to push updated GPS pins back to the community database.
    var cloudRecordID: String?

    // MARK: - Coordinate Refinement (Phase 1B fix)
    // Set to true after a user places pins and the course's city-level
    // lat/lng has been refined toward the actual course location. Only
    // done once per course to avoid drift from later edits.
    // nil = not yet refined (or legacy row).
    var coordinatesRefined: Bool?

    // MARK: - Live API Import (Session: GolfCourseAPI live search)
    /// True when this course was fetched live from GolfCourseAPI through
    /// the in-app search flow (vs bundled, community, or hand-created).
    /// Optional so SwiftData migration stays lightweight — nil on every
    /// pre-existing row; new imports set this to true.
    var isUserImported: Bool?

    /// External API course identifier from GolfCourseAPI. Used for
    /// dedupe (so re-importing the same course returns the existing
    /// row instead of duplicating). Optional Bool/String pattern matches
    /// the courseSource / cloudRecordID fields above.
    var externalAPIID: String?

    /// True when this course was created locally by the user (free to edit pins).
    var isUserCreated: Bool {
        courseSource == nil || courseSource == "user"
    }

    @Relationship(deleteRule: .cascade, inverse: \HoleInfo.course)
    var holes: [HoleInfo] = []

    @Relationship(deleteRule: .cascade, inverse: \GolfRound.course)
    var rounds: [GolfRound] = []

    // MARK: - Tees (Phase 2)
    /// Multi-tee scorecards (Blue, White, Gold, Red, etc.). Populated from
    /// the GolfCourseAPI-sourced `tees` array in courses.json. Courses that
    /// predate Phase 2 or that didn't match the API will have an empty
    /// array — the UI falls back to the single default scorecard stored on
    /// `HoleInfo` in that case.
    @Relationship(deleteRule: .cascade, inverse: \CourseTee.course)
    var tees: [CourseTee] = []

    /// Returns the CourseTee with the given name, or nil if not found.
    func tee(named name: String) -> CourseTee? {
        tees.first { $0.name == name }
    }

    init(
        name: String,
        city: String = "",
        state: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        totalPar: Int = 72,
        totalYardage: Int = 6500,
        slopeRating: Double = 113,
        courseRating: Double = 72.0,
        isFavorite: Bool = false,
        courseSource: String? = "user",
        cloudRecordID: String? = nil,
        coordinatesRefined: Bool? = nil,
        isUserImported: Bool? = nil,
        externalAPIID: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.city = city
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
        self.totalPar = totalPar
        self.totalYardage = totalYardage
        self.slopeRating = slopeRating
        self.courseRating = courseRating
        self.createdAt = Date()
        self.isFavorite = isFavorite
        self.courseSource = courseSource
        self.cloudRecordID = cloudRecordID
        self.coordinatesRefined = coordinatesRefined
        self.isUserImported = isUserImported
        self.externalAPIID = externalAPIID
    }
}

// MARK: - HoleInfo (static course data per hole)
@Model
final class HoleInfo {
    var id: UUID
    var holeNumber: Int
    var par: Int
    var yardage: Int
    var handicapRating: Int
    var course: GolfCourse?

    // MARK: - Hazard Pins (Phase 2 GPS)
    /// Bunker and water hazard pins placed on this hole. Cascades so
    /// deleting a hole or course tears them down. Inverse is
    /// `HazardPin.hole`. Empty array for holes that haven't been
    /// mapped — the HazardCard self-hides in that case.
    @Relationship(deleteRule: .cascade, inverse: \HazardPin.hole)
    var hazards: [HazardPin] = []

    // MARK: - Green GPS Pins (Phase 1A)
    // Optional green front/center/back coordinates for on-course GPS distances.
    // All existing courses work without these — absence of pins simply disables
    // the GPS distance HUD for that hole.
    var greenFrontLatitude: Double?
    var greenFrontLongitude: Double?
    var greenCenterLatitude: Double?
    var greenCenterLongitude: Double?
    var greenBackLatitude: Double?
    var greenBackLongitude: Double?

    /// Returns true only if the green **center** coordinates are both set.
    /// Center is the minimum viable pin — front/back are optional refinements.
    var hasGreenPins: Bool {
        greenCenterLatitude != nil && greenCenterLongitude != nil
    }

    /// Returns distance in yards from a given location to the front, center,
    /// and back of the green. Any coordinate that is nil returns nil.
    /// Conversion: 1 meter = 1.09361 yards.
    func distanceYards(from location: CLLocation) -> (front: Double?, center: Double?, back: Double?) {
        func distanceYd(lat: Double?, lon: Double?) -> Double? {
            guard let lat, let lon else { return nil }
            let target = CLLocation(latitude: lat, longitude: lon)
            return location.distance(from: target) * 1.09361
        }
        return (
            front: distanceYd(lat: greenFrontLatitude, lon: greenFrontLongitude),
            center: distanceYd(lat: greenCenterLatitude, lon: greenCenterLongitude),
            back: distanceYd(lat: greenBackLatitude, lon: greenBackLongitude)
        )
    }

    init(
        holeNumber: Int,
        par: Int = 4,
        yardage: Int = 350,
        handicapRating: Int = 1,
        course: GolfCourse? = nil,
        greenFrontLatitude: Double? = nil,
        greenFrontLongitude: Double? = nil,
        greenCenterLatitude: Double? = nil,
        greenCenterLongitude: Double? = nil,
        greenBackLatitude: Double? = nil,
        greenBackLongitude: Double? = nil
    ) {
        self.id = UUID()
        self.holeNumber = holeNumber
        self.par = par
        self.yardage = yardage
        self.handicapRating = handicapRating
        self.course = course
        self.greenFrontLatitude = greenFrontLatitude
        self.greenFrontLongitude = greenFrontLongitude
        self.greenCenterLatitude = greenCenterLatitude
        self.greenCenterLongitude = greenCenterLongitude
        self.greenBackLatitude = greenBackLatitude
        self.greenBackLongitude = greenBackLongitude
    }
}
