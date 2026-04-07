// MARK: - GolfCourse Model
// Course with 18 holes, location data, and offline MapKit region support

import Foundation
import SwiftData
import CoreLocation

@Model
final class GolfCourse {
    var id: UUID
    var name: String
    var city: String
    var state: String
    var latitude: Double
    var longitude: Double
    var totalPar: Int
    var totalYardage: Int
    var slopeRating: Double
    var courseRating: Double
    var createdAt: Date
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade, inverse: \HoleInfo.course)
    var holes: [HoleInfo] = []

    @Relationship(deleteRule: .cascade, inverse: \GolfRound.course)
    var rounds: [GolfRound] = []

    init(
        name: String,
        city: String = "",
        state: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        totalPar: Int = 72,
        totalYardage: Int = 6500,
        slopeRating: Double = 113,
        courseRating: Double = 72.0,
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.city = city
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
        self.totalPar = totalPar
        self.totalYardage = totalYardage
        self.slopeRating = slopeRating
        self.courseRating = courseRating
        self.createdAt = Date()
        self.isFavorite = isFavorite
    }
}

// MARK: - HoleInfo (static course data per hole)
@Model
final class HoleInfo {
    var id: UUID
    var holeNumber: Int
    var par: Int
    var yardage: Int
    var handicapRating: Int
    var course: GolfCourse?

    init(
        holeNumber: Int,
        par: Int = 4,
        yardage: Int = 350,
        handicapRating: Int = 1,
        course: GolfCourse? = nil
    ) {
        self.id = UUID()
        self.holeNumber = holeNumber
        self.par = par
        self.yardage = yardage
        self.handicapRating = handicapRating
        self.course = course
    }
}
