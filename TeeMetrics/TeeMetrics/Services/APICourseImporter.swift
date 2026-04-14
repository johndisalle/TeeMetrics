// MARK: - API Course Importer (Session: GolfCourseAPI live search)
// Maps an `APICourseDetail` payload from `GolfCourseAPIClient` into our
// SwiftData models. Mirrors the shape of `BundledCourseImporter` so that
// imported live courses look identical to bundled ones inside the app.
//
// Dedupe rule: a second import of the same external course returns the
// existing `GolfCourse` row instead of duplicating it. Lookup is by
// `externalAPIID == "<id>"` (kept as a String to match other identifier
// fields on the model).

import Foundation
import SwiftData

@MainActor
enum APICourseImporter {

    enum ImportError: LocalizedError {
        case missingName
        case noTees

        var errorDescription: String? {
            switch self {
            case .missingName: return "The course is missing a name."
            case .noTees:      return "The course has no tee data to import."
            }
        }
    }

    /// Imports a course detail payload into SwiftData. If the course was
    /// previously imported (matched by `externalAPIID`), the existing
    /// `GolfCourse` row is returned untouched.
    @discardableResult
    static func importCourse(
        _ detail: APICourseDetail,
        into context: ModelContext
    ) throws -> GolfCourse {

        let externalID = String(detail.id)

        // Dedupe: bail out early if we already have this course.
        if let existing = try fetchExisting(externalID: externalID, in: context) {
            return existing
        }

        // Pick the most populated tee for the course-level summary fields
        // (par/yardage/slope/rating). The model still needs single values
        // here even though we also store per-tee data below.
        let allTees = (detail.tees?.male ?? []) + (detail.tees?.female ?? [])
        guard !allTees.isEmpty else { throw ImportError.noTees }

        // Prefer male tees with the largest yardage as the "primary" set,
        // falling back to whatever has data. This matches what the bundled
        // importer ends up with for most courses.
        let primary = (detail.tees?.male ?? [])
            .sorted { ($0.total_yards ?? 0) > ($1.total_yards ?? 0) }
            .first ?? allTees.first!

        let displayName = detail.course_name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? detail.course_name!
            : (detail.club_name ?? "")
        guard !displayName.isEmpty else { throw ImportError.missingName }

        let city = detail.location?.city ?? ""
        let state = detail.location?.state ?? ""
        let lat = detail.location?.latitude ?? 0
        let lon = detail.location?.longitude ?? 0

        let course = GolfCourse(
            name: displayName,
            city: city,
            state: state,
            latitude: lat,
            longitude: lon,
            totalPar: primary.par_total.map { Int($0) } ?? 72,
            totalYardage: primary.total_yards.map { Int($0) } ?? 6500,
            slopeRating: primary.slope_rating ?? 113,
            courseRating: primary.course_rating ?? 72.0,
            courseSource: "user",
            isUserImported: true,
            externalAPIID: externalID
        )
        context.insert(course)

        // Build the default 18-hole scorecard from the primary tee. The
        // `HoleInfo` rows are what the rest of the app falls back to when
        // a CourseTee isn't selected explicitly.
        let primaryHoles = primary.holes ?? []
        for i in 1...18 {
            let h = i - 1 < primaryHoles.count ? primaryHoles[i - 1] : nil
            let info = HoleInfo(
                holeNumber: i,
                par: h?.par ?? 4,
                yardage: h?.yardage ?? 350,
                handicapRating: h?.handicap ?? i,
                course: course
            )
            context.insert(info)
        }

        // Phase 2: import every tee from the API into CourseTee + TeeHole.
        // The shape is exactly what `migrate_tees.py` writes into the
        // bundled file, so courses imported live are interchangeable with
        // bundled ones at runtime.
        for tee in allTees {
            guard let teeHoles = tee.holes, teeHoles.count == 18 else { continue }

            // Determine gender by checking which array this tee came from.
            let gender: String = (detail.tees?.male?.contains(where: { $0.tee_name == tee.tee_name && $0.total_yards == tee.total_yards }) ?? false)
                ? "male"
                : "female"

            let courseTee = CourseTee(
                name: tee.tee_name ?? "Unknown",
                gender: gender,
                par: tee.par_total.map { Int($0) } ?? 72,
                yardage: tee.total_yards.map { Int($0) } ?? 6500,
                slope: tee.slope_rating.map { Int($0) } ?? 113,
                rating: tee.course_rating ?? 72.0,
                course: course
            )
            context.insert(courseTee)

            for (idx, h) in teeHoles.enumerated() {
                let teeHole = TeeHole(
                    num: idx + 1,
                    par: h.par ?? 4,
                    yardage: h.yardage ?? 350,
                    handicap: h.handicap ?? (idx + 1),
                    tee: courseTee
                )
                context.insert(teeHole)
            }
        }

        return course
    }

    // MARK: - Dedupe lookup

    /// Returns the existing GolfCourse row for this external API id, if any.
    static func fetchExisting(externalID: String, in context: ModelContext) throws -> GolfCourse? {
        let descriptor = FetchDescriptor<GolfCourse>(
            predicate: #Predicate { $0.externalAPIID == externalID }
        )
        return try context.fetch(descriptor).first
    }
}
