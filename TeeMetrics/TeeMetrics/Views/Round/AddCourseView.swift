// MARK: - Add Course View
// Create new course with name, location, hole-by-hole par/yardage, and MapKit pin

import SwiftUI
import SwiftData
import MapKit

struct AddCourseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onCourseCreated: ((GolfCourse) -> Void)?

    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var slopeRating = "113"
    @State private var courseRating = "72.0"
    @State private var holes: [EditableHole] = (1...18).map { EditableHole(number: $0) }
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pinLocation: CLLocationCoordinate2D?
    @State private var showSharePrompt = false
    @State private var savedCourse: GolfCourse?

    struct EditableHole: Identifiable {
        let id = UUID()
        let number: Int
        var par: Int = 4
        var yardage: Int = 350
        var handicapRating: Int = 1
    }

    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
    var totalYardage: Int { holes.reduce(0) { $0 + $1.yardage } }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Course Info
                Section("Course Info") {
                    TextField("Course Name", text: $name)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    HStack {
                        TextField("Slope", text: $slopeRating)
                            .keyboardType(.decimalPad)
                        TextField("Rating", text: $courseRating)
                            .keyboardType(.decimalPad)
                    }
                }

                // MARK: - Map Pin
                Section("Location") {
                    Map(position: $cameraPosition) {
                        if let pin = pinLocation {
                            Marker("Course", coordinate: pin)
                                .tint(Theme.primary)
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("Location is optional — used for nearby course suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Quick Par Setup
                Section("Quick Setup") {
                    HStack {
                        Text("Par: \(totalPar)")
                            .font(.headline)
                        Spacer()
                        Text("Yards: \(totalYardage)")
                            .font(.headline)
                    }

                    Button("Set All Par 4") {
                        for i in holes.indices { holes[i].par = 4 }
                    }
                    Button("Standard Par 72 Layout") {
                        applyStandardLayout()
                    }
                }

                // MARK: - Hole-by-Hole Editor
                Section("Holes") {
                    ForEach($holes) { $hole in
                        HStack {
                            Text("#\(hole.number)")
                                .font(.caption.bold())
                                .frame(width: 30)
                            Picker("Par", selection: $hole.par) {
                                ForEach(3...5, id: \.self) { Text("P\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            TextField("Yds", value: $hole.yardage, format: .number)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCourse() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Share with Community?", isPresented: $showSharePrompt) {
                Button("Share") {
                    if let course = savedCourse {
                        Task {
                            _ = await CloudKitCourseService.shared.shareCourse(course, contributorName: "TeeMetrics User")
                        }
                    }
                    dismiss()
                }
                Button("No Thanks", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Help other golfers! Share this course with the TeeMetrics community.")
            }
        }
    }

    private func applyStandardLayout() {
        // Standard par 72: par 3 on holes 3, 7, 12, 16; par 5 on holes 2, 9, 13, 18
        let par5s: Set<Int> = [2, 9, 13, 18]
        let par3s: Set<Int> = [3, 7, 12, 16]
        for i in holes.indices {
            let num = holes[i].number
            if par5s.contains(num) {
                holes[i].par = 5
                holes[i].yardage = 520
            } else if par3s.contains(num) {
                holes[i].par = 3
                holes[i].yardage = 170
            } else {
                holes[i].par = 4
                holes[i].yardage = 380
            }
            holes[i].handicapRating = i + 1
        }
    }

    private func saveCourse() {
        let course = GolfCourse(
            name: name.trimmingCharacters(in: .whitespaces),
            city: city,
            state: state,
            latitude: pinLocation?.latitude ?? 0,
            longitude: pinLocation?.longitude ?? 0,
            totalPar: totalPar,
            totalYardage: totalYardage,
            slopeRating: Double(slopeRating) ?? 113,
            courseRating: Double(courseRating) ?? 72.0
        )
        modelContext.insert(course)

        for hole in holes {
            let holeInfo = HoleInfo(
                holeNumber: hole.number,
                par: hole.par,
                yardage: hole.yardage,
                handicapRating: hole.handicapRating,
                course: course
            )
            modelContext.insert(holeInfo)
        }

        Haptics.success()
        savedCourse = course
        onCourseCreated?(course)

        // Prompt to share with community
        if CloudKitCourseService.shared.isAvailable {
            showSharePrompt = true
        } else {
            dismiss()
        }
    }
}

