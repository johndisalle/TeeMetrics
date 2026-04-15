// MARK: - CourseImageService (Session C)
// Renders satellite snapshots of golf courses on demand using
// MKMapSnapshotter, with a two-layer cache so the dashboard / Courses
// list don't re-request the same image every scroll.
//
// API note: the public method takes primitive lat/lng + a cache id
// rather than a `GolfCourse` so the same service can power Home's
// "Near You" section (which uses the Sendable `NearbyCourse` struct,
// not a SwiftData @Model). A `GolfCourse` convenience overload at the
// bottom of the file routes through the same code path.
//
// Cache layers (in order):
//   1. NSCache  — in-process, ~50 entries, evicted under memory pressure
//   2. Caches/  — JPEG on disk at quality 0.8, persists across launches
//   3. Snapshot — MKMapSnapshotter call, results back-fill both caches
//
// Errors (network down, invalid coordinate, snapshot timeout) are
// swallowed and return nil. Callers fall through to a placeholder.

import Foundation
import UIKit
import MapKit

@MainActor
final class CourseImageService {
    static let shared = CourseImageService()

    private let memoryCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 50
        return c
    }()

    private let diskDir: URL = {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = cachesDir.appendingPathComponent("CourseHeroImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - Public API

    /// Renders a satellite snapshot for the given coordinate. Returns
    /// nil for invalid coordinates or any rendering failure — callers
    /// must show a placeholder in that case.
    func image(
        latitude: Double,
        longitude: Double,
        cacheID: String,
        size: CGSize
    ) async -> UIImage? {
        // Reject (0, 0) and other obviously invalid coordinates so we
        // don't waste a snapshot call on the equator off the coast of
        // Africa for legacy / unfilled courses.
        guard latitude != 0 || longitude != 0 else { return nil }

        let key = cacheKey(id: cacheID, size: size) as NSString

        // Layer 1: memory
        if let img = memoryCache.object(forKey: key) {
            return img
        }

        // Layer 2: disk
        let diskURL = diskDir.appendingPathComponent("\(key).jpg")
        if let data = try? Data(contentsOf: diskURL),
           let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: key)
            return img
        }

        // Layer 3: render via MKMapSnapshotter
        guard let img = await renderSnapshot(
            latitude: latitude,
            longitude: longitude,
            size: size
        ) else {
            return nil
        }

        memoryCache.setObject(img, forKey: key)
        // Best-effort disk write — not fatal if the cache dir is full.
        if let jpeg = img.jpegData(compressionQuality: 0.8) {
            try? jpeg.write(to: diskURL, options: .atomic)
        }
        return img
    }

    /// Convenience overload that takes a `GolfCourse` directly, so
    /// callers with a SwiftData row in hand don't have to unpack
    /// fields manually. The underlying cache key uses `course.id` so
    /// renames don't bust the cache.
    func image(for course: GolfCourse, size: CGSize) async -> UIImage? {
        await image(
            latitude: course.latitude,
            longitude: course.longitude,
            cacheID: course.id.uuidString,
            size: size
        )
    }

    // MARK: - Internals

    /// Combines the course id with the rendered pixel size so two
    /// callers asking for different sizes don't share an image.
    private func cacheKey(id: String, size: CGSize) -> String {
        "\(id)_\(Int(size.width))x\(Int(size.height))"
    }

    /// Bridges MKMapSnapshotter's completion-handler API to async/await.
    private func renderSnapshot(
        latitude: Double,
        longitude: Double,
        size: CGSize
    ) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        )
        // .satelliteFlyover is iOS 9+ but produces dramatic 3D imagery
        // for courses in metropolitan areas. Plain .satellite is a safe
        // fallback that always renders a flat orthoimage — we use that
        // here so rural courses (most golf courses in WI) don't fail.
        options.mapType = .satellite
        options.size = size
        options.scale = UIScreen.main.scale
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)

        return await withCheckedContinuation { continuation in
            snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
    }
}
