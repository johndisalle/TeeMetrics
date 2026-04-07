// MARK: - Course Library
// Browsable list of saved courses, 18-hole editor, favorites

import SwiftUI
import SwiftData
import MapKit

struct CourseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfCourse.name) private var courses: [GolfCourse]
    @State private var searchText = ""
    @State private var showAddCourse = false

    private var filteredCourses: [GolfCourse] {
        if searchText.isEmpty { return courses }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    ContentUnavailableView(
                        "No Courses",
                        systemImage: "flag.fill",
                        description: Text("Add your first course to get started")
                    )
                } else {
                    List {
                        ForEach(filteredCourses) { course in
                            NavigationLink {
                                CourseDetailView(course: course)
                            } label: {
                                CourseRow(course: course)
                            }
                        }
                        .onDelete(perform: deleteCourses)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Courses")
            .searchable(text: $searchText, prompt: "Search courses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCourse = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCourse) {
                AddCourseView()
            }
        }
    }

    private func deleteCourses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCourses[index])
        }
    }
}

// MARK: - Course Row
struct CourseRow: View {
    let course: GolfCourse

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(course.name)
                        .font(.headline)
                    if course.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text("\(course.city)\(course.city.isEmpty || course.state.isEmpty ? "" : ", ")\(course.state)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Par \(course.totalPar)")
                    .font(.subheadline.bold())
                Text("\(course.totalYardage) yds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Course Detail
struct CourseDetailView: View {
    @Bindable var course: GolfCourse

    private var sortedHoles: [HoleInfo] {
        course.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    var body: some View {
        List {
            Section("Info") {
                HStack {
                    Text("Par")
                    Spacer()
                    Text("\(course.totalPar)")
                }
                HStack {
                    Text("Yardage")
                    Spacer()
                    Text("\(course.totalYardage)")
                }
                HStack {
                    Text("Slope / Rating")
                    Spacer()
                    Text("\(String(format: "%.0f", course.slopeRating)) / \(String(format: "%.1f", course.courseRating))")
                }
                HStack {
                    Text("Rounds Played")
                    Spacer()
                    Text("\(course.rounds.filter { $0.isCompleted }.count)")
                }
            }

            if course.latitude != 0 {
                Section("Location") {
                    Map {
                        Marker(course.name, coordinate: CLLocationCoordinate2D(
                            latitude: course.latitude,
                            longitude: course.longitude
                        ))
                        .tint(Theme.primary)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Section("Holes") {
                ForEach(sortedHoles) { hole in
                    HStack {
                        Text("#\(hole.holeNumber)")
                            .font(.caption.bold())
                            .frame(width: 30)
                        Text("Par \(hole.par)")
                            .frame(width: 50)
                        Text("\(hole.yardage) yds")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("HCP \(hole.handicapRating)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(course.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    course.isFavorite.toggle()
                    Haptics.selection()
                } label: {
                    Image(systemName: course.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
