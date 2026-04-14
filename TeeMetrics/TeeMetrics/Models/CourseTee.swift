// MARK: - CourseTee Model (Phase 2)
// One tee box on a GolfCourse (Blue, White, Gold, Red, etc.). Each tee has
// its own par / yardage / slope / rating and its own per-hole data
// (`TeeHole`), because yardages differ by tee box even though the green
// location is shared across all tees.
//
// Green GPS pins stay on HoleInfo (they're tee-agnostic — the green doesn't
// move based on which box you tee off from). Only par/yardage/handicap
// per hole is duplicated per tee.

import Foundation
import SwiftData

@Model
final class CourseTee {
    var id: UUID
    var name: String            // e.g. "Blue", "White", "Gold", "Red"
    var gender: String          // "male" or "female" (from GolfCourseAPI)
    var par: Int                // total par for this tee
    var yardage: Int            // total yardage for this tee
    var slope: Int              // slope rating for this tee
    var rating: Double          // course rating for this tee

    // MARK: - Relationships
    /// Back-reference to the parent course. Inverse side.
    var course: GolfCourse?

    /// Per-hole data specific to this tee box.
    @Relationship(deleteRule: .cascade, inverse: \TeeHole.tee)
    var holes: [TeeHole] = []

    /// Returns the TeeHole for a given hole number, or nil if not found.
    func hole(number: Int) -> TeeHole? {
        holes.first { $0.num == number }
    }

    init(
        name: String,
        gender: String = "male",
        par: Int = 72,
        yardage: Int = 6500,
        slope: Int = 113,
        rating: Double = 72.0,
        course: GolfCourse? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.gender = gender
        self.par = par
        self.yardage = yardage
        self.slope = slope
        self.rating = rating
        self.course = course
    }
}

// MARK: - TeeHole Model (Phase 2)
// Per-hole scorecard data for one specific tee box. Par and yardage vary by
// tee (a par-4 from the back tees might play 440y vs 380y from the middle),
// so we need a separate row per (tee × hole).

@Model
final class TeeHole {
    var id: UUID
    var num: Int        // hole number 1-18
    var par: Int
    var yardage: Int
    var handicap: Int

    /// Back-reference to the parent tee. Inverse side.
    var tee: CourseTee?

    init(
        num: Int,
        par: Int = 4,
        yardage: Int = 350,
        handicap: Int = 1,
        tee: CourseTee? = nil
    ) {
        self.id = UUID()
        self.num = num
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
        self.tee = tee
    }
}
