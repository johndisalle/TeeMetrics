// MARK: - Bundled Course Browser
// Search and import pre-loaded courses with verification note.
//
// Session: GolfCourseAPI live search
// This view now shows two sections when the user types a query:
//   1. "On this device" — instant local match across the bundled courses
//   2. "Search online"  — debounced live query against GolfCourseAPI
//
// The online section silently hides when no API key is configured (see
// `GolfCourseAPIClient.isConfigured`), so dev builds without the key still
// behave exactly like before.

import SwiftUI
import SwiftData

struct BundledCourseBrowser: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onCourseImported: ((GolfCourse) -> Void)?

    @State private var allCourses: [BundledCourse] = []
    @State private var searchText = ""
    @State private var selectedState = "All"
    @State private var importedAlert = false
    @State private var importedName = ""

    // MARK: - Online search state
    @State private var onlineResults: [APICourseSummary] = []
    @State private var onlineSearchTask: Task<Void, Never>?
    @State private var isSearchingOnline = false
    @State private var onlineErrorMessage: String?
    @State private var importingOnlineID: Int?
    @State private var importErrorMessage: String?

    private let onlineEnabled = GolfCourseAPIClient.shared.isConfigured

    private var states: [String] {
        let s = Set(allCourses.map(\.state))
        return ["All"] + s.sorted()
    }

    private var filteredCourses: [BundledCourse] {
        var result = allCourses
        if selectedState != "All" {
            result = result.filter { $0.state == selectedState }
        }
        if !searchText.isEmpty {
            result = BundledCourseImporter.search(searchText, in: result)
        }
        return result
    }

    /// True once the user types at least 3 characters — the minimum query
    /// length for the online endpoint. Below this threshold the online
    /// section just says "Type at least 3 characters" instead of firing
    /// requests for every keystroke.
    private var onlineQueryReady: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // State filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(states, id: \.self) { state in
                            Button {
                                selectedState = state
                                Haptics.selection()
                            } label: {
                                Text(state)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedState == state ? Theme.primary : Color.gray.opacity(0.1))
                                    .foregroundStyle(selectedState == state ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Theme.secondaryBackground)

                // Course list
                List {
                    // MARK: On this device
                    Section {
                        if filteredCourses.isEmpty {
                            Text(searchText.isEmpty
                                 ? "No bundled courses match this filter."
                                 : "No matches on this device.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredCourses, id: \.name) { course in
                                BundledCourseRow(
                                    course: course,
                                    isImported: BundledCourseImporter.isAlreadyImported(
                                        name: course.name, state: course.state, context: modelContext
                                    )
                                ) {
                                    importCourse(course)
                                }
                            }
                        }
                    } header: {
                        Text("On this device")
                    }

                    // MARK: Search online (gated on API key presence)
                    if onlineEnabled {
                        Section {
                            onlineSectionContent
                        } header: {
                            HStack(spacing: 6) {
                                Text("Search online")
                                if isSearchingOnline {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
                            }
                        } footer: {
                            if onlineQueryReady && onlineErrorMessage == nil {
                                Text("Live results from GolfCourseAPI. Verify the scorecard before your round.")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Course Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search \(allCourses.count) courses")
            .onChange(of: searchText) { _, newValue in
                scheduleOnlineSearch(for: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Course Added", isPresented: $importedAlert) {
                Button("OK") {}
            } message: {
                Text("\(importedName) has been added. Verify the scorecard before your round.")
            }
            .alert(
                "Couldn't import course",
                isPresented: Binding(
                    get: { importErrorMessage != nil },
                    set: { if !$0 { importErrorMessage = nil } }
                )
            ) {
                Button("OK") { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .onAppear {
                if allCourses.isEmpty {
                    allCourses = BundledCourseImporter.loadBundledCourses()
                }
            }
            .onDisappear {
                onlineSearchTask?.cancel()
            }
        }
    }

    // MARK: - Online section content

    @ViewBuilder
    private var onlineSectionContent: some View {
        if !onlineQueryReady {
            Text("Type at least 3 characters to search online.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if let error = onlineErrorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if isSearchingOnline && onlineResults.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                Text("Searching online…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if onlineResults.isEmpty {
            Text("No online results.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(onlineResults) { result in
                OnlineCourseRow(
                    result: result,
                    isImporting: importingOnlineID == result.id
                ) {
                    importOnlineCourse(result)
                }
            }
        }
    }

    // MARK: - Search debouncing

    private func scheduleOnlineSearch(for query: String) {
        guard onlineEnabled else { return }
        onlineSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            onlineResults = []
            onlineErrorMessage = nil
            isSearchingOnline = false
            return
        }

        onlineErrorMessage = nil
        isSearchingOnline = true

        onlineSearchTask = Task { @MainActor in
            // 400ms debounce — Task.sleep cancels cleanly when a new
            // keystroke fires another scheduleOnlineSearch.
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }

            do {
                let results = try await GolfCourseAPIClient.shared.searchCourses(query: trimmed)
                if Task.isCancelled { return }
                self.onlineResults = results
                self.isSearchingOnline = false
            } catch is CancellationError {
                // Swallow — a newer search is already running.
            } catch GolfCourseAPIError.notConfigured {
                self.onlineErrorMessage = "Online search isn't available in this build."
                self.onlineResults = []
                self.isSearchingOnline = false
            } catch {
                self.onlineErrorMessage = error.localizedDescription
                self.onlineResults = []
                self.isSearchingOnline = false
            }
        }
    }

    // MARK: - Imports

    private func importCourse(_ bundled: BundledCourse) {
        let course = BundledCourseImporter.importCourse(bundled, into: modelContext)
        importedName = bundled.name
        importedAlert = true
        onCourseImported?(course)
        Haptics.success()
    }

    private func importOnlineCourse(_ summary: APICourseSummary) {
        guard importingOnlineID == nil else { return }
        importingOnlineID = summary.id

        Task { @MainActor in
            defer { importingOnlineID = nil }
            do {
                let detail = try await GolfCourseAPIClient.shared.fetchCourseDetail(id: summary.id)
                let course = try APICourseImporter.importCourse(detail, into: modelContext)
                importedName = course.name
                importedAlert = true
                onCourseImported?(course)
                Haptics.success()
            } catch {
                importErrorMessage = error.localizedDescription
                Haptics.medium()
            }
        }
    }
}

// MARK: - Course Row (bundled)
struct BundledCourseRow: View {
    let course: BundledCourse
    let isImported: Bool
    let onImport: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(course.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if !course.verified {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text("\(course.city), \(course.state)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("Par \(course.par)")
                    Text("\u{2022}")
                    Text("\(course.yardage) yds")
                    Text("\u{2022}")
                    Text("Slope \(String(format: "%.0f", course.slope))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isImported {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    onImport()
                } label: {
                    Text("Add")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Course Row (online)
// Renders one search hit from GolfCourseAPI. Tap "Add" to fetch the full
// course detail and import it via APICourseImporter.
struct OnlineCourseRow: View {
    let result: APICourseSummary
    let isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.and.arrow.down")
                .foregroundStyle(Theme.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.displayName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                let subtitle = result.displaySubtitle
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isImporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    onImport()
                } label: {
                    Text("Add")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
