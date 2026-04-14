// MARK: - Bundled Course Importer
// Loads pre-bundled courses from JSON, imports into SwiftData with verification flag.
//
// JSON Schema (TeeMetrics/Resources/courses.json):
// [
//   {
//     "name": String, "city": String, "state": String,
//     "lat": Double, "lng": Double,
//     "par": Int, "yardage": Int,
//     "slope": Double, "rating": Double,
//     "verified": Bool,
//     "holes": [
//       {
//         "num": Int, "par": Int, "yds": Int, "hcp": Int,
//
//         // Optional green GPS pins (Phase 1A — not present in bundled file yet).
//         // When a hole has at least greenC_lat / greenC_lon, the app can show
//         // live distance-to-green during a round. Front/back are optional
//         // refinements for F/C/B yardage displays.
//         "greenF_lat": Double?, "greenF_lon": Double?,
//         "greenC_lat": Double?, "greenC_lon": Double?,
//         "greenB_lat": Double?, "greenB_lon": Double?
//       }
//     ]
//   }
// ]
//
// Note: The current bundled courses.json does NOT include green pin fields.
// They are reserved for future community-contributed pins via CloudKit.

import Foundation
import SwiftData

struct BundledCourse: Codable {
    let name: String
    let city: String
    let state: String
    let lat: Double
    let lng: Double
    let par: Int
    let yardage: Int
    let slope: Double
    let rating: Double
    let holes: [BundledHole]
    let verified: Bool
}

struct BundledHole: Codable {
    let num: Int
    let par: Int
    let yds: Int
    let hcp: Int
    // Optional green GPS pins (Phase 1A — future-proofed, not populated in courses.json yet)
    let greenF_lat: Double?
    let greenF_lon: Double?
    let greenC_lat: Double?
    let greenC_lon: Double?
    let greenB_lat: Double?
    let greenB_lon: Double?
}

@MainActor
enum BundledCourseImporter {

    // MARK: - Load all bundled courses from JSON
    static func loadBundledCourses() -> [BundledCourse] {
        guard let url = Bundle.main.url(forResource: "courses", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([BundledCourse].self, from: data)) ?? []
    }

    // MARK: - Import a single course into SwiftData
    static func importCourse(_ bundled: BundledCourse, into context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: bundled.name,
            city: bundled.city,
            state: bundled.state,
            latitude: bundled.lat,
            longitude: bundled.lng,
            totalPar: bundled.par,
            totalYardage: bundled.yardage,
            slopeRating: bundled.slope,
            courseRating: bundled.rating,
            courseSource: "bundled"
        )
        context.insert(course)

        for hole in bundled.holes {
            let holeInfo = HoleInfo(
                holeNumber: hole.num,
                par: hole.par,
                yardage: hole.yds,
                handicapRating: hole.hcp,
                course: course,
                greenFrontLatitude: hole.greenF_lat,
                greenFrontLongitude: hole.greenF_lon,
                greenCenterLatitude: hole.greenC_lat,
                greenCenterLongitude: hole.greenC_lon,
                greenBackLatitude: hole.greenB_lat,
                greenBackLongitude: hole.greenB_lon
            )
            context.insert(holeInfo)
        }

        return course
    }

    // MARK: - Check if course already imported (by name + state)
    static func isAlreadyImported(name: String, state: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<GolfCourse>(
            predicate: #Predicate { $0.name == name && $0.state == state }
        )
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    // MARK: - Search bundled courses
    static func search(_ query: String, in courses: [BundledCourse]) -> [BundledCourse] {
        if query.isEmpty { return courses }
        let q = query.lowercased()
        return courses.filter {
            $0.name.lowercased().contains(q) ||
            $0.city.lowercased().contains(q) ||
            $0.state.lowercased().contains(q)
        }
    }

    // MARK: - Filter by state
    static func coursesByState(_ courses: [BundledCourse]) -> [(String, [BundledCourse])] {
        let grouped = Dictionary(grouping: courses, by: \.state)
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
    }
}
