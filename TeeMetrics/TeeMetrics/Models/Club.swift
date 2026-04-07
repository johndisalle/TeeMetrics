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
        createFromTemplate(.standard)
    }

    // MARK: - Bag Templates
    static func createFromTemplate(_ template: BagTemplate) -> Bag {
        let bag = Bag(name: template.name, isDefault: true)
        for (i, club) in template.clubs.enumerated() {
            bag.clubs.append(Club(name: club.0, clubType: club.1, avgDistance: club.2, sortOrder: i, bag: bag))
        }
        return bag
    }
}

// MARK: - Bag Template
enum BagTemplate: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case standard = "Standard"
    case lowHandicap = "Low Handicap"
    case senior = "Senior"
    case womens = "Women's"
    case junior = "Junior"

    var id: String { rawValue }

    var name: String { rawValue + " Bag" }

    var subtitle: String {
        switch self {
        case .beginner: return "Forgiving setup, 11 clubs"
        case .standard: return "Classic 14-club setup"
        case .lowHandicap: return "Players irons, extra wedges"
        case .senior: return "More hybrids, higher launch"
        case .womens: return "Adjusted distances, more fairway woods"
        case .junior: return "Compact starter set, 9 clubs"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "hand.wave.fill"
        case .standard: return "bag.fill"
        case .lowHandicap: return "trophy.fill"
        case .senior: return "figure.walk"
        case .womens: return "figure.stand"
        case .junior: return "figure.and.child.holdinghands"
        }
    }

    var clubCount: Int { clubs.count }

    // (name, type, avgDistance)
    var clubs: [(String, String, Int)] {
        switch self {
        case .beginner:
            return [
                ("Driver", "driver", 200),
                ("5 Wood", "wood", 170),
                ("5 Hybrid", "hybrid", 155),
                ("7 Iron", "iron", 130),
                ("8 Iron", "iron", 120),
                ("9 Iron", "iron", 110),
                ("PW", "wedge", 95),
                ("SW", "wedge", 70),
                ("Putter", "putter", 0),
            ]
        case .standard:
            return [
                ("Driver", "driver", 240),
                ("3 Wood", "wood", 215),
                ("5 Wood", "wood", 200),
                ("4 Hybrid", "hybrid", 190),
                ("5 Iron", "iron", 175),
                ("6 Iron", "iron", 165),
                ("7 Iron", "iron", 155),
                ("8 Iron", "iron", 145),
                ("9 Iron", "iron", 135),
                ("PW", "wedge", 120),
                ("GW", "wedge", 105),
                ("SW", "wedge", 90),
                ("LW", "wedge", 70),
                ("Putter", "putter", 0),
            ]
        case .lowHandicap:
            return [
                ("Driver", "driver", 275),
                ("3 Wood", "wood", 250),
                ("3 Iron", "iron", 220),
                ("4 Iron", "iron", 210),
                ("5 Iron", "iron", 195),
                ("6 Iron", "iron", 183),
                ("7 Iron", "iron", 170),
                ("8 Iron", "iron", 158),
                ("9 Iron", "iron", 145),
                ("PW", "wedge", 132),
                ("50\u{00B0}", "wedge", 115),
                ("54\u{00B0}", "wedge", 100),
                ("58\u{00B0}", "wedge", 80),
                ("Putter", "putter", 0),
            ]
        case .senior:
            return [
                ("Driver", "driver", 210),
                ("3 Wood", "wood", 190),
                ("5 Wood", "wood", 175),
                ("7 Wood", "wood", 160),
                ("4 Hybrid", "hybrid", 155),
                ("5 Hybrid", "hybrid", 145),
                ("6 Iron", "iron", 140),
                ("7 Iron", "iron", 130),
                ("8 Iron", "iron", 120),
                ("9 Iron", "iron", 110),
                ("PW", "wedge", 100),
                ("SW", "wedge", 75),
                ("Putter", "putter", 0),
            ]
        case .womens:
            return [
                ("Driver", "driver", 180),
                ("3 Wood", "wood", 160),
                ("5 Wood", "wood", 145),
                ("7 Wood", "wood", 130),
                ("5 Hybrid", "hybrid", 125),
                ("6 Hybrid", "hybrid", 115),
                ("7 Iron", "iron", 105),
                ("8 Iron", "iron", 95),
                ("9 Iron", "iron", 85),
                ("PW", "wedge", 75),
                ("SW", "wedge", 55),
                ("Putter", "putter", 0),
            ]
        case .junior:
            return [
                ("Driver", "driver", 160),
                ("5 Wood", "wood", 130),
                ("5 Hybrid", "hybrid", 115),
                ("7 Iron", "iron", 100),
                ("9 Iron", "iron", 80),
                ("PW", "wedge", 65),
                ("SW", "wedge", 45),
                ("Putter", "putter", 0),
            ]
        }
    }
}
