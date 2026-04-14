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
    /// Active hazard placement mode (Phase 2 GPS). Mutually exclusive with
    /// `activePin` — selecting one clears the other so the map never has
    /// two "what to drop next" intents at once.
    @State private var activeHazardKind: HazardKind? = nil
    /// Hazard staged for deletion by tapping an existing map annotation.
    /// When non-nil, triggers the confirm-delete alert.
    @State private var hazardPendingDelete: HazardPin? = nil
    @State private var showDeleteHazardAlert = false
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

    // MARK: - Hazard editing gate (Phase 2 GPS)
    /// Hazard editing is a pure Pro feature on every course, on top of
    /// the regular pin-edit gate. Non-Pro users see the hazard buttons
    /// but tapping one presents the paywall instead of entering
    /// placement mode.
    private var canEditHazards: Bool {
        GatingManager.shared.isProUser
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
            .alert(
                "Delete \(hazardPendingDelete?.hazardKind?.label.lowercased() ?? "hazard")?",
                isPresented: $showDeleteHazardAlert
            ) {
                Button("Delete", role: .destructive) { deletePendingHazard() }
                Button("Cancel", role: .cancel) { hazardPendingDelete = nil }
            } message: {
                Text("Remove this hazard pin from the current hole.")
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
            activeHazardKind = nil
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
        ZStack {
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

                        // Hazard pins for the current hole (Phase 2 GPS).
                        // Tapping an existing hazard stages it for delete
                        // when no placement mode is active.
                        ForEach(hole.hazards) { hazard in
                            let coord = CLLocationCoordinate2D(
                                latitude: hazard.latitude,
                                longitude: hazard.longitude
                            )
                            Annotation(hazard.hazardKind?.label ?? "Hazard", coordinate: coord) {
                                hazardPinView(kind: hazard.hazardKind ?? .bunker)
                                    .onTapGesture {
                                        handleHazardTap(hazard)
                                    }
                            }
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .onTapGesture(coordinateSpace: .local) { screenPoint in
                    if let pin = activePin,
                       let coord = proxy.convert(screenPoint, from: .local) {
                        setPin(pin, coordinate: coord)
                    } else if let kind = activeHazardKind,
                              let coord = proxy.convert(screenPoint, from: .local) {
                        addHazard(kind: kind, at: coord)
                    }
                }
            }

            // Placement-mode banner (top-right)
            if let pin = activePin {
                VStack {
                    HStack {
                        Spacer()
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
                    Spacer()
                }
            } else if let kind = activeHazardKind {
                VStack {
                    HStack {
                        Spacer()
                        Text("Tap the map to place \(kind.label.uppercased())")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hazardTint(for: kind).opacity(0.9))
                            .clipShape(Capsule())
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                            .shadow(radius: 4)
                    }
                    Spacer()
                }
            }

            // Recenter button (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        centerCameraOnCourse()
                        Haptics.selection()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    }
                    .accessibilityLabel("Recenter map on course")
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 10) {
            if let hole = currentHole {
                // Three pin buttons (F / C / B)
                HStack(spacing: 8) {
                    pinButton(kind: .front, isSet: hole.greenFrontLatitude != nil)
                    pinButton(kind: .center, isSet: hole.greenCenterLatitude != nil)
                    pinButton(kind: .back, isSet: hole.greenBackLatitude != nil)
                }

                // Hazard pin buttons (Phase 2 GPS — Pro)
                HStack(spacing: 8) {
                    hazardButton(kind: .bunker, hole: hole)
                    hazardButton(kind: .water, hole: hole)
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

    // MARK: - Hazard Button (Phase 2 GPS)
    private func hazardButton(kind: HazardKind, hole: HoleInfo) -> some View {
        let count = hole.hazards.filter { $0.hazardKind == kind }.count
        let tint = hazardTint(for: kind)
        let isActive = activeHazardKind == kind
        let locked = !canEditHazards

        return Button {
            // Pro gate: non-Pro users get the paywall instead of placement mode.
            if locked {
                showPaywall = true
                Haptics.selection()
                return
            }

            // Toggle placement mode; clear F/C/B mode since they're mutually
            // exclusive.
            if activeHazardKind == kind {
                activeHazardKind = nil
            } else {
                activeHazardKind = kind
                activePin = nil
            }
            Haptics.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: locked ? "lock.fill" : kind.systemImage)
                    .font(.title3)
                Text(kind.label)
                    .font(.caption2.bold())
                if count > 0 && !locked {
                    Text("(\(count))")
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? tint : tint.opacity(0.12))
            .foregroundStyle(isActive ? .white : tint)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.clear : tint.opacity(0.4), lineWidth: 1)
            )
            .opacity(locked ? 0.75 : 1.0)
        }
        .accessibilityLabel("\(kind.label) hazard placement\(locked ? ", locked — Pro feature" : "")")
    }

    /// UI tint color for a hazard kind. Kept here rather than on
    /// HazardKind so the model file doesn't need SwiftUI.
    private func hazardTint(for kind: HazardKind) -> Color {
        switch kind {
        case .bunker: return Color(red: 0.82, green: 0.68, blue: 0.35) // sand beige
        case .water: return Color(red: 0.20, green: 0.55, blue: 0.85)  // pool blue
        }
    }

    // MARK: - Hazard Annotation View
    private func hazardPinView(kind: HazardKind) -> some View {
        let tint = hazardTint(for: kind)
        return ZStack {
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            Image(systemName: kind.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    // MARK: - Hazard Mutations
    /// Create a HazardPin at the given coordinate for the current hole.
    /// Clears placement mode afterwards so the user can preview the result.
    private func addHazard(kind: HazardKind, at coordinate: CLLocationCoordinate2D) {
        guard let hole = currentHole else { return }
        let hazard = HazardPin(
            kind: kind,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            hole: hole
        )
        modelContext.insert(hazard)
        activeHazardKind = nil
        Haptics.success()
    }

    /// Called when a hazard annotation is tapped. Stages the hazard for
    /// delete only when no placement mode is active — otherwise falls
    /// through so the placement tap can land nearby (note: the Annotation
    /// tap still consumes the gesture, so placement-on-top-of-hazard is
    /// a minor known limitation).
    private func handleHazardTap(_ hazard: HazardPin) {
        guard activePin == nil, activeHazardKind == nil else { return }
        hazardPendingDelete = hazard
        showDeleteHazardAlert = true
    }

    /// Delete the staged hazard from SwiftData.
    private func deletePendingHazard() {
        guard let hazard = hazardPendingDelete else { return }
        modelContext.delete(hazard)
        hazardPendingDelete = nil
        Haptics.medium()
    }

    // MARK: - Helpers
    private func coordinate(lat: Double?, lon: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Saves a pin coordinate. When called from "Use My Location", the
    /// caller passes the user's current `CLLocation.altitude` so plays-like
    /// elevation math has data to work with later. Map-tap placements
    /// pass nil — there's no way to know the elevation of a tap point.
    private func setPin(
        _ kind: PinKind,
        coordinate: CLLocationCoordinate2D,
        elevation: Double? = nil
    ) {
        guard let hole = currentHole else { return }
        switch kind {
        case .front:
            hole.greenFrontLatitude = coordinate.latitude
            hole.greenFrontLongitude = coordinate.longitude
            if let elevation { hole.greenFrontElevation = elevation }
        case .center:
            hole.greenCenterLatitude = coordinate.latitude
            hole.greenCenterLongitude = coordinate.longitude
            if let elevation { hole.greenCenterElevation = elevation }
        case .back:
            hole.greenBackLatitude = coordinate.latitude
            hole.greenBackLongitude = coordinate.longitude
            if let elevation { hole.greenBackElevation = elevation }
        }
        activePin = nil
        Haptics.success()
    }

    private func useCurrentLocationForActivePin() {
        guard let pin = activePin, let loc = locationManager.currentLocation else { return }
        // CLLocation.altitude is meters above sea level (the native unit
        // PlaysLikeCalculator expects). We use verticalAccuracy >= 0 as
        // the validity check — negative means the GPS device couldn't fix
        // altitude even though horizontal accuracy was usable.
        let altitude: Double? = loc.verticalAccuracy >= 0 ? loc.altitude : nil
        setPin(pin, coordinate: loc.coordinate, elevation: altitude)
    }

    // MARK: - Camera Centering (Phase 1B fix)
    /// Standard span for golf courses — ~1km square fits most full 18-hole layouts.
    private static let courseSpan = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)

    /// Returns the best known center coordinate using the priority order:
    ///   a) First placed center pin on any hole (user returning to edit).
    ///   b) Stored course lat/lng if non-zero (populated by importers).
    ///   c) User's current location if available.
    ///   d) nil → caller falls back to .automatic.
    private func bestCenterCoordinate() -> CLLocationCoordinate2D? {
        // (a) Existing center pin on any hole
        for hole in sortedHoles {
            if let lat = hole.greenCenterLatitude, let lon = hole.greenCenterLongitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        // (b) Stored course coordinates
        if course.latitude != 0 || course.longitude != 0 {
            return CLLocationCoordinate2D(latitude: course.latitude, longitude: course.longitude)
        }
        // (c) User's current location
        if let loc = locationManager.currentLocation {
            return loc.coordinate
        }
        // (d) No good center known
        return nil
    }

    private func centerCameraOnCourse() {
        guard let center = bestCenterCoordinate() else {
            cameraPosition = .automatic
            return
        }
        cameraPosition = .region(MKCoordinateRegion(center: center, span: Self.courseSpan))
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

        // Progressive course coordinate refinement (Phase 1B fix).
        // When a user places pins on a bundled or community course for the
        // first time, update the stored city-level lat/lng toward the actual
        // course location using the earliest placed center pin.
        refineCoordinatesIfNeeded()

        // If this is a community course with a cloud record, offer to sync back.
        if course.courseSource == "community", course.cloudRecordID != nil,
           CloudKitCourseService.shared.isAvailable {
            showShareAlert = true
        } else {
            dismiss()
        }
    }

    // MARK: - Progressive Coordinate Refinement (Phase 1B fix)
    /// Updates the course's stored lat/lng to the first center pin placed on
    /// any hole, so future opens of the GPS editor zoom to the correct
    /// location. Only runs on non-user courses (bundled or community) and
    /// only once per course (guarded by `coordinatesRefined`).
    ///
    /// For community courses with a valid CloudKit record, also pushes the
    /// refined location back to the public database so other players benefit.
    private func refineCoordinatesIfNeeded() {
        // Only refine bundled/community courses. User-created courses keep
        // whatever the user explicitly set.
        guard course.courseSource == "bundled" || course.courseSource == "community" else { return }

        // Only refine once.
        guard course.coordinatesRefined != true else { return }

        // Find the first placed center pin across all holes.
        guard let firstCenter = sortedHoles
            .compactMap({ hole -> CLLocationCoordinate2D? in
                guard let lat = hole.greenCenterLatitude, let lon = hole.greenCenterLongitude else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            })
            .first
        else { return }

        course.latitude = firstCenter.latitude
        course.longitude = firstCenter.longitude
        course.coordinatesRefined = true

        // For community courses, push the refined location back to CloudKit.
        if course.courseSource == "community",
           course.cloudRecordID != nil,
           CloudKitCourseService.shared.isAvailable {
            Task {
                _ = await CloudKitCourseService.shared.updateCourseLocation(for: course)
            }
        }
    }
}
