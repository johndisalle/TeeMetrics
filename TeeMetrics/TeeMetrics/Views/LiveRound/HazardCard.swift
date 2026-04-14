// MARK: - HazardCard (Phase 2 GPS — Pro)
// Live "next hazard" HUD rendered just below DistanceToGreenCard during
// an active round. Garmin-style: only the upcoming hazard's kind + carry
// and into yardages, not a full list.
//
// Self-hiding rules — the card returns EmptyView to collapse to zero
// size inside HoleLoggerView's VStack when there's nothing useful to
// show, so the layout doesn't jitter as the golfer walks past hazards:
//
//   1. Hole has zero mapped hazards → hide entirely (Pro or not)
//   2. Non-Pro user + hole has hazards → show generic Pro lock card via
//      .proGated(.hazardDistances) as a teaser
//   3. Pro user + waiting for GPS fix → hide (DistanceToGreenCard already
//      shows an acquiring state; we don't want two spinners)
//   4. Pro user + no hazard in the forward cone → hide (silent)
//   5. Pro user + hazard ahead → show it
//
// The TimelineView polls every 5 seconds so the card switches to/from
// the "nothing ahead" state as the golfer walks, without needing a
// continuous update stream.

import SwiftUI
import CoreLocation

struct HazardCard: View {
    let holeInfo: HoleInfo?

    @State private var locationManager = RoundLocationManager.shared

    var body: some View {
        // State 1: no hazards on this hole → hide entirely.
        // This check runs BEFORE the Pro gate so non-Pro users don't see
        // upgrade teasers on every pinless hole — only on holes where
        // the feature would actually do something.
        if let info = holeInfo, !info.hazards.isEmpty {
            gatedContent(info: info)
                .proGated(.hazardDistances)
        }
    }

    // MARK: - Pro content
    /// Everything visible only to Pro users. Returns EmptyView when there's
    /// no hazard ahead so the card stays silent between hazards.
    @ViewBuilder
    private func gatedContent(info: HoleInfo) -> some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            hazardContent(info: info)
        }
    }

    @ViewBuilder
    private func hazardContent(info: HoleInfo) -> some View {
        if let player = locationManager.currentLocation,
           let next = HazardCalculator.nextHazard(in: info, from: player) {
            hazardRow(next)
        }
        // else: silent (no EmptyView needed — nil branch collapses)
    }

    // MARK: - Hazard Row
    private func hazardRow(_ next: NextHazard) -> some View {
        let tint = tint(for: next.kind)
        return HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: next.kind.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }

            // Kind label above numbers
            VStack(alignment: .leading, spacing: 2) {
                Text(next.kind.label)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.6)
                HStack(spacing: 14) {
                    numberPair(label: "Carry", yards: next.carryDistance, color: tint)
                    divider
                    numberPair(label: "Into", yards: next.intoDistance, color: .secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(next.kind.label) ahead, carry \(next.carryDistance) yards, into \(next.intoDistance) yards")
    }

    private func numberPair(label: String, yards: Int, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(yards)")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .frame(width: 1, height: 14)
    }

    // MARK: - Styling helpers
    /// UI tint color for a hazard kind. Kept in the view layer so
    /// HazardPin.swift (the model) stays UIKit/SwiftUI-free.
    private func tint(for kind: HazardKind) -> Color {
        switch kind {
        case .bunker: return Color(red: 0.82, green: 0.68, blue: 0.35)
        case .water: return Color(red: 0.20, green: 0.55, blue: 0.85)
        }
    }

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
}
