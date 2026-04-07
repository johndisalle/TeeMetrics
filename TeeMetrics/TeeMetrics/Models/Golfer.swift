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

    init(
        name: String,
        handicapIndex: Double = 0.0,
        homeCourseID: UUID? = nil,
        defaultBagID: UUID? = nil,
        avatarSystemName: String = "figure.golf"
    ) {
        self.id = UUID()
        self.name = name
        self.handicapIndex = handicapIndex
        self.homeCourseID = homeCourseID
        self.defaultBagID = defaultBagID
        self.createdAt = Date()
        self.avatarSystemName = avatarSystemName
    }
}
