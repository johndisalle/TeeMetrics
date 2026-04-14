// MARK: - DistanceToGreenCard (Phase 1C)
// Compact glass-style card rendered at the top of HoleLoggerView during a
// live round. Shows front/center/back yardages to the green for the current
// hole, driven by RoundLocationManager.shared.currentLocation.
//
// Five states, in priority order:
//
//   1. No pins on the current hole       → tappable "Tap to set green pins"
//                                           placeholder that opens
//                                           HoleGPSEditorView for the course,
//                                           seeded to the current hole.
//
//   2. Location permission denied         → "Enable location in Settings"
//                                           with a button that deep-links
//                                           to UIApplication.openSettingsURLString.
//
//   3. Pins + no location fix yet         → "Acquiring GPS..." with spinner.
//
//   4. Pins + location older than 30s     → "Signal lost" with refresh hint.
//                                           TimelineView polls every 5s so
//                                           we exit this state as soon as a
//                                           new fix arrives.
//
//   5. Pins + fresh location              → three numbers (F / C / B) with
//                                           C rendered ~44pt and F/B ~18pt.
//
// This card is explicitly NOT pro-gated — distance-to-green is the free
// tier hook that pulls users back to the app on the course.

import SwiftUI
import CoreLocation
import UIKit

struct DistanceToGreenCard: View {
    let course: GolfCourse?
    let holeInfo: HoleInfo?

    /// Observed singleton — SwiftUI will re-render this view whenever
    /// `currentLocation` or `authorizationStatus` changes.
    @State private var locationManager = RoundLocationManager.shared

    /// Present the GPS editor when the user taps the no-pins placeholder.
    @State private var showGPSEditor = false

    /// Cached wind reading for the active course. Fetched once when the
    /// card appears and refreshed when the hole changes (which lets
    /// `WeatherService`'s 15-minute TTL handle deduplication).
    @State private var currentWind: WindReading? = nil

    /// How long a fix can be before we consider the signal lost.
    private static let signalLostThreshold: TimeInterval = 30

    /// Pro gate — plays-like distance is a Pro feature.
    private var playsLikeUnlocked: Bool {
        !GatingManager.shared.requiresPro(feature: .playsLikeDistance)
    }

    // MARK: - Body
    var body: some View {
        Group {
            if let info = holeInfo {
                contentForState(info: info)
            } else {
                // Hole has no matching HoleInfo (shouldn't happen in practice
                // but guard explicitly).
                EmptyView()
            }
        }
        .sheet(isPresented: $showGPSEditor) {
            if let course {
                HoleGPSEditorView(course: course)
            }
        }
        // Fetch wind once per hole change. WeatherService caches for 15
        // minutes so this is effectively a single network call per round
        // unless the user lingers past the TTL.
        .task(id: holeInfo?.id) {
            guard playsLikeUnlocked,
                  let info = holeInfo,
                  info.hasGreenPins,
                  let lat = info.greenCenterLatitude,
                  let lon = info.greenCenterLongitude
            else { return }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            currentWind = await WeatherService.shared.currentWind(at: coord)
        }
    }

    // MARK: - State Router
    @ViewBuilder
    private func contentForState(info: HoleInfo) -> some View {
        if !info.hasGreenPins {
            // State 1: no pins
            noPinsPlaceholder
        } else if locationManager.authorizationStatus == .denied
                    || locationManager.authorizationStatus == .restricted {
            // State 2: permission denied
            permissionDeniedCard
        } else {
            // States 3/4/5 — re-evaluate every 5 seconds so the "signal
            // lost" threshold kicks in even when no new location arrives.
            TimelineView(.periodic(from: .now, by: 5)) { ctx in
                locationAwareContent(info: info, now: ctx.date)
            }
        }
    }

    @ViewBuilder
    private func locationAwareContent(info: HoleInfo, now: Date) -> some View {
        if let fix = locationManager.currentLocation {
            let age = now.timeIntervalSince(fix.timestamp)
            if age > Self.signalLostThreshold {
                // State 4: signal lost
                signalLostCard
            } else {
                // State 5: distances
                distancesCard(info: info, location: fix)
            }
        } else {
            // State 3: acquiring
            acquiringCard
        }
    }

    // MARK: - State 5: Distances
    private func distancesCard(info: HoleInfo, location: CLLocation) -> some View {
        let d = info.distanceYards(from: location)
        let front = d.front.map { Int($0.rounded()) }
        let center = d.center.map { Int($0.rounded()) }
        let back = d.back.map { Int($0.rounded()) }

        // Plays-like adjustment lives below the center pillar. Computed
        // off the raw center-of-green yardage; nil when the user is
        // non-Pro, when no adjustment data is available, or when the
        // adjusted value matches raw.
        let playsLikeYards = playsLikeYards(info: info, location: location, rawCenterYards: d.center)

        return VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 24) {
                distancePillar(
                    label: "F",
                    yards: front,
                    size: 22,
                    weight: .medium,
                    color: .secondary
                )
                distancePillar(
                    label: "C",
                    yards: center,
                    size: 44,
                    weight: .semibold,
                    color: Theme.primary
                )
                distancePillar(
                    label: "B",
                    yards: back,
                    size: 22,
                    weight: .medium,
                    color: .secondary
                )
            }
            if let playsLikeYards {
                Text("plays \(playsLikeYards)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("plays like \(playsLikeYards) yards")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(front: front, center: center, back: back))
    }

    /// Computes the plays-like center yardage for the current player
    /// fix and returns the rounded integer. Returns nil whenever the
    /// "plays N" line should NOT be shown:
    ///   - user is not a Pro subscriber
    ///   - no center pin / no center yardage
    ///   - neither elevation nor wind data is available
    ///   - rounded adjusted value equals rounded raw value (no visible delta)
    private func playsLikeYards(info: HoleInfo, location: CLLocation, rawCenterYards: Double?) -> Int? {
        guard playsLikeUnlocked,
              let raw = rawCenterYards,
              let lat = info.greenCenterLatitude,
              let lon = info.greenCenterLongitude
        else { return nil }

        let userElevation: Double? = location.verticalAccuracy >= 0 ? location.altitude : nil
        let pinElevation = info.greenCenterElevation

        // Bail if BOTH adjustment sources are nil — nothing to compute.
        let hasElev = userElevation != nil && pinElevation != nil
        let hasWind = currentWind != nil
        guard hasElev || hasWind else { return nil }

        let bearing = location.coordinate.bearing(to: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let result = PlaysLikeCalculator.compute(
            PlaysLikeInputs(
                rawDistanceYards: raw,
                bearingToTarget: bearing,
                userElevationMeters: userElevation,
                targetElevationMeters: pinElevation,
                wind: currentWind
            )
        )

        let rawRounded = Int(raw.rounded())
        let adjustedRounded = Int(result.adjustedYards.rounded())
        // Hide the line when the adjustment doesn't change the visible
        // number (flat hole + no wind, or perfect crosswind on a flat
        // hole, etc.).
        guard adjustedRounded != rawRounded else { return nil }
        return adjustedRounded
    }

    private func distancePillar(
        label: String,
        yards: Int?,
        size: CGFloat,
        weight: Font.Weight,
        color: Color
    ) -> some View {
        VStack(spacing: 2) {
            Text(yards.map { "\($0)" } ?? "—")
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    // MARK: - State 3: Acquiring GPS
    private var acquiringCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Acquiring GPS...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(cardBackground)
    }

    // MARK: - State 4: Signal Lost
    private var signalLostCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Signal lost")
                    .font(.subheadline.bold())
                Text("Waiting for a fresh GPS fix...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(cardBackground)
    }

    // MARK: - State 1: No Pins Placeholder
    private var noPinsPlaceholder: some View {
        Button {
            showGPSEditor = true
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tap to set green pins")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Get live distances during your round")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.primary.opacity(0.25), lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - State 2: Permission Denied
    private var permissionDeniedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Location off")
                    .font(.subheadline.bold())
                Text("Enable location in Settings for live distances")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(cardBackground)
    }

    // MARK: - Shared Card Background (glass-style)
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    // MARK: - Accessibility
    private func accessibilityLabel(front: Int?, center: Int?, back: Int?) -> String {
        var parts: [String] = []
        if let front { parts.append("Front \(front) yards") }
        if let center { parts.append("Center \(center) yards") }
        if let back { parts.append("Back \(back) yards") }
        return parts.isEmpty ? "Distance to green unavailable" : parts.joined(separator: ", ")
    }
}
