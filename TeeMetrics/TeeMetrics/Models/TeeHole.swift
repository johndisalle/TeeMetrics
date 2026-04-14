import Foundation
import SwiftData

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
