// MARK: - GolfRound Model
// A single round of golf with scoring, weather, and completion state

import Foundation
import SwiftData

@Model
final class GolfRound {
    var id: UUID
    var date: Date
    var course: GolfCourse?
    var weatherNotes: String
    var totalScore: Int
    var totalPutts: Int
    var playersCount: Int
    var playerNames: String // comma-separated for simplicity
    var isCompleted: Bool
    var notes: String
    var currentHole: Int
    var createdAt: Date

    // MARK: - Tee (Phase 2)
    /// Name of the tee box the golfer played from (e.g. "Blue", "White").
    /// Optional so rounds created before Phase 2 still load. When nil, the
    /// UI falls back to the course's default scorecard (HoleInfo).
    var teeName: String?

    @Relationship(deleteRule: .cascade, inverse: \HoleEntry.round)
    var holeEntries: [HoleEntry] = []

    // MARK: - GPS Shots (Pro shot tracking)
    /// Manual-tap GPS shot captures. Independent from the per-hole
    /// `ShotEntry` form-based shots. Cascades so the rows go away when
    /// the round is deleted.
    @Relationship(deleteRule: .cascade, inverse: \Shot.round)
    var shots: [Shot] = []

    // MARK: - Tee Resolution (Phase 2)
    /// Returns the CourseTee the golfer selected for this round, if any.
    /// Nil when `teeName` is unset or the course has no matching tee row.
    var selectedTee: CourseTee? {
        guard let name = teeName, let course else { return nil }
        return course.tee(named: name)
    }

    /// Total par for scoring. Prefers the selected tee's par when set,
    /// falling back to the course's default par.
    var effectivePar: Int {
        selectedTee?.par ?? course?.totalPar ?? 72
    }

    // MARK: - Computed Stats
    var scoreToPar: Int {
        totalScore - effectivePar
    }

    var scoreToParString: String {
        let diff = scoreToPar
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    var fairwayPercentage: Double {
        let eligible = holeEntries.filter { entry in
            guard let hole = entry.holeInfo else { return false }
            return hole.par >= 4
        }
        guard !eligible.isEmpty else { return 0 }
        let hit = eligible.filter { $0.fairwayHit == true }.count
        return Double(hit) / Double(eligible.count) * 100
    }

    var girPercentage: Double {
        guard !holeEntries.isEmpty else { return 0 }
        let hit = holeEntries.filter { $0.greenInRegulation }.count
        return Double(hit) / Double(holeEntries.count) * 100
    }

    var averagePutts: Double {
        guard !holeEntries.isEmpty else { return 0 }
        let total = holeEntries.reduce(0) { $0 + $1.putts }
        return Double(total) / Double(holeEntries.count)
    }

    var frontNine: Int {
        holeEntries.filter { $0.holeNumber <= 9 }.reduce(0) { $0 + $1.score }
    }

    var backNine: Int {
        holeEntries.filter { $0.holeNumber > 9 }.reduce(0) { $0 + $1.score }
    }

    init(
        course: GolfCourse? = nil,
        weatherNotes: String = "",
        playersCount: Int = 1,
        playerNames: String = "",
        teeName: String? = nil
    ) {
        self.id = UUID()
        self.date = Date()
        self.course = course
        self.weatherNotes = weatherNotes
        self.totalScore = 0
        self.totalPutts = 0
        self.playersCount = playersCount
        self.playerNames = playerNames
        self.isCompleted = false
        self.notes = ""
        self.currentHole = 1
        self.createdAt = Date()
        self.teeName = teeName
    }

    // MARK: - Recalculate Totals
    func recalculateTotals() {
        totalScore = holeEntries.reduce(0) { $0 + $1.score }
        totalPutts = holeEntries.reduce(0) { $0 + $1.putts }
    }
}
