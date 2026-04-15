// MARK: - GolfCourseAPI Client (Session: GolfCourseAPI live search)
// Lightweight networking layer for live course search via golfcourseapi.com.
//
// API shape (matches the cached JSON consumed by tools/migrate_tees.py):
//
//   GET /v1/search?search_query=<q>
//     → { "courses": [ APICourseSummary, ... ] }
//
//   GET /v1/courses/<id>
//     → APICourseDetail
//
// Both endpoints require:
//   Authorization: Key <GOLFCOURSE_API_KEY>
//
// The key is read at runtime from Info.plist (`GolfCourseAPIKey`) which is
// populated by Xcode from `Secrets.xcconfig` (gitignored). When the key is
// missing or empty the client throws `.notConfigured` and the UI hides the
// online section gracefully.
//
// Caching is in-memory only (no disk), keyed separately for search results
// and course detail. ~50 entries each, simple LRU.

import Foundation
import CoreLocation

// MARK: - DTOs

/// One row in the search results list. The location subfields are all
/// optional because the real API sometimes returns null for individual
/// fields (mostly older / unverified records).
struct APICourseSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let club_name: String?
    let course_name: String?
    let location: APILocation?

    /// User-facing course name. Falls back to club_name when course_name is
    /// missing. Empty string only when both are nil — those rows are
    /// filtered out at the call site.
    var displayName: String {
        if let course_name, !course_name.isEmpty { return course_name }
        if let club_name, !club_name.isEmpty { return club_name }
        return ""
    }

    /// "City, ST" or just one of the two if the other is missing.
    var displaySubtitle: String {
        let city = location?.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let state = location?.state?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch (city.isEmpty, state.isEmpty) {
        case (false, false): return "\(city), \(state)"
        case (false, true):  return city
        case (true, false):  return state
        case (true, true):   return location?.country ?? ""
        }
    }
}

struct APILocation: Decodable, Hashable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

/// Full course payload for `/v1/courses/<id>`. Mirrors the structure of the
/// cached files in `tools/api_cache/<id>.json` that `migrate_tees.py` reads.
struct APICourseDetail: Decodable {
    let id: Int
    let club_name: String?
    let course_name: String?
    let location: APILocation?
    let tees: APITeeContainer?
}

struct APITeeContainer: Decodable {
    let male: [APITee]?
    let female: [APITee]?
}

struct APITee: Decodable {
    let tee_name: String?
    let course_rating: Double?
    let slope_rating: Double?
    let bogey_rating: Double?
    let total_yards: Double?
    let total_meters: Double?
    let number_of_holes: Double?
    let par_total: Double?
    let front_course_rating: Double?
    let front_slope_rating: Double?
    let front_bogey_rating: Double?
    let back_course_rating: Double?
    let back_slope_rating: Double?
    let back_bogey_rating: Double?
    let holes: [APITeeHole]?
}

struct APITeeHole: Decodable {
    let par: Int?
    let yardage: Int?
    let handicap: Int?
}

// MARK: - Search response wrapper

private struct APISearchResponse: Decodable {
    let courses: [APICourseSummary]?
}

// MARK: - Detail response wrapper
// The /v1/courses/<id> endpoint wraps the course payload in a top-level
// `course` envelope (unlike the offline cache files that store the bare
// course object).
private struct APICourseDetailResponse: Decodable {
    let course: APICourseDetail
}

// MARK: - Errors

enum GolfCourseAPIError: LocalizedError {
    case notConfigured
    case badResponse(Int)
    case decodingFailed
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Online course search is unavailable in this build."
        case .badResponse(let code):
            return "Course server returned status \(code)."
        case .decodingFailed:
            return "Couldn't read the course server response."
        case .network(let err):
            return err.localizedDescription
        }
    }
}

// MARK: - Nearby search DTOs (Session B)

/// One row in the Home dashboard's "Near You" list. Decoupled from
/// `APICourseSummary` because the bundled-fallback path produces these
/// from local `GolfCourse` rows (which carry their own coordinate +
/// city) rather than from the API.
struct NearbyCourse: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
    /// Great-circle distance from the user's fix to this course, in
    /// miles. Computed by the caller; not part of the source data.
    let distanceMiles: Double
}

/// Sendable snapshot of a bundled `GolfCourse` row, passed into the
/// actor's `searchNearby` so non-Sendable SwiftData models never cross
/// the actor boundary. Callers convert their `[GolfCourse]` to
/// `[NearbyCandidate]` on the main actor before invoking.
struct NearbyCandidate: Sendable {
    let id: String
    let name: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Client

/// Singleton actor that fans out URLSession calls and caches results in
/// memory. Actor isolation gives us a thread-safe cache without locks.
actor GolfCourseAPIClient {
    static let shared = GolfCourseAPIClient()

    private let baseURL = URL(string: "https://api.golfcourseapi.com/v1")!
    private let session: URLSession

    // Simple bounded LRU. We keep insertion order in a separate array so we
    // can pop the least-recently-used key when over capacity. Capacity is
    // intentionally small — this is just to avoid hammering the network on
    // the same searches inside one session.
    private let cacheCapacity = 50
    private var searchCache: [String: [APICourseSummary]] = [:]
    private var searchOrder: [String] = []
    private var detailCache: [Int: APICourseDetail] = [:]
    private var detailOrder: [Int] = []

    // MARK: - Nearby cache (Session B)
    // Cache of "nearby courses" lookups, keyed by rounded coordinate +
    // radius. 15-minute TTL — wind/courses don't change much faster than
    // that and we want to avoid the bundled-distance recompute on every
    // Home re-render.
    private struct NearbyCacheEntry {
        let timestamp: Date
        let results: [NearbyCourse]
    }
    private var nearbyCache: [String: NearbyCacheEntry] = [:]
    private static let nearbyTTL: TimeInterval = 15 * 60

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 20
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Configuration

    /// True when an API key is present in Info.plist. Used by the UI to
    /// decide whether to render the online-search section at all.
    nonisolated var isConfigured: Bool {
        Self.apiKey() != nil
    }

    private static func apiKey() -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GolfCourseAPIKey") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Filter the unsubstituted xcconfig token and the placeholder value
        // so a misconfigured build degrades gracefully instead of sending a
        // bogus Authorization header.
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("$(") { return nil }
        if trimmed == "REPLACE_WITH_YOUR_GOLFCOURSE_API_KEY" { return nil }
        return trimmed
    }

    // MARK: - Public API

    /// Searches courses by free-text query. Returns an empty array for
    /// queries shorter than 3 characters (the UI also gates on this but
    /// double-checking here makes the actor safer to call from elsewhere).
    func searchCourses(query: String) async throws -> [APICourseSummary] {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard key.count >= 3 else { return [] }

        if let cached = searchCache[key] {
            touchSearch(key)
            return cached
        }

        guard let apiKey = Self.apiKey() else { throw GolfCourseAPIError.notConfigured }

        var comps = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "search_query", value: key)]
        guard let url = comps.url else { throw GolfCourseAPIError.badResponse(-1) }

        let data = try await get(url, apiKey: apiKey)
        let decoded: APISearchResponse
        do {
            decoded = try JSONDecoder().decode(APISearchResponse.self, from: data)
        } catch {
            throw GolfCourseAPIError.decodingFailed
        }

        // Drop rows with no usable display name — the row UI would render a
        // blank line otherwise.
        let results = (decoded.courses ?? []).filter { !$0.displayName.isEmpty }
        rememberSearch(key, results)
        return results
    }

    /// Fetches the full course payload by ID, including all tee boxes. The
    /// importer needs every field this returns.
    func fetchCourseDetail(id: Int) async throws -> APICourseDetail {
        if let cached = detailCache[id] {
            touchDetail(id)
            return cached
        }

        guard let apiKey = Self.apiKey() else { throw GolfCourseAPIError.notConfigured }

        let url = baseURL.appendingPathComponent("courses").appendingPathComponent("\(id)")
        let data = try await get(url, apiKey: apiKey)

        let decoded: APICourseDetail
        do {
            let envelope = try JSONDecoder().decode(APICourseDetailResponse.self, from: data)
            decoded = envelope.course
        } catch {
            throw GolfCourseAPIError.decodingFailed
        }

        rememberDetail(id, decoded)
        return decoded
    }

    // MARK: - Nearby (Session B)
    /// Returns up to `limit` courses within `radiusMiles` of the given
    /// coordinate, sorted ascending by distance.
    ///
    /// **Geo support**: golfcourseapi.com's public `/v1/search` endpoint
    /// only documents free-text search via `search_query=<q>`. There is
    /// no documented `?lat=&lng=` parameter, so this method runs
    /// **bundled-only** — it iterates over the supplied bundled
    /// `GolfCourse` rows (the 661 `courses.json` set), computes distance
    /// via Haversine, filters to the radius, and returns the closest N.
    /// Results are cached for 15 minutes per coordinate grid.
    ///
    /// If the API ever gains geo search, the upgrade path is to swap the
    /// bundled iteration here for an API call and keep the same return
    /// shape — callers don't need to change.
    func searchNearby(
        lat: Double,
        lng: Double,
        radiusMiles: Double,
        limit: Int = 3,
        candidates: [NearbyCandidate]
    ) -> [NearbyCourse] {
        let key = cacheKey(lat: lat, lng: lng, radius: radiusMiles)
        if let entry = nearbyCache[key],
           Date().timeIntervalSince(entry.timestamp) < Self.nearbyTTL {
            return Array(entry.results.prefix(limit))
        }

        let user = CLLocation(latitude: lat, longitude: lng)
        let metersPerMile = 1609.34
        let radiusMeters = radiusMiles * metersPerMile

        let results: [NearbyCourse] = candidates
            .compactMap { c -> NearbyCourse? in
                guard c.latitude != 0 || c.longitude != 0 else { return nil }
                let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
                let meters = user.distance(from: here)
                guard meters <= radiusMeters else { return nil }
                return NearbyCourse(
                    id: c.id,
                    name: c.name,
                    city: c.city,
                    state: c.state,
                    latitude: c.latitude,
                    longitude: c.longitude,
                    distanceMiles: meters / metersPerMile
                )
            }
            .sorted { $0.distanceMiles < $1.distanceMiles }

        nearbyCache[key] = NearbyCacheEntry(timestamp: Date(), results: results)
        return Array(results.prefix(limit))
    }

    /// Coordinate cache key — round to 2 decimal places so callers within
    /// a ~1 km grid get the same cached result. Plus the radius so two
    /// requests with different radii at the same point don't collide.
    private func cacheKey(lat: Double, lng: Double, radius: Double) -> String {
        let rl = (lat * 100).rounded() / 100
        let rg = (lng * 100).rounded() / 100
        return "\(rl),\(rg),\(radius)"
    }

    // MARK: - HTTP

    private func get(_ url: URL, apiKey: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw GolfCourseAPIError.badResponse(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw GolfCourseAPIError.badResponse(http.statusCode)
            }
            return data
        } catch let err as GolfCourseAPIError {
            throw err
        } catch {
            throw GolfCourseAPIError.network(error)
        }
    }

    // MARK: - LRU helpers

    private func rememberSearch(_ key: String, _ value: [APICourseSummary]) {
        searchCache[key] = value
        searchOrder.removeAll { $0 == key }
        searchOrder.append(key)
        while searchOrder.count > cacheCapacity {
            let evict = searchOrder.removeFirst()
            searchCache.removeValue(forKey: evict)
        }
    }

    private func touchSearch(_ key: String) {
        searchOrder.removeAll { $0 == key }
        searchOrder.append(key)
    }

    private func rememberDetail(_ id: Int, _ value: APICourseDetail) {
        detailCache[id] = value
        detailOrder.removeAll { $0 == id }
        detailOrder.append(id)
        while detailOrder.count > cacheCapacity {
            let evict = detailOrder.removeFirst()
            detailCache.removeValue(forKey: evict)
        }
    }

    private func touchDetail(_ id: Int) {
        detailOrder.removeAll { $0 == id }
        detailOrder.append(id)
    }
}
