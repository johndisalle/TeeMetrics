// MARK: - Courses Tab (Session B)
// Top-level entry point for the course library, promoted from its
// previous home buried under Settings → Data → Course Library.
//
// This is a slim wrapper around the existing `CourseLibraryView`
// reusing its list/search/filter/add-menu logic — `CourseRow` and
// `CourseDetailView` from CourseLibraryView.swift are reused directly
// since they're top-level structs in the same module. Don't duplicate
// the row + detail code here.

import SwiftUI
import SwiftData

struct CoursesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfCourse.name) private var courses: [GolfCourse]

    @State private var searchText = ""
    @State private var showAddCourse = false
    @State private var showBundledBrowser = false
    @State private var showCommunityBrowser = false

    private var filteredCourses: [GolfCourse] {
        if searchText.isEmpty { return courses }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        #if DEBUG
        let _ = print("[CoursesView] courses.count: \(courses.count) (filtered: \(filteredCourses.count))")
        #endif
        NavigationStack {
            Group {
                if courses.isEmpty {
                    ContentUnavailableView(
                        "No Courses",
                        systemImage: "flag",
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
            .background(Theme.background)
            .navigationTitle("Courses")
            .searchable(text: $searchText, prompt: "Search courses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showBundledBrowser = true
                        } label: {
                            Label("Browse 660+ Courses", systemImage: "building.2.fill")
                        }
                        Button {
                            showCommunityBrowser = true
                        } label: {
                            Label("Community Courses", systemImage: "person.3.fill")
                        }
                        Divider()
                        Button {
                            showAddCourse = true
                        } label: {
                            Label("Create Custom Course", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCourse) {
                AddCourseView()
            }
            .sheet(isPresented: $showBundledBrowser) {
                BundledCourseBrowser()
            }
            .sheet(isPresented: $showCommunityBrowser) {
                CommunityCourseBrowser()
            }
        }
    }

    private func deleteCourses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredCourses[index])
        }
    }
}
