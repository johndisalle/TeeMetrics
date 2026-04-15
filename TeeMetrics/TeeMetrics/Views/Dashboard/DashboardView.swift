// MARK: - Home Dashboard (Session B rebuild)
// Six stacked sections, in order:
//   A) Greeting + handicap badge
//   B) Primary "Start Round" CTA (or Resume Round if one is in progress)
//   C) Goal progress card  (conditional — golfer.scoringGoal != nil)
//   D) Last round card     (conditional — at least one completed round,
//                            otherwise a soft empty state)
//   E) Near You             (3 closest courses within 25 mi)
//   F) Weather at nearest course (Pro only, free tier hides it)
//
// Location uses the existing CourseDetectionManager singleton (it
// already provides one-shot fixes via requestLocation()), not a new
// HomeLocationProvider — that singleton predates this session and we
// want to keep just one Home-level location consumer to avoid
// double-prompting.

import SwiftUI
import SwiftData
import CoreLocation

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.date, order: .reverse) private var allRounds: [GolfRound]
    @Query private var golfers: [Golfer]
    @Query private var allCourses: [GolfCourse]
    @State private var showNewRound = false

    @State private var locationManager = CourseDetectionManager.shared

    // Section E state
    @State private var nearby: [NearbyCourse] = []
    @State private var nearbyLoading = false
    @State private var nearbyError: String?
    @State private var loadedForCoordKey: String?

    // Section F state
    @State private var nearestWeather: WindReading?
    @State private var weatherLoadedForKey: String?

    // MARK: - Derived state
    private var golfer: Golfer? { golfers.first }

    private var completedRounds: [GolfRound] {
        allRounds.filter { $0.isCompleted }
    }

    private var lastRound: GolfRound? {
        completedRounds.first
    }

    private var activeRound: GolfRound? {
        allRounds.first { !$0.isCompleted }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    /// Average over the most recent 5 completed rounds. Returns nil
    /// when the user has no rounds at all; the goal card uses the
    /// "play N more rounds" copy when fewer than 5 exist.
    private var avgLast5: Double? {
        let recent = completedRounds.prefix(5)
        guard !recent.isEmpty else { return nil }
        let total = recent.reduce(0) { $0 + $1.totalScore }
        return Double(total) / Double(recent.count)
    }

    private var nearbyWeatherUnlocked: Bool {
        !GatingManager.shared.requiresPro(feature: .nearbyWeather)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // A
                    headerSection
                    // B
                    primaryPlaySection
                    // C
                    if let goal = golfer?.scoringGoal {
                        goalCard(goal: goal)
                    }
                    // D
                    lastRoundSection
                    // E
                    nearbySection
                    // F
                    if nearbyWeatherUnlocked, let nearest = nearby.first, nearestWeather != nil {
                        weatherCard(for: nearest)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewRound) {
                NewRoundView()
            }
            .task {
                #if DEBUG
                print("[DashboardView] allCourses count: \(allCourses.count), completedRounds: \(completedRounds.count)")
                #endif
                await loadNearbyIfPossible()
            }
            // Re-fire the nearby load when a fresh GPS fix arrives.
            // CLLocation isn't Equatable, so we key on its timestamp
            // instead — Date? satisfies onChange's Equatable requirement
            // and only changes when a new fix lands.
            .onChange(of: locationManager.currentLocation?.timestamp) { _, _ in
                Task { await loadNearbyIfPossible() }
            }
        }
    }

    // MARK: - Section A — Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                Text(firstName)
                    .font(.title.bold())
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            handicapBadge
        }
    }

    private var firstName: String {
        let full = golfer?.name ?? "Golfer"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    @ViewBuilder
    private var handicapBadge: some View {
        if let g = golfer, g.handicapIndex > 0 {
            HStack(spacing: 4) {
                Text("HCP")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.textMuted)
                Text(String(format: "%.1f", g.handicapIndex))
                    .font(.caption.bold())
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surface)
            .clipShape(Capsule())
        }
    }

    // MARK: - Section B — Primary Play CTA
    @ViewBuilder
    private var primaryPlaySection: some View {
        if let active = activeRound {
            NavigationLink {
                LiveRoundView(round: active)
            } label: {
                playButtonLabel(
                    icon: "play.circle.fill",
                    title: "Resume Round",
                    subtitle: "Hole \(active.currentHole) · \(active.course?.name ?? "Round in progress")"
                )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Haptics.medium()
                showNewRound = true
            } label: {
                playButtonLabel(
                    icon: "flag.fill",
                    title: "Start Round",
                    subtitle: nil
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func playButtonLabel(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Section C — Goal progress
    private func goalCard(goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal: Break \(goal)")
                .font(.headline)
                .foregroundStyle(Theme.text)

            if completedRounds.count < 5 {
                Text("Play \(5 - completedRounds.count) more rounds to see progress")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
            } else if let avg = avgLast5 {
                let delta = avg - Double(goal)
                let deltaText: String = {
                    if delta <= 0 {
                        return "you're \(String(format: "%.1f", -delta)) under"
                    }
                    return "\(String(format: "%.1f", delta)) to goal"
                }()
                Text("Avg last 5 rounds: \(String(format: "%.1f", avg)) (\(deltaText))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Section D — Last round
    @ViewBuilder
    private var lastRoundSection: some View {
        if let round = lastRound {
            NavigationLink {
                RoundDetailView(round: round)
            } label: {
                lastRoundCard(round)
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "flag")
                        .foregroundStyle(Theme.textMuted)
                    Text("Your first round will appear here")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                }
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func lastRoundCard(_ round: GolfRound) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.course?.name ?? "Unknown Course")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(round.date.relativeFormatted)
                    Text("·")
                    Text("\(round.totalScore)")
                    Text("(\(round.scoreToParString))")
                }
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.textMuted)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Section E — Near You
    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Near You")
                .font(.headline)
                .foregroundStyle(Theme.text)

            nearbyContent
        }
    }

    @ViewBuilder
    private var nearbyContent: some View {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            nearbyMessageCard(
                icon: "location.slash",
                title: "Nearby courses unavailable",
                subtitle: "Enable location in Settings",
                action: openAppSettings,
                actionLabel: "Open"
            )
        case .notDetermined:
            nearbyMessageCard(
                icon: "location",
                title: "Enable location to see nearby courses",
                subtitle: nil,
                action: { locationManager.requestLocation() },
                actionLabel: "Enable"
            )
        default:
            if nearbyLoading {
                VStack(spacing: 8) {
                    nearbySkeletonRow
                    nearbySkeletonRow
                    nearbySkeletonRow
                }
            } else if let err = nearbyError {
                nearbyMessageCard(
                    icon: "wifi.exclamationmark",
                    title: "Can't load nearby courses right now",
                    subtitle: err,
                    action: nil,
                    actionLabel: nil
                )
            } else if nearby.isEmpty {
                nearbyMessageCard(
                    icon: "mappin.slash",
                    title: "No courses within 25 miles",
                    subtitle: nil,
                    action: nil,
                    actionLabel: nil
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(nearby) { course in
                        nearbyRow(course)
                    }
                }
            }
        }
    }

    private func nearbyRow(_ course: NearbyCourse) -> some View {
        HStack(spacing: 12) {
            // Compact 48x48 satellite hero — matches Home's denser row
            // height vs the 64x64 used in the Courses tab list.
            CourseHeroImage(
                latitude: course.latitude,
                longitude: course.longitude,
                cacheID: course.id,
                size: CGSize(width: 48, height: 48),
                cornerRadius: 8
            )

            // Flexible frame so long course names truncate cleanly
            // instead of pushing the distance + chevron off-screen.
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(courseSubtitle(course))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.1f mi", course.distanceMiles))
                .font(.caption.bold())
                .foregroundStyle(Theme.textMuted)
                .fixedSize()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func courseSubtitle(_ course: NearbyCourse) -> String {
        let parts = [course.city, course.state].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    private var nearbySkeletonRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.textMuted.opacity(0.15))
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.textMuted.opacity(0.15))
                    .frame(height: 12)
                    .frame(maxWidth: 160)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.textMuted.opacity(0.10))
                    .frame(height: 10)
                    .frame(maxWidth: 100)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func nearbyMessageCard(
        icon: String,
        title: String,
        subtitle: String?,
        action: (() -> Void)?,
        actionLabel: String?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            if let action, let actionLabel {
                Button {
                    action()
                } label: {
                    Text(actionLabel)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Section F — Weather card
    private func weatherCard(for course: NearbyCourse) -> some View {
        let wind = nearestWeather
        let speed = wind.map { Int($0.speed.rounded()) } ?? 0
        let dir = wind.map { Int($0.direction.rounded()) } ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("Weather at \(course.name)")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            HStack(spacing: 14) {
                Image(systemName: "wind")
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(speed) mph")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.text)
                    Text("From \(dir)°")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "location.north.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
                    .rotationEffect(.degrees(Double(dir)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Loading helpers

    private func loadNearbyIfPossible() async {
        // Trigger a one-shot fix if we don't have one and authorization
        // already allows it. The "notDetermined" case does NOT auto-prompt
        // — Section E's tap-to-enable button is the trigger.
        if locationManager.currentLocation == nil {
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            default:
                return
            }
        }

        guard let fix = locationManager.currentLocation else { return }

        let coordKey = String(
            format: "%.2f,%.2f",
            fix.coordinate.latitude,
            fix.coordinate.longitude
        )
        guard coordKey != loadedForCoordKey else { return }
        loadedForCoordKey = coordKey

        nearbyLoading = true
        nearbyError = nil

        // Snapshot the SwiftData rows into Sendable structs on the main
        // actor before crossing into the GolfCourseAPIClient actor.
        let candidates: [NearbyCandidate] = allCourses.map { c in
            NearbyCandidate(
                id: c.id.uuidString,
                name: c.name,
                city: c.city,
                state: c.state,
                latitude: c.latitude,
                longitude: c.longitude
            )
        }
        let results = await GolfCourseAPIClient.shared.searchNearby(
            lat: fix.coordinate.latitude,
            lng: fix.coordinate.longitude,
            radiusMiles: 25,
            limit: 3,
            candidates: candidates
        )
        nearby = results
        nearbyLoading = false

        // Section F — fetch weather for the nearest course (Pro only).
        if nearbyWeatherUnlocked, let nearest = results.first {
            let wxKey = String(format: "%.2f,%.2f", nearest.latitude, nearest.longitude)
            if wxKey != weatherLoadedForKey {
                weatherLoadedForKey = wxKey
                let coord = CLLocationCoordinate2D(
                    latitude: nearest.latitude,
                    longitude: nearest.longitude
                )
                nearestWeather = await WeatherService.shared.currentWind(at: coord)
            }
        } else {
            nearestWeather = nil
            weatherLoadedForKey = nil
        }
    }
}
