// MARK: - CloudKit Course Sharing Service
// Crowd-sourced courses via CloudKit public database
// Free with Apple Developer account, no backend needed
// Users can share courses they create and discover courses from the community

import Foundation
import CloudKit

// MARK: - Shared Course Record (CloudKit representation)
struct SharedCourseRecord: Identifiable {
    let id: CKRecord.ID
    let name: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
    let totalPar: Int
    let totalYardage: Int
    let slopeRating: Double
    let courseRating: Double
    // Per-hole data stored as JSON inside CKRecord["holesJSON"].
    // Each dictionary contains:
    //   num (Int), par (Int), yds (Int), hcp (Int)
    //   Optional green GPS pins (Phase 1A):
    //   greenF_lat, greenF_lon, greenC_lat, greenC_lon, greenB_lat, greenB_lon (Double)
    let holes: [[String: Any]]
    let contributorName: String
    let createdAt: Date
    let upvotes: Int

    static let recordType = "SharedCourse"
}

// MARK: - CloudKit Course Service
@MainActor @Observable
final class CloudKitCourseService {
    static let shared = CloudKitCourseService()

    var communityCourses: [SharedCourseRecord] = []
    var isLoading = false
    var errorMessage: String?
    var isAvailable = false

    private let container = CKContainer(identifier: "iCloud.com.teemetrics.app")
    private let publicDB: CKDatabase

    init() {
        publicDB = container.publicCloudDatabase
        checkAvailability()
    }

    // MARK: - Check CloudKit Availability
    private func checkAvailability() {
        Task {
            let status = try? await container.accountStatus()
            isAvailable = (status == .available)
        }
    }

    // MARK: - Upload Course to Public Database
    func shareCourse(_ course: GolfCourse, contributorName: String) async -> Bool {
        guard isAvailable else {
            errorMessage = "iCloud account required to share courses"
            return false
        }

        let record = CKRecord(recordType: SharedCourseRecord.recordType)
        record["name"] = course.name
        record["city"] = course.city
        record["state"] = course.state
        record["latitude"] = course.latitude
        record["longitude"] = course.longitude
        record["totalPar"] = course.totalPar
        record["totalYardage"] = course.totalYardage
        record["slopeRating"] = course.slopeRating
        record["courseRating"] = course.courseRating
        record["contributorName"] = contributorName
        record["upvotes"] = 0

        // Encode holes as JSON data (includes optional green GPS pins — Phase 1A)
        let sortedHoles = course.holes.sorted { $0.holeNumber < $1.holeNumber }
        let holesData = sortedHoles.map { hole -> [String: Any] in
            var dict: [String: Any] = [
                "num": hole.holeNumber,
                "par": hole.par,
                "yds": hole.yardage,
                "hcp": hole.handicapRating
            ]
            if let v = hole.greenFrontLatitude { dict["greenF_lat"] = v }
            if let v = hole.greenFrontLongitude { dict["greenF_lon"] = v }
            if let v = hole.greenCenterLatitude { dict["greenC_lat"] = v }
            if let v = hole.greenCenterLongitude { dict["greenC_lon"] = v }
            if let v = hole.greenBackLatitude { dict["greenB_lat"] = v }
            if let v = hole.greenBackLongitude { dict["greenB_lon"] = v }
            return dict
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: holesData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["holesJSON"] = jsonString
        }

        do {
            _ = try await publicDB.save(record)
            return true
        } catch {
            errorMessage = "Failed to share: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Fetch Community Courses
    func fetchCommunityCourses(searchText: String = "", state: String? = nil) async {
        isLoading = true
        errorMessage = nil

        var predicates: [NSPredicate] = [NSPredicate(value: true)]

        if !searchText.isEmpty {
            predicates = [NSPredicate(format: "name CONTAINS[cd] %@", searchText)]
        }
        if let state, !state.isEmpty {
            predicates.append(NSPredicate(format: "state == %@", state))
        }

        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let query = CKQuery(recordType: SharedCourseRecord.recordType, predicate: compound)
        query.sortDescriptors = [NSSortDescriptor(key: "upvotes", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
            var courses: [SharedCourseRecord] = []

            for (_, result) in results {
                if let record = try? result.get() {
                    if let course = parseRecord(record) {
                        courses.append(course)
                    }
                }
            }

            communityCourses = courses
        } catch {
            errorMessage = "Could not load courses: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Search Nearby Community Courses
    func fetchNearbyCourses(latitude: Double, longitude: Double, radiusKM: Double = 50) async {
        isLoading = true
        errorMessage = nil

        let location = CLLocation(latitude: latitude, longitude: longitude)

        // Fetch recent courses and filter by distance locally
        // (CloudKit location queries require a Location field type — we use lat/lng doubles instead)
        let query = CKQuery(recordType: SharedCourseRecord.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 200)
            var courses: [SharedCourseRecord] = []

            for (_, result) in results {
                if let record = try? result.get(), let course = parseRecord(record) {
                    let courseLocation = CLLocation(latitude: course.latitude, longitude: course.longitude)
                    let distance = location.distance(from: courseLocation)
                    if distance <= radiusKM * 1000 {
                        courses.append(course)
                    }
                }
            }

            communityCourses = courses
        } catch {
            errorMessage = "Could not load nearby courses: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Upvote a Course
    func upvoteCourse(_ course: SharedCourseRecord) async {
        do {
            let record = try await publicDB.record(for: course.id)
            let current = record["upvotes"] as? Int ?? 0
            record["upvotes"] = current + 1
            _ = try await publicDB.save(record)

            // Update local
            if let idx = communityCourses.firstIndex(where: { $0.id == course.id }) {
                communityCourses[idx] = parseRecord(record) ?? communityCourses[idx]
            }
        } catch {
            // Silently fail upvotes
        }
    }

    // MARK: - Import Community Course into SwiftData
    func importCourse(_ shared: SharedCourseRecord, into context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: shared.name,
            city: shared.city,
            state: shared.state,
            latitude: shared.latitude,
            longitude: shared.longitude,
            totalPar: shared.totalPar,
            totalYardage: shared.totalYardage,
            slopeRating: shared.slopeRating,
            courseRating: shared.courseRating
        )
        context.insert(course)

        for holeData in shared.holes {
            let holeInfo = HoleInfo(
                holeNumber: holeData["num"] as? Int ?? 1,
                par: holeData["par"] as? Int ?? 4,
                yardage: holeData["yds"] as? Int ?? 350,
                handicapRating: holeData["hcp"] as? Int ?? 1,
                course: course,
                greenFrontLatitude: holeData["greenF_lat"] as? Double,
                greenFrontLongitude: holeData["greenF_lon"] as? Double,
                greenCenterLatitude: holeData["greenC_lat"] as? Double,
                greenCenterLongitude: holeData["greenC_lon"] as? Double,
                greenBackLatitude: holeData["greenB_lat"] as? Double,
                greenBackLongitude: holeData["greenB_lon"] as? Double
            )
            context.insert(holeInfo)
        }

        return course
    }

    // MARK: - Parse CKRecord into SharedCourseRecord
    private func parseRecord(_ record: CKRecord) -> SharedCourseRecord? {
        guard let name = record["name"] as? String else { return nil }

        var holes: [[String: Any]] = []
        if let json = record["holesJSON"] as? String,
           let data = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            holes = parsed
        }

        return SharedCourseRecord(
            id: record.recordID,
            name: name,
            city: record["city"] as? String ?? "",
            state: record["state"] as? String ?? "",
            latitude: record["latitude"] as? Double ?? 0,
            longitude: record["longitude"] as? Double ?? 0,
            totalPar: record["totalPar"] as? Int ?? 72,
            totalYardage: record["totalYardage"] as? Int ?? 6500,
            slopeRating: record["slopeRating"] as? Double ?? 113,
            courseRating: record["courseRating"] as? Double ?? 72.0,
            holes: holes,
            contributorName: record["contributorName"] as? String ?? "Anonymous",
            createdAt: record.creationDate ?? Date(),
            upvotes: record["upvotes"] as? Int ?? 0
        )
    }
}

// MARK: - Import for CLLocation (used in distance calc)
import CoreLocation
import SwiftData
