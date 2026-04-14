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
    let slope_rating: Int?
    let bogey_rating: Double?
    let total_yards: Int?
    let total_meters: Int?
    let number_of_holes: Int?
    let par_total: Int?
    let front_course_rating: Double?
    let front_slope_rating: Int?
    let front_bogey_rating: Double?
    let back_course_rating: Double?
    let back_slope_rating: Int?
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
            decoded = try JSONDecoder().decode(APICourseDetail.self, from: data)
        } catch {
            throw GolfCourseAPIError.decodingFailed
        }

        rememberDetail(id, decoded)
        return decoded
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
