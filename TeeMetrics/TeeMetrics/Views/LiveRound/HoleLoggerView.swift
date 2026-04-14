// MARK: - Hole Logger View
// Quick-score buttons + detailed mode, putts, penalties,
// Fairway/GIR/Sand Save toggles, club recommendation, shot tracker

import SwiftUI
import SwiftData

struct HoleLoggerView: View {
    @Bindable var entry: HoleEntry
    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]
    var onShowShotTracker: () -> Void

    @State private var showDetailedMode = false
    @State private var scoreFlash = false

    private var clubTip: String? {
        ClubRecommendationEngine.suggestForHole(
            holeInfo: entry.holeInfo,
            shotNumber: entry.shots.count + 1,
            bag: bags.first
        )
    }

    // MARK: - Tee-aware hole data (Phase 2)
    /// The TeeHole row for the current hole if the round was started from a
    /// specific tee box. Nil when the round has no tee selection or the
    /// course has no tees array.
    private var selectedTeeHole: TeeHole? {
        entry.round?.selectedTee?.hole(number: entry.holeNumber)
    }

    /// Yardage to display: prefers the selected tee's yardage, falls back to
    /// HoleInfo's default.
    private var displayYardage: Int? {
        if let y = selectedTeeHole?.yardage, y > 0 { return y }
        return entry.holeInfo?.yardage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Hole Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hole \(entry.holeNumber)")
                            .font(.title2.bold())
                        HStack(spacing: 8) {
                            Text("Par \(entry.par)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let yds = displayYardage {
                                Text("\u{2022} \(yds) yds")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let teeName = entry.round?.teeName {
                                Text("\u{2022} \(teeName)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                    Spacer()
                    if entry.score > 0 {
                        Text(entry.scoreLabel)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.scoreColor(for: entry.scoreToPar))
                            .clipShape(Capsule())
                            .scaleEffect(scoreFlash ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: scoreFlash)
                    }
                }

                // MARK: - Club Recommendation
                if let tip = clubTip {
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Theme.accent)
                        Text(tip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // MARK: - Quick Score Buttons (2-tap scoring)
                VStack(spacing: 10) {
                    Text("QUICK SCORE")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        quickScoreButton(label: scoreLabel(for: entry.par - 2), value: entry.par - 2, color: Theme.eagle)
                        quickScoreButton(label: scoreLabel(for: entry.par - 1), value: entry.par - 1, color: Theme.birdie)
                        quickScoreButton(label: "Par", value: entry.par, color: Theme.par)
                        quickScoreButton(label: "Bogey", value: entry.par + 1, color: Theme.bogey)
                        quickScoreButton(label: "Dbl", value: entry.par + 2, color: Theme.doublePlus)
                    }

                    // Other score button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showDetailedMode.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showDetailedMode ? "Hide Stepper" : "Other Score...")
                                .font(.caption)
                            Image(systemName: showDetailedMode ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Detailed Stepper (expandable)
                if showDetailedMode {
                    HStack(spacing: 24) {
                        Button {
                            if entry.score > 0 { entry.score -= 1 }
                            Haptics.light()
                            flashScore()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.primary)
                        }

                        Text("\(entry.score)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .frame(width: 80)

                        Button {
                            entry.score += 1
                            Haptics.light()
                            flashScore()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: - Putts (always visible — critical stat)
                HStack(spacing: 32) {
                    stepperColumn(label: "PUTTS", value: $entry.putts)
                    stepperColumn(label: "PENALTIES", value: $entry.penalties)
                }

                // MARK: - Toggle Row
                HStack(spacing: 10) {
                    if entry.par >= 4 {
                        toggleButton(
                            label: "FW",
                            isOn: Binding(
                                get: { entry.fairwayHit ?? false },
                                set: { entry.fairwayHit = $0 }
                            ),
                            icon: "leaf.fill"
                        )
                    }

                    toggleButton(label: "GIR", isOn: $entry.greenInRegulation, icon: "target")

                    toggleButton(
                        label: "Sand",
                        isOn: Binding(
                            get: { entry.sandSave ?? false },
                            set: { entry.sandSave = $0 }
                        ),
                        icon: "sun.dust.fill"
                    )

                    toggleButton(
                        label: "U&D",
                        isOn: Binding(
                            get: { entry.upAndDown ?? false },
                            set: { entry.upAndDown = $0 }
                        ),
                        icon: "arrow.up.arrow.down"
                    )
                }

                // MARK: - Shot Tracker
                Button {
                    onShowShotTracker()
                } label: {
                    Label("Track Shots (\(entry.shots.count))", systemImage: "scope")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // MARK: - Notes
                TextField("Hole notes...", text: $entry.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Quick Score Button
    private func quickScoreButton(label: String, value: Int, color: Color) -> some View {
        Button {
            entry.score = value
            Haptics.medium()
            flashScore()
        } label: {
            VStack(spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(entry.score == value ? color : color.opacity(0.12))
            .foregroundStyle(entry.score == value ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(entry.score == value ? color : .clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("\(label), score \(value)")
    }

    private func scoreLabel(for score: Int) -> String {
        let diff = score - entry.par
        switch diff {
        case ...(-2): return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        default: return "Dbl+"
        }
    }

    private func flashScore() {
        scoreFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scoreFlash = false
        }
    }

    // MARK: - Mini Stepper
    private func stepperColumn(label: String, value: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Button {
                    if value.wrappedValue > 0 { value.wrappedValue -= 1 }
                    Haptics.light()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primary)
                }
                Text("\(value.wrappedValue)")
                    .font(.title.bold())
                    .frame(width: 40)
                Button {
                    value.wrappedValue += 1
                    Haptics.light()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }

    // MARK: - Toggle Button
    private func toggleButton(label: String, isOn: Binding<Bool>, icon: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            Haptics.selection()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? Theme.primary : Color.gray.opacity(0.15))
            .foregroundStyle(isOn.wrappedValue ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel("\(label): \(isOn.wrappedValue ? "on" : "off")")
    }
}
