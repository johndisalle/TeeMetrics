// MARK: - Bundled Course Browser
// Search and import pre-loaded courses with verification note

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
                    if filteredCourses.isEmpty {
                        ContentUnavailableView.search(text: searchText)
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
                }
                .listStyle(.plain)
            }
            .navigationTitle("Course Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search \(allCourses.count) courses")
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
            .onAppear {
                if allCourses.isEmpty {
                    allCourses = BundledCourseImporter.loadBundledCourses()
                }
            }
        }
    }

    private func importCourse(_ bundled: BundledCourse) {
        let course = BundledCourseImporter.importCourse(bundled, into: modelContext)
        importedName = bundled.name
        importedAlert = true
        onCourseImported?(course)
        Haptics.success()
    }
}

// MARK: - Course Row
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
