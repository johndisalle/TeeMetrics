// MARK: - Community Course Browser
// Browse and import crowd-sourced courses from CloudKit public database

import SwiftUI
import SwiftData

struct CommunityCourseBrowser: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onCourseImported: ((GolfCourse) -> Void)?

    @State private var service = CloudKitCourseService.shared
    @State private var searchText = ""
    @State private var selectedState = ""
    @State private var importedAlert = false
    @State private var importedName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Status Bar
                if !service.isAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.slash")
                            .foregroundStyle(.orange)
                        Text("Sign in to iCloud to browse community courses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.08))
                }

                // MARK: - Course List
                if service.isLoading {
                    Spacer()
                    ProgressView("Loading community courses...")
                    Spacer()
                } else if let error = service.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await service.fetchCommunityCourses(searchText: searchText) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primary)
                    }
                    .padding()
                    Spacer()
                } else if service.communityCourses.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.primary.opacity(0.3))
                        Text("No Community Courses Yet")
                            .font(.headline)
                        Text("Be the first to share a course!\nCreate a course and tap \"Share with Community\".")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(service.communityCourses) { course in
                            CommunityCourseRow(course: course) {
                                importCourse(course)
                            } onUpvote: {
                                Task { await service.upvoteCourse(course) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Community Courses")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search community courses")
            .onSubmit(of: .search) {
                Task { await service.fetchCommunityCourses(searchText: searchText) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Course Added", isPresented: $importedAlert) {
                Button("OK") {}
            } message: {
                Text("\(importedName) has been added to your courses. Verify the scorecard before your round.")
            }
            .task {
                if service.communityCourses.isEmpty {
                    await service.fetchCommunityCourses()
                }
            }
        }
    }

    private func importCourse(_ shared: SharedCourseRecord) {
        let course = service.importCourse(shared, into: modelContext)
        importedName = shared.name
        importedAlert = true
        onCourseImported?(course)
        Haptics.success()
    }
}

// MARK: - Community Course Row
struct CommunityCourseRow: View {
    let course: SharedCourseRecord
    let onImport: () -> Void
    let onUpvote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: name + add button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text("\(course.city), \(course.state)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

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

            // Stats row
            HStack(spacing: 12) {
                Label("Par \(course.totalPar)", systemImage: "flag.fill")
                Label("\(course.totalYardage) yds", systemImage: "ruler")
                Label(String(format: "%.0f", course.slopeRating), systemImage: "mountain.2.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            // Bottom row: contributor + upvotes
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption2)
                    Text(course.contributorName)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onUpvote()
                    Haptics.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption2)
                        Text("\(course.upvotes)")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
