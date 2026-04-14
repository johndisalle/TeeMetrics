// MARK: - Golfer Model
// Single user profile with handicap, home course reference, and default bag

import Foundation
import SwiftData

@Model
final class Golfer {
    var id: UUID
    var name: String
    var handicapIndex: Double
    var homeCourseID: UUID?
    var defaultBagID: UUID?
    var createdAt: Date
    var avatarSystemName: String

    // MARK: - Scoring Goal (Foundation Session A)
    /// User's self-selected scoring target — 100, 90, 80, 70, or nil for
    /// "I don't have one yet". Captured during onboarding and used by the
    /// dashboard/stats progress UI in Session B. Optional so the SwiftData
    /// migration stays lightweight (existing Golfer rows get nil).
    var scoringGoal: Int?

    init(
        name: String,
        handicapIndex: Double = 0.0,
        homeCourseID: UUID? = nil,
        defaultBagID: UUID? = nil,
        avatarSystemName: String = "figure.golf",
        scoringGoal: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.handicapIndex = handicapIndex
        self.homeCourseID = homeCourseID
        self.defaultBagID = defaultBagID
        self.createdAt = Date()
        self.avatarSystemName = avatarSystemName
        self.scoringGoal = scoringGoal
    }
}
