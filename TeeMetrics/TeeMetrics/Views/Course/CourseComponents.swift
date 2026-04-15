// MARK: - Course Components
// Shared row + detail views for the course list. Originally lived
// alongside an outer `CourseLibraryView` wrapper; that wrapper was
// promoted to the top-level `CoursesView` tab in Session B and removed
// from Settings, so this file now holds just the reusable pieces:
//
//   - `CourseRow`         — text-only row used by CommunityCourseBrowser
//   - `CourseDetailView`  — full course detail used by CoursesView
//
// (The Courses tab itself uses `CoursesListRow` from CoursesView.swift,
// which is the hero-image variant introduced in Session C.)

import SwiftUI
import SwiftData
import MapKit

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
    @State private var showGPSEditor = false

    private var sortedHoles: [HoleInfo] {
        course.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    private var holesWithPins: Int {
        sortedHoles.filter { $0.hasGreenPins }.count
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

            // MARK: - GPS Pins (Phase 1B)
            Section("GPS Pins") {
                Button {
                    showGPSEditor = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Theme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set GPS Pins")
                                .foregroundStyle(.primary)
                            Text("\(holesWithPins) of 18 holes mapped")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }
                }
                .buttonStyle(.plain)
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
                        if hole.hasGreenPins {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.primary)
                        }
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
        .sheet(isPresented: $showGPSEditor) {
            HoleGPSEditorView(course: course)
        }
    }
}
