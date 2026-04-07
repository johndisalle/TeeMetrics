// MARK: - Hole Logger View
// Individual hole scoring: big tappable score, putts, penalties,
// Fairway/GIR/Sand Save toggles, notes, shot tracker access

import SwiftUI
import SwiftData

struct HoleLoggerView: View {
    @Bindable var entry: HoleEntry
    @Query(filter: #Predicate<Bag> { $0.isDefault == true }) private var bags: [Bag]
    var onShowShotTracker: () -> Void

    private var clubTip: String? {
        ClubRecommendationEngine.suggestForHole(
            holeInfo: entry.holeInfo,
            shotNumber: entry.shots.count + 1,
            bag: bags.first
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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

                // MARK: - Hole Info
                HStack {
                    Text("Hole \(entry.holeNumber)")
                        .font(.title2.bold())
                    Spacer()
                    Text("Par \(entry.par)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if let info = entry.holeInfo {
                        Text("\(info.yardage) yds")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Score Stepper (big tappable)
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        Button {
                            if entry.score > 0 { entry.score -= 1 }
                            Haptics.light()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Theme.primary)
                        }

                        VStack(spacing: 4) {
                            Text("\(entry.score)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                            if entry.score > 0 {
                                Text(entry.scoreLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.scoreColor(for: entry.scoreToPar))
                            }
                        }
                        .frame(width: 100)

                        Button {
                            entry.score += 1
                            Haptics.light()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score: \(entry.score). \(entry.score > 0 ? entry.scoreLabelAccessible : "Not yet scored")")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: entry.score += 1
                    case .decrement: if entry.score > 0 { entry.score -= 1 }
                    @unknown default: break
                    }
                }

                // MARK: - Putts & Penalties
                HStack(spacing: 32) {
                    stepperColumn(label: "PUTTS", value: $entry.putts)
                    stepperColumn(label: "PENALTIES", value: $entry.penalties)
                }

                // MARK: - Toggle Row
                HStack(spacing: 12) {
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

                    toggleButton(
                        label: "GIR",
                        isOn: $entry.greenInRegulation,
                        icon: "target"
                    )

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
