// MARK: - New Round Flow
// Course selection, multi-player toggle, bag selection, start round

import SwiftUI
import SwiftData

struct NewRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \GolfCourse.name) private var courses: [GolfCourse]
    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]

    @State private var selectedCourse: GolfCourse?
    @State private var selectedTeeName: String?
    @State private var playerCount = 1
    @State private var playerNames = ""
    @State private var weatherNotes = ""
    @State private var showAddCourse = false
    @State private var showBundledBrowser = false
    @State private var showCommunityBrowser = false
    @State private var searchText = ""
    @State private var navigateToRound = false
    @State private var createdRound: GolfRound?

    private var filteredCourses: [GolfCourse] {
        if searchText.isEmpty { return courses }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Tees for the currently selected course, sorted long-to-short so the
    /// traditional "back tees first" order is preserved.
    private var availableTees: [CourseTee] {
        guard let course = selectedCourse else { return [] }
        return course.tees.sorted { $0.yardage > $1.yardage }
    }

    /// Picks the tee closest to the median yardage — "the middle tee" —
    /// as the default. Returns nil if there are no tees.
    private func defaultTeeName(for tees: [CourseTee]) -> String? {
        guard !tees.isEmpty else { return nil }
        let sortedByYardage = tees.sorted { $0.yardage < $1.yardage }
        let midIndex = sortedByYardage.count / 2
        return sortedByYardage[midIndex].name
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Nearby Suggestion
                if let suggested = CourseDetectionManager.shared.suggestedCourse {
                    Section("Nearby") {
                        Button {
                            selectedCourse = suggested
                            Haptics.selection()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(Theme.primary)
                                VStack(alignment: .leading) {
                                    Text(suggested.name)
                                        .font(.subheadline.bold())
                                    if let dist = CourseDetectionManager.shared.distanceTo(suggested) {
                                        Text(dist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedCourse?.id == suggested.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                // MARK: - Course Selection
                Section("Course") {
                    if courses.isEmpty {
                        Button("Add Your First Course") {
                            showAddCourse = true
                        }
                    } else {
                        Picker("Select Course", selection: $selectedCourse) {
                            Text("Choose...").tag(nil as GolfCourse?)
                            ForEach(filteredCourses) { course in
                                Text(course.name).tag(course as GolfCourse?)
                            }
                        }
                    }

                    Button {
                        showAddCourse = true
                    } label: {
                        Label("Add New Course", systemImage: "plus.circle")
                    }

                    Button {
                        showBundledBrowser = true
                    } label: {
                        Label("Browse 660+ Courses", systemImage: "building.2.fill")
                            .foregroundStyle(Theme.primary)
                    }

                    Button {
                        showCommunityBrowser = true
                    } label: {
                        Label("Community Courses", systemImage: "person.3.fill")
                            .foregroundStyle(Theme.primary)
                    }
                }

                // MARK: - Tees (Phase 2)
                // Only shown when the selected course has tee data. Legacy
                // courses with no tees array fall through to the default
                // scorecard on HoleInfo.
                if !availableTees.isEmpty {
                    Section("Tees") {
                        Picker("Tee Box", selection: $selectedTeeName) {
                            ForEach(availableTees) { tee in
                                Text("\(tee.name) · \(tee.yardage)y")
                                    .tag(tee.name as String?)
                            }
                        }
                        .pickerStyle(.menu)

                        if let tee = availableTees.first(where: { $0.name == selectedTeeName }) {
                            HStack {
                                Text("Par \(tee.par)")
                                Spacer()
                                Text("Slope \(tee.slope)")
                                    .foregroundStyle(.secondary)
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("Rating \(String(format: "%.1f", tee.rating))")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }

                // MARK: - Players
                Section("Players") {
                    Stepper("Players: \(playerCount)", value: $playerCount, in: 1...4)
                    if playerCount > 1 {
                        TextField("Player names (comma separated)", text: $playerNames)
                    }
                }

                // MARK: - Weather
                Section("Conditions") {
                    TextField("Weather notes (optional)", text: $weatherNotes)
                }

                // MARK: - Start Round
                Section {
                    Button {
                        startRound()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Round", systemImage: "flag.checkered")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(selectedCourse == nil)
                }
            }
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCourse) {
                AddCourseView { course in
                    selectedCourse = course
                }
            }
            .sheet(isPresented: $showBundledBrowser) {
                BundledCourseBrowser { course in
                    selectedCourse = course
                    showBundledBrowser = false
                }
            }
            .sheet(isPresented: $showCommunityBrowser) {
                CommunityCourseBrowser { course in
                    selectedCourse = course
                    showCommunityBrowser = false
                }
            }
            .navigationDestination(isPresented: $navigateToRound) {
                if let round = createdRound {
                    LiveRoundView(round: round)
                }
            }
            .searchable(text: $searchText, prompt: "Search courses")
            .onAppear {
                CourseDetectionManager.shared.requestLocation()
                CourseDetectionManager.shared.findNearbyCourses(from: courses)
            }
            .onChange(of: selectedCourse) { _, newCourse in
                // When the user picks a new course, reset the tee to the
                // middle-by-yardage default. Avoids stale tee names from the
                // previous selection leaking into the next round.
                let tees = newCourse?.tees.sorted { $0.yardage > $1.yardage } ?? []
                selectedTeeName = defaultTeeName(for: tees)
            }
        }
    }

    private func startRound() {
        guard let course = selectedCourse else { return }
        Haptics.success()

        let round = GolfRound(
            course: course,
            weatherNotes: weatherNotes,
            playersCount: playerCount,
            playerNames: playerNames
        )
        // Phase 2: remember which tee the golfer played from. When the
        // course has no tees array, this stays nil and we fall back to
        // the default scorecard on HoleInfo.
        round.teeName = selectedTeeName
        modelContext.insert(round)

        // Pre-populate hole entries. Prefer the selected tee's per-hole
        // par when available, else fall back to HoleInfo's default par.
        let selectedTee: CourseTee? = {
            guard let teeName = selectedTeeName else { return nil }
            return course.tees.first { $0.name == teeName }
        }()
        let sortedHoles = course.holes.sorted { $0.holeNumber < $1.holeNumber }

        for i in 1...18 {
            let holeInfo = sortedHoles.first { $0.holeNumber == i }
            let teeHolePar = selectedTee?.hole(number: i)?.par
            let par = teeHolePar ?? holeInfo?.par ?? 4
            let entry = HoleEntry(
                holeNumber: i,
                par: par,
                round: round,
                holeInfo: holeInfo
            )
            modelContext.insert(entry)
            round.holeEntries.append(entry)
        }

        createdRound = round
        navigateToRound = true

        // Push the new round (course, tee, per-hole pars) to the paired
        // Apple Watch so it can switch from idle to active scoring with
        // the correct par values for this tee.
        WatchSyncManager.shared.sendRoundStart(round: round)
    }
}
