// MARK: - Club & Bag Models
// Club configuration with distance tracking, organized into bags

import Foundation
import SwiftData

@Model
final class Club {
    var id: UUID
    var name: String
    var clubType: String // driver, wood, hybrid, iron, wedge, putter
    var avgDistance: Int
    var maxDistance: Int
    var minDistance: Int
    var totalShots: Int
    var lastUsed: Date?
    var sortOrder: Int
    var bag: Bag?

    var systemImage: String {
        switch clubType {
        case "driver": return "figure.golf"
        case "wood": return "leaf.fill"
        case "hybrid": return "leaf.arrow.triangle.circlepath"
        case "iron": return "line.diagonal"
        case "wedge": return "triangle.fill"
        case "putter": return "hockey.puck.fill"
        default: return "sportscourt.fill"
        }
    }

    init(
        name: String,
        clubType: String,
        avgDistance: Int = 0,
        sortOrder: Int = 0,
        bag: Bag? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.clubType = clubType
        self.avgDistance = avgDistance
        self.maxDistance = avgDistance
        self.minDistance = avgDistance
        self.totalShots = 0
        self.lastUsed = nil
        self.sortOrder = sortOrder
        self.bag = bag
    }

    func updateDistance(newDistance: Int) {
        totalShots += 1
        if newDistance > maxDistance { maxDistance = newDistance }
        if newDistance < minDistance || minDistance == 0 { minDistance = newDistance }
        avgDistance = ((avgDistance * (totalShots - 1)) + newDistance) / totalShots
        lastUsed = Date()
    }
}

// MARK: - Club Type Enum (for UI)
enum ClubType: String, CaseIterable, Identifiable {
    case driver, wood, hybrid, iron, wedge, putter
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// MARK: - Bag Model
@Model
final class Bag {
    var id: UUID
    var name: String
    var isDefault: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Club.bag)
    var clubs: [Club] = []

    var sortedClubs: [Club] {
        clubs.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(name: String = "My Bag", isDefault: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isDefault = isDefault
        self.createdAt = Date()
    }

    // MARK: - Default Bag Factory
    static func createDefault() -> Bag {
        let bag = Bag(name: "My Bag", isDefault: true)
        let defaultClubs: [(String, String, Int, Int)] = [
            ("Driver", "driver", 240, 0),
            ("3 Wood", "wood", 215, 1),
            ("5 Wood", "wood", 200, 2),
            ("4 Hybrid", "hybrid", 190, 3),
            ("5 Iron", "iron", 175, 4),
            ("6 Iron", "iron", 165, 5),
            ("7 Iron", "iron", 155, 6),
            ("8 Iron", "iron", 145, 7),
            ("9 Iron", "iron", 135, 8),
            ("PW", "wedge", 120, 9),
            ("GW", "wedge", 105, 10),
            ("SW", "wedge", 90, 11),
            ("LW", "wedge", 70, 12),
            ("Putter", "putter", 0, 13),
        ]
        for (name, type, dist, order) in defaultClubs {
            bag.clubs.append(Club(name: name, clubType: type, avgDistance: dist, sortOrder: order, bag: bag))
        }
        return bag
    }
}
