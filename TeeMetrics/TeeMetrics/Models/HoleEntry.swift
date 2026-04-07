// MARK: - HoleEntry Model
// Per-hole scoring data for a round

import Foundation
import SwiftData

@Model
final class HoleEntry {
    var id: UUID
    var holeNumber: Int
    var par: Int
    var score: Int
    var putts: Int
    var penalties: Int
    var fairwayHit: Bool?
    var greenInRegulation: Bool
    var sandSave: Bool?
    var upAndDown: Bool?
    var notes: String

    // MARK: - Relationships (inverse side — owner declares @Relationship)
    var round: GolfRound?
    var holeInfo: HoleInfo?

    @Relationship(deleteRule: .cascade, inverse: \ShotEntry.holeEntry)
    var shots: [ShotEntry] = []

    // MARK: - Score Relative to Par
    var scoreToPar: Int { score - par }

    var scoreLabel: String {
        let diff = scoreToPar
        switch diff {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        case 3: return "Triple"
        default: return "+\(diff)"
        }
    }

    var scoreLabelAccessible: String {
        let diff = scoreToPar
        switch diff {
        case ...(-3): return "Albatross, \(-diff) under par"
        case -2: return "Eagle, 2 under par"
        case -1: return "Birdie, 1 under par"
        case 0: return "Par"
        case 1: return "Bogey, 1 over par"
        case 2: return "Double bogey, 2 over par"
        case 3: return "Triple bogey, 3 over par"
        default: return "\(diff) over par"
        }
    }

    init(
        holeNumber: Int,
        par: Int = 4,
        score: Int = 0,
        putts: Int = 0,
        penalties: Int = 0,
        fairwayHit: Bool? = nil,
        greenInRegulation: Bool = false,
        round: GolfRound? = nil,
        holeInfo: HoleInfo? = nil
    ) {
        self.id = UUID()
        self.holeNumber = holeNumber
        self.par = par
        self.score = score
        self.putts = putts
        self.penalties = penalties
        self.fairwayHit = fairwayHit
        self.greenInRegulation = greenInRegulation
        self.sandSave = nil
        self.upAndDown = nil
        self.notes = ""
        self.round = round
        self.holeInfo = holeInfo
    }
}
