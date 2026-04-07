// MARK: - Sample Data Seeder
// Creates realistic sample courses and rounds for demo/testing

import Foundation
import SwiftData

enum SampleDataSeeder {

    // MARK: - Load All Sample Data
    @MainActor
    static func loadSampleData(into context: ModelContext) {
        let course1 = createPineValley(context: context)
        let course2 = createSunsetLinks(context: context)

        // Create a default bag if none exists
        let bagDescriptor = FetchDescriptor<Bag>(predicate: #Predicate { $0.isDefault == true })
        let existingBag = try? context.fetch(bagDescriptor).first
        let bag = existingBag ?? Bag.createDefault()
        if existingBag == nil { context.insert(bag) }

        // Create 5 sample rounds across both courses
        createRound(context: context, course: course1, daysAgo: 2, scores: [4,5,3,5,4,3,5,4,5, 4,6,3,4,5,4,4,5,4], putts: [2,2,1,2,2,1,2,2,3, 2,3,2,1,2,2,2,2,2])
        createRound(context: context, course: course2, daysAgo: 6, scores: [4,4,4,4,5,3,4,5,4, 5,5,3,4,4,3,5,5,5], putts: [1,2,2,2,2,1,2,2,2, 2,2,1,2,2,2,3,2,2])
        createRound(context: context, course: course1, daysAgo: 13, scores: [5,5,3,4,5,4,4,5,4, 4,5,4,5,4,3,4,6,5], putts: [2,2,2,1,2,2,2,3,2, 2,2,2,2,1,1,2,3,2])
        createRound(context: context, course: course2, daysAgo: 20, scores: [4,5,3,5,5,3,5,6,4, 5,5,4,4,5,3,4,5,5], putts: [2,2,1,2,2,2,2,3,2, 2,2,2,2,2,1,2,2,2])
        createRound(context: context, course: course1, daysAgo: 30, scores: [5,6,4,5,4,4,5,5,5, 5,5,3,5,5,4,5,6,5], putts: [2,3,2,2,2,2,2,2,2, 2,2,1,2,3,2,2,3,2])

        try? context.save()
    }

    // MARK: - Pine Valley Golf Club
    private static func createPineValley(context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: "Pine Valley Golf Club",
            city: "Pine Valley",
            state: "NJ",
            latitude: 39.7872,
            longitude: -74.9684,
            totalPar: 72,
            totalYardage: 6765,
            slopeRating: 135,
            courseRating: 73.2,
            isFavorite: true
        )
        context.insert(course)

        let holeData: [(Int, Int, Int, Int)] = [ // (hole, par, yardage, handicap)
            (1, 4, 427, 7),  (2, 5, 530, 3),  (3, 3, 185, 15), (4, 4, 461, 1),
            (5, 4, 399, 9),  (6, 3, 190, 17), (7, 4, 430, 5),  (8, 5, 555, 11),
            (9, 4, 410, 13), (10, 4, 386, 8), (11, 5, 510, 4), (12, 3, 168, 16),
            (13, 4, 420, 6), (14, 4, 405, 2), (15, 3, 205, 18),(16, 4, 438, 10),
            (17, 5, 545, 12),(18, 4, 401, 14),
        ]
        for (num, par, yds, hcp) in holeData {
            let hole = HoleInfo(holeNumber: num, par: par, yardage: yds, handicapRating: hcp, course: course)
            context.insert(hole)
        }
        return course
    }

    // MARK: - Sunset Links (fictional)
    private static func createSunsetLinks(context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: "Sunset Links",
            city: "Monterey",
            state: "CA",
            latitude: 36.5871,
            longitude: -121.9500,
            totalPar: 72,
            totalYardage: 6480,
            slopeRating: 128,
            courseRating: 71.8
        )
        context.insert(course)

        let holeData: [(Int, Int, Int, Int)] = [
            (1, 4, 385, 5),  (2, 4, 410, 3),  (3, 4, 350, 11), (4, 4, 395, 7),
            (5, 5, 520, 1),  (6, 3, 175, 15), (7, 4, 365, 9),  (8, 5, 505, 13),
            (9, 4, 380, 17), (10, 5, 530, 2), (11, 4, 405, 6), (12, 3, 160, 18),
            (13, 4, 370, 8), (14, 4, 415, 4), (15, 3, 185, 16),(16, 4, 425, 10),
            (17, 5, 540, 12),(18, 4, 365, 14),
        ]
        for (num, par, yds, hcp) in holeData {
            let hole = HoleInfo(holeNumber: num, par: par, yardage: yds, handicapRating: hcp, course: course)
            context.insert(hole)
        }
        return course
    }

    // MARK: - Create a Round
    private static func createRound(
        context: ModelContext,
        course: GolfCourse,
        daysAgo: Int,
        scores: [Int],
        putts: [Int]
    ) {
        let round = GolfRound(course: course, weatherNotes: "", playersCount: 1, playerNames: "")
        round.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        round.isCompleted = true
        context.insert(round)

        let sortedHoles = course.holes.sorted { $0.holeNumber < $1.holeNumber }

        for i in 0..<18 {
            let holeInfo = sortedHoles.count > i ? sortedHoles[i] : nil
            let par = holeInfo?.par ?? 4
            let entry = HoleEntry(
                holeNumber: i + 1,
                par: par,
                score: scores[i],
                putts: putts[i],
                penalties: scores[i] > par + 1 ? 1 : 0,
                fairwayHit: par >= 4 ? Bool.random() : nil,
                greenInRegulation: scores[i] - putts[i] <= par - 2,
                round: round,
                holeInfo: holeInfo
            )
            context.insert(entry)
            round.holeEntries.append(entry)
        }

        round.recalculateTotals()
    }

    // MARK: - Clear Sample Data
    @MainActor
    static func clearAllData(context: ModelContext) {
        try? context.delete(model: ShotEntry.self)
        try? context.delete(model: HoleEntry.self)
        try? context.delete(model: GolfRound.self)
        try? context.delete(model: HoleInfo.self)
        try? context.delete(model: GolfCourse.self)
    }
}
