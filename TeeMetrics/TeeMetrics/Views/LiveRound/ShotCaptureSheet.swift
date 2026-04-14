// MARK: - Shot Capture Sheet (Pro)
// Bottom sheet presented when the user taps the on-course "Record Shot"
// button. Big tappable rows for every club in the default bag plus a
// "No club" fallback for penalty drops / provisionals.
//
// Tapping a row:
//   1. Pulls the latest GPS fix from RoundLocationManager
//   2. If there's an open shot on this hole, closes it with that fix
//      (the "shot N's end == shot N+1's start" chain)
//   3. Inserts a brand-new Shot with start = current fix, club = tapped row
//   4. Dismisses the sheet
//
// Stale or missing GPS is surfaced as an inline warning but does NOT
// block capture — tap-only is the explicit goal.

import SwiftUI
import SwiftData
import CoreLocation

struct ShotCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Round we're appending shots to.
    let round: GolfRound
    /// Hole the player is currently on (1-18).
    let holeNumber: Int

    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]
    @State private var locationManager = RoundLocationManager.shared

    private var clubs: [Club] {
        bags.first?.sortedClubs ?? []
    }

    /// True when the latest GPS fix is fresh enough to use for shot
    /// capture. The 30-second threshold matches DistanceToGreenCard's
    /// "signal lost" cutoff.
    private var hasFreshFix: Bool {
        guard let fix = locationManager.currentLocation else { return false }
        return Date().timeIntervalSince(fix.timestamp) < 30
    }

    var body: some View {
        NavigationStack {
            List {
                if !hasFreshFix {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundStyle(.orange)
                            Text(locationManager.currentLocation == nil
                                 ? "No GPS fix yet — shot will use last known location."
                                 : "GPS fix is stale — shot may be slightly off.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Bag") {
                    if clubs.isEmpty {
                        Text("No clubs in your default bag.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(clubs) { club in
                            Button {
                                capture(clubName: club.name)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: club.systemImage)
                                        .font(.title3)
                                        .foregroundStyle(Theme.primary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(club.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(club.clubType.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if club.avgDistance > 0 {
                                        Text("\(club.avgDistance) yd avg")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button {
                        capture(clubName: nil)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "scope")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No club — just log position")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Penalty drop, provisional, etc.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Record Shot \(ShotTracker.nextShotNumber(round: round, holeNumber: holeNumber))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func capture(clubName: String?) {
        ShotTracker.recordShot(
            round: round,
            holeNumber: holeNumber,
            clubName: clubName,
            location: locationManager.currentLocation,
            context: modelContext
        )
        Haptics.success()
        dismiss()
    }
}

// MARK: - ShotTracker
// Pure helpers for the shot-capture lifecycle. Lives outside the view so
// the auto-close-on-hole-advance and auto-close-on-finish wiring can call
// the same code without depending on the sheet being open.
@MainActor
enum ShotTracker {

    /// All Shot rows on this round/hole, sorted ascending by shotNumber.
    static func shots(for round: GolfRound, holeNumber: Int) -> [Shot] {
        round.shots
            .filter { $0.holeNumber == holeNumber }
            .sorted { $0.shotNumber < $1.shotNumber }
    }

    /// 1-indexed number that the next captured shot will receive.
    static func nextShotNumber(round: GolfRound, holeNumber: Int) -> Int {
        shots(for: round, holeNumber: holeNumber).count + 1
    }

    /// The most recent open shot on the hole (last shot with no end), or
    /// nil if every shot has been closed.
    static func openShot(for round: GolfRound, holeNumber: Int) -> Shot? {
        shots(for: round, holeNumber: holeNumber).last { !$0.isClosed }
    }

    /// Records a new shot on the given hole. If there's an open shot
    /// already on this hole, it gets closed with the same fix first
    /// (chain rule).
    static func recordShot(
        round: GolfRound,
        holeNumber: Int,
        clubName: String?,
        location: CLLocation?,
        context: ModelContext
    ) {
        let now = Date()
        let coord = location?.coordinate
        // Vertical accuracy < 0 means the device couldn't fix altitude
        // even though horizontal accuracy was usable — treat as unknown.
        let elevation: Double? = {
            guard let loc = location, loc.verticalAccuracy >= 0 else { return nil }
            return loc.altitude
        }()

        // Close any open shot on this hole at the current fix.
        if let open = openShot(for: round, holeNumber: holeNumber),
           let coord {
            open.endLatitude = coord.latitude
            open.endLongitude = coord.longitude
            open.endElevation = elevation
            open.endedAt = now
        }

        // Insert the new shot, defaulting start to (0,0) only if we
        // somehow have no fix at all — better than a crash, and the
        // post-round display will read "—" yards on it.
        let startLat = coord?.latitude ?? 0
        let startLon = coord?.longitude ?? 0
        let nextNumber = nextShotNumber(round: round, holeNumber: holeNumber)

        let shot = Shot(
            holeNumber: holeNumber,
            shotNumber: nextNumber,
            startLatitude: startLat,
            startLongitude: startLon,
            startElevation: elevation,
            startedAt: now,
            clubName: clubName,
            round: round
        )
        context.insert(shot)
    }

    /// Deletes the most recent shot on the hole and reopens the prior
    /// shot (if any) by clearing its end fields. Called from the
    /// HoleLoggerView "Undo last shot" link.
    static func undoLastShot(
        round: GolfRound,
        holeNumber: Int,
        context: ModelContext
    ) {
        let list = shots(for: round, holeNumber: holeNumber)
        guard let last = list.last else { return }

        // Reopen the previous shot if one exists.
        if list.count >= 2 {
            let prior = list[list.count - 2]
            prior.endLatitude = nil
            prior.endLongitude = nil
            prior.endElevation = nil
            prior.endedAt = nil
        }

        context.delete(last)
    }

    /// Closes any open shot on the hole using the supplied location.
    /// Called from LiveRoundView when the player advances holes or
    /// finishes the round, so the final shot of every hole has an
    /// endpoint without requiring the player to tap "hole out".
    static func closeOpenShot(
        round: GolfRound,
        holeNumber: Int,
        with location: CLLocation?
    ) {
        guard let open = openShot(for: round, holeNumber: holeNumber),
              let loc = location else { return }
        open.endLatitude = loc.coordinate.latitude
        open.endLongitude = loc.coordinate.longitude
        open.endElevation = loc.verticalAccuracy >= 0 ? loc.altitude : nil
        open.endedAt = Date()
    }
}
