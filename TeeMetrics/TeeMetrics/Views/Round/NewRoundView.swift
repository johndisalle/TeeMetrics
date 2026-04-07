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
    @State private var playerCount = 1
    @State private var playerNames = ""
    @State private var weatherNotes = ""
    @State private var showAddCourse = false
    @State private var searchText = ""
    @State private var navigateToRound = false
    @State private var createdRound: GolfRound?

    private var filteredCourses: [GolfCourse] {
        if searchText.isEmpty { return courses }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationDestination(isPresented: $navigateToRound) {
                if let round = createdRound {
                    LiveRoundView(round: round)
                }
            }
            .searchable(text: $searchText, prompt: "Search courses")
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
        modelContext.insert(round)

        // Pre-populate hole entries from course data
        let sortedHoles = course.holes.sorted { $0.holeNumber < $1.holeNumber }
        for i in 1...18 {
            let holeInfo = sortedHoles.first { $0.holeNumber == i }
            let entry = HoleEntry(
                holeNumber: i,
                par: holeInfo?.par ?? 4,
                round: round,
                holeInfo: holeInfo
            )
            modelContext.insert(entry)
            round.holeEntries.append(entry)
        }

        createdRound = round
        navigateToRound = true
    }
}
