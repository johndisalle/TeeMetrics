// MARK: - Practice Session Model
// Range/practice sessions without a full round

import Foundation
import SwiftData

@Model
final class PracticeSession {
    var id: UUID
    var date: Date
    var sessionType: String // range, putting, chipping, full
    var durationMinutes: Int
    var notes: String
    var clubsUsed: String // comma-separated club names

    @Relationship(deleteRule: .cascade, inverse: \PracticeShot.session)
    var shots: [PracticeShot] = []

    var shotCount: Int { shots.count }

    init(
        sessionType: String = "range",
        durationMinutes: Int = 0,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = Date()
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.clubsUsed = ""
    }
}

@Model
final class PracticeShot {
    var id: UUID
    var clubUsed: String
    var distanceYards: Int
    var result: String
    var session: PracticeSession?

    init(clubUsed: String, distanceYards: Int = 0, result: String = "hit", session: PracticeSession? = nil) {
        self.id = UUID()
        self.clubUsed = clubUsed
        self.distanceYards = distanceYards
        self.result = result
        self.session = session
    }
}
