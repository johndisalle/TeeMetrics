// MARK: - Hole GPS Editor (Phase 1B)
// Full-screen satellite map for placing Front / Center / Back green pins.
//
// Flow:
// 1. User picks a hole (segmented picker 1-18 at top).
// 2. User taps one of three pin buttons (Set Front / Set Center / Set Back)
//    to enter placement mode for that pin.
// 3. User taps on the map to drop the pin at that coordinate, OR taps
//    "Use My Location" to drop the pin at their current GPS position
//    (on-course workflow).
// 4. Front/Center/Back annotations update live with distinct colors.
// 5. Distance-between-pins readout shows front→back and warns if out of
//    the typical 20-40 yard range.
// 6. Save writes the coordinates back to HoleInfo via @Bindable.
// 7. If the course came from CloudKit, user is prompted to share the pins
//    back to the community.

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct HoleGPSEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var course: GolfCourse

    @State private var selectedHoleNumber: Int = 1
    @State private var activePin: PinKind? = nil
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showShareAlert = false
    @State private var showPaywall = false
    @State private var showSavedToast = false
    @State private var locationManager = CourseDetectionManager.shared

    enum PinKind: String, CaseIterable {
        case front, center, back

        var label: String {
            switch self {
            case .front: return "Front"
            case .center: return "Center"
            case .back: return "Back"
            }
        }

        var color: Color {
            switch self {
            case .front: return .blue
            case .center: return .red
            case .back: return .green
            }
        }

        var systemImage: String {
            switch self {
            case .front: return "arrowtriangle.up.fill"
            case .center: return "circle.circle.fill"
            case .back: return "arrowtriangle.down.fill"
            }
        }
    }

    // MARK: - Derived State
    private var sortedHoles: [HoleInfo] {
        course.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    private var currentHole: HoleInfo? {
        sortedHoles.first { $0.holeNumber == selectedHoleNumber }
    }

    private var canEdit: Bool {
        GatingManager.shared.canEditPins(for: course)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if canEdit {
                    editorContent
                } else {
                    lockedContent
                }
            }
            .navigationTitle("GPS Pins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack { SubscriptionView() }
            }
            .alert("Share these pins with other players?", isPresented: $showShareAlert) {
                Button("Share") {
                    Task {
                        _ = await CloudKitCourseService.shared.updateGreenPins(for: course)
                        dismiss()
                    }
                }
                Button("Keep Local", role: .cancel) { dismiss() }
            } message: {
                Text("Your GPS pins will be uploaded to the TeeMetrics community so other players at \(course.name) get accurate distances.")
            }
        }
    }

    // MARK: - Editor Content (user has permission)
    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            holePicker
                .padding(.horizontal)
                .padding(.top, 8)

            mapView

            controlsPanel
        }
        .onAppear {
            centerCameraOnCourse()
            locationManager.requestLocation()
        }
        .onChange(of: selectedHoleNumber) { _, _ in
            activePin = nil
        }
    }

    // MARK: - Locked / Pro-Gated Content
    @ViewBuilder
    private var lockedContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)

            VStack(spacing: 8) {
                Text("GPS Pin Editing is Pro")
                    .font(.title3.bold())
                Text("You can edit GPS pins on courses you created for free.\nUpgrade to Pro to edit pins on community and bundled courses.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Hole Picker
    private var holePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...18, id: \.self) { hole in
                    Button {
                        selectedHoleNumber = hole
                        Haptics.selection()
                    } label: {
                        let isSelected = hole == selectedHoleNumber
                        let hasPins = sortedHoles.first { $0.holeNumber == hole }?.hasGreenPins ?? false
                        VStack(spacing: 2) {
                            Text("\(hole)")
                                .font(.caption.bold())
                            if hasPins {
                                Circle()
                                    .fill(Theme.primary)
                                    .frame(width: 4, height: 4)
                            } else {
                                Circle()
                                    .fill(.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(width: 34, height: 34)
                        .background(isSelected ? Theme.primary : Color.gray.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - Map View
    private var mapView: some View {
        ZStack(alignment: .topTrailing) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    // Existing pins for current hole
                    if let hole = currentHole {
                        if let frontCoord = coordinate(lat: hole.greenFrontLatitude, lon: hole.greenFrontLongitude) {
                            Annotation("Front", coordinate: frontCoord) {
                                pinView(kind: .front)
                            }
                        }
                        if let centerCoord = coordinate(lat: hole.greenCenterLatitude, lon: hole.greenCenterLongitude) {
                            Annotation("Center", coordinate: centerCoord) {
                                pinView(kind: .center)
                            }
                        }
                        if let backCoord = coordinate(lat: hole.greenBackLatitude, lon: hole.greenBackLongitude) {
                            Annotation("Back", coordinate: backCoord) {
                                pinView(kind: .back)
                            }
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .onTapGesture(coordinateSpace: .local) { screenPoint in
                    guard let pin = activePin else { return }
                    if let coord = proxy.convert(screenPoint, from: .local) {
                        setPin(pin, coordinate: coord)
                    }
                }
            }

            // Placement-mode banner
            if let pin = activePin {
                Text("Tap the map to place \(pin.label.uppercased())")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(pin.color.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .shadow(radius: 4)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 10) {
            if let hole = currentHole {
                // Three pin buttons
                HStack(spacing: 8) {
                    pinButton(kind: .front, isSet: hole.greenFrontLatitude != nil)
                    pinButton(kind: .center, isSet: hole.greenCenterLatitude != nil)
                    pinButton(kind: .back, isSet: hole.greenBackLatitude != nil)
                }

                // Use my location button
                Button {
                    useCurrentLocationForActivePin()
                } label: {
                    Label("Use My Location", systemImage: "location.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(activePin != nil ? Theme.primary : Color.gray.opacity(0.2))
                        .foregroundStyle(activePin != nil ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(activePin == nil || locationManager.currentLocation == nil)

                // Distance readout + warning
                if let readout = distanceReadout(for: hole) {
                    HStack(spacing: 6) {
                        Image(systemName: readout.isWarning ? "exclamationmark.triangle.fill" : "ruler")
                            .foregroundStyle(readout.isWarning ? .orange : Theme.primary)
                        Text(readout.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }

                // Save button
                Button {
                    savePins()
                } label: {
                    Text("Save Pins for Hole \(hole.holeNumber)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Text("No hole selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Theme.background)
    }

    // MARK: - Pin Button
    private func pinButton(kind: PinKind, isSet: Bool) -> some View {
        Button {
            if activePin == kind {
                activePin = nil
            } else {
                activePin = kind
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: kind.systemImage)
                    .font(.title3)
                Text("Set \(kind.label)")
                    .font(.caption2.bold())
                if isSet {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(activePin == kind ? kind.color : kind.color.opacity(0.12))
            .foregroundStyle(activePin == kind ? .white : kind.color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSet && activePin != kind ? kind.color : .clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("Set \(kind.label) pin\(isSet ? ", currently set" : "")")
    }

    // MARK: - Map Annotation View
    private func pinView(kind: PinKind) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(kind.color)
                .background(Circle().fill(.white).padding(4))
                .shadow(radius: 3)
            Text(kind.label)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(kind.color)
                .clipShape(Capsule())
        }
    }

    // MARK: - Helpers
    private func coordinate(lat: Double?, lon: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func setPin(_ kind: PinKind, coordinate: CLLocationCoordinate2D) {
        guard let hole = currentHole else { return }
        switch kind {
        case .front:
            hole.greenFrontLatitude = coordinate.latitude
            hole.greenFrontLongitude = coordinate.longitude
        case .center:
            hole.greenCenterLatitude = coordinate.latitude
            hole.greenCenterLongitude = coordinate.longitude
        case .back:
            hole.greenBackLatitude = coordinate.latitude
            hole.greenBackLongitude = coordinate.longitude
        }
        activePin = nil
        Haptics.success()
    }

    private func useCurrentLocationForActivePin() {
        guard let pin = activePin, let loc = locationManager.currentLocation else { return }
        setPin(pin, coordinate: loc.coordinate)
    }

    private func centerCameraOnCourse() {
        // Prefer course coordinates; fall back to user location if course has none.
        if course.latitude != 0 || course.longitude != 0 {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: course.latitude, longitude: course.longitude),
                latitudinalMeters: 800,
                longitudinalMeters: 800
            ))
        } else if let loc = locationManager.currentLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: loc.coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            ))
        }
    }

    // MARK: - Distance Readout (front → back)
    private struct DistanceReadout {
        let text: String
        let isWarning: Bool
    }

    private func distanceReadout(for hole: HoleInfo) -> DistanceReadout? {
        guard let fLat = hole.greenFrontLatitude, let fLon = hole.greenFrontLongitude,
              let bLat = hole.greenBackLatitude, let bLon = hole.greenBackLongitude else {
            return nil
        }
        let front = CLLocation(latitude: fLat, longitude: fLon)
        let back = CLLocation(latitude: bLat, longitude: bLon)
        let yards = front.distance(from: back) * 1.09361
        let isWarning = yards < 20 || yards > 40
        let text = isWarning
            ? String(format: "Front → Back: %.0f yds (typical greens are 20-40 yds)", yards)
            : String(format: "Front → Back: %.0f yds \u{2713}", yards)
        return DistanceReadout(text: text, isWarning: isWarning)
    }

    // MARK: - Save
    private func savePins() {
        // SwiftData auto-persists @Model mutations; this is mostly a UX marker.
        Haptics.success()

        // If this is a community course with a cloud record, offer to sync back.
        if course.courseSource == "community", course.cloudRecordID != nil,
           CloudKitCourseService.shared.isAvailable {
            showShareAlert = true
        } else {
            dismiss()
        }
    }
}
