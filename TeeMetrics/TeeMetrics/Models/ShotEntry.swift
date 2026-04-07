// MARK: - ShotEntry Model
// Individual shot tracking within a hole

import Foundation
import SwiftData

@Model
final class ShotEntry {
    var id: UUID
    var shotNumber: Int
    var clubUsed: String
    var distanceYards: Int
    var lieType: String // tee, fairway, rough, bunker, fringe, green, penalty
    var result: String  // hit, push, pull, slice, hook, topped, chunked, perfect
    var notes: String
    var holeEntry: HoleEntry?

    init(
        shotNumber: Int,
        clubUsed: String = "",
        distanceYards: Int = 0,
        lieType: String = "tee",
        result: String = "hit",
        holeEntry: HoleEntry? = nil
    ) {
        self.id = UUID()
        self.shotNumber = shotNumber
        self.clubUsed = clubUsed
        self.distanceYards = distanceYards
        self.lieType = lieType
        self.result = result
        self.notes = ""
        self.holeEntry = holeEntry
    }
}

// MARK: - Lie Type Enum (for UI)
enum LieType: String, CaseIterable, Identifiable {
    case tee, fairway, rough, bunker, fringe, green, penalty
    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .tee: return "flag.fill"
        case .fairway: return "leaf.fill"
        case .rough: return "leaf.arrow.triangle.circlepath"
        case .bunker: return "sun.dust.fill"
        case .fringe: return "circle.dashed"
        case .green: return "circle.fill"
        case .penalty: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Shot Result Enum (for UI)
enum ShotResult: String, CaseIterable, Identifiable {
    case perfect, hit, push, pull, slice, hook, topped, chunked
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
