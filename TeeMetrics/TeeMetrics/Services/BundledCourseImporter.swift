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
//         "greenF_lat": Double?, "greenF_lon": Double?,
//         "greenC_lat": Double?, "greenC_lon": Double?,
//         "greenB_lat": Double?, "greenB_lon": Double?
//       }
//     ],
//
//     // Phase 2: Multi-tee scorecards populated via tools/migrate_tees.py
//     // from cached GolfCourseAPI responses. Empty array for courses that
//     // didn't match the API or predate Phase 2.
//     "tees": [
//       {
//         "name": String,        // "Blue", "White", "Gold", "Red"
//         "gender": String,      // "male" or "female"
//         "par": Int,
//         "yardage": Int,
//         "slope": Int,
//         "rating": Double,
//         "holes": [{ "num": Int, "par": Int, "yds": Int, "hcp": Int }]
//       }
//     ]
//   }
// ]

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
    // Phase 2: Optional multi-tee scorecards. Missing in legacy files,
    // empty when unmatched, populated when matched via migrate_tees.py.
    let tees: [BundledTee]?
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

// MARK: - Phase 2 Tee Decoding

struct BundledTee: Codable {
    let name: String
    let gender: String
    let par: Int
    let yardage: Int
    let slope: Int
    let rating: Double
    let holes: [BundledTeeHole]
}

struct BundledTeeHole: Codable {
    let num: Int
    let par: Int
    let yds: Int
    let hcp: Int
}

@MainActor
enum BundledCourseImporter {

    // MARK: - First-launch seed
    /// Imports the entire bundled `courses.json` set (~661 courses) into
    /// SwiftData, but **only when the store is empty**. Idempotent: a
    /// second call after the seed has already happened is a no-op via
    /// the count check.
    ///
    /// Called from `MainTabView.onAppear` so the Home dashboard's
    /// "Near You" query and the Courses tab `@Query` have data to read
    /// on a fresh install. Without this, the importer was only triggered
    /// when the user manually browsed `BundledCourseBrowser` and tapped
    /// "Add" on individual rows — meaning a fresh install showed an
    /// empty Courses tab and no nearby suggestions.
    static func seedBundledCoursesIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<GolfCourse>())) ?? 0
        guard existing == 0 else {
            #if DEBUG
            print("[BundledCourseImporter] Seed skipped — \(existing) courses already in DB")
            #endif
            return
        }

        let bundled = loadBundledCourses()
        #if DEBUG
        print("[BundledCourseImporter] Seeding \(bundled.count) bundled courses on first launch")
        #endif
        guard !bundled.isEmpty else {
            #if DEBUG
            print("[BundledCourseImporter] WARNING: courses.json missing or unreadable from main bundle")
            #endif
            return
        }

        for c in bundled {
            _ = importCourse(c, into: context)
        }

        do {
            try context.save()
            #if DEBUG
            print("[BundledCourseImporter] Seed complete — \(bundled.count) courses inserted")
            #endif
        } catch {
            #if DEBUG
            print("[BundledCourseImporter] Seed save failed: \(error)")
            #endif
        }
    }

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

        // Phase 2: import tee boxes if present. When absent (legacy file or
        // unmatched course), the course gets no tees and the UI falls back
        // to the default HoleInfo scorecard.
        if let bundledTees = bundled.tees, !bundledTees.isEmpty {
            for bt in bundledTees {
                let tee = CourseTee(
                    name: bt.name,
                    gender: bt.gender,
                    par: bt.par,
                    yardage: bt.yardage,
                    slope: bt.slope,
                    rating: bt.rating,
                    course: course
                )
                context.insert(tee)

                for th in bt.holes {
                    let teeHole = TeeHole(
                        num: th.num,
                        par: th.par,
                        yardage: th.yds,
                        handicap: th.hcp,
                        tee: tee
                    )
                    context.insert(teeHole)
                }
            }
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
