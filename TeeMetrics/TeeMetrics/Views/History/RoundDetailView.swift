// MARK: - Round Detail View
// Full round recap: scorecard, stats summary, hole-by-hole breakdown, share

import SwiftUI

struct RoundDetailView: View {
    let round: GolfRound
    @State private var showShareSheet = false

    private var sortedEntries: [HoleEntry] {
        round.holeEntries.sorted { $0.holeNumber < $1.holeNumber }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header Card
                VStack(spacing: 8) {
                    Text(round.course?.name ?? "Unknown Course")
                        .font(.title2.bold())
                    Text(round.date.shortFormatted)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 32) {
                        VStack {
                            Text("\(round.totalScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text(round.scoreToParString)
                                .font(.headline)
                                .foregroundStyle(Theme.scoreColor(for: round.scoreToPar))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            statLine("Front 9", value: "\(round.frontNine)")
                            statLine("Back 9", value: "\(round.backNine)")
                            statLine("Putts", value: "\(round.totalPutts)")
                            statLine("FW%", value: String(format: "%.0f%%", round.fairwayPercentage))
                            statLine("GIR%", value: String(format: "%.0f%%", round.girPercentage))
                        }
                    }
                }
                .cardStyle()

                // MARK: - Strokes Gained (Pro)
                if SubscriptionManager.shared.isProUser {
                    strokesGainedCard
                }

                // MARK: - Scorecard Grid
                scorecardSection

                // MARK: - Hole Details
                ForEach(sortedEntries) { entry in
                    HoleDetailRow(entry: entry)
                }

                // MARK: - Notes
                if !round.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(round.notes)
                            .foregroundStyle(.secondary)
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
        .navigationTitle("Round Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: roundSummaryText,
                    subject: Text("My Golf Round"),
                    message: Text("Check out my round!")
                )
            }
        }
    }

    // MARK: - Stat Line
    private func statLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.subheadline.bold())
        }
    }

    // MARK: - Strokes Gained Card
    private var strokesGainedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strokes Gained")
                .font(.headline)

            HStack(spacing: 16) {
                sgItem("Off Tee", value: StatsCalculator.strokesGainedOffTee(round: round))
                sgItem("Approach", value: StatsCalculator.strokesGainedApproach(round: round))
                sgItem("Short", value: StatsCalculator.strokesGainedShortGame(round: round))
                sgItem("Putting", value: StatsCalculator.strokesGainedPutting(round: round))
            }
        }
        .cardStyle()
    }

    private func sgItem(_ label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%+.1f", value))
                .font(.headline)
                .foregroundStyle(value >= 0 ? .green : .red)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scorecard
    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scorecard")
                .font(.headline)

            // Front 9
            scorecardRow(entries: sortedEntries.filter { $0.holeNumber <= 9 }, label: "OUT")
            // Back 9
            scorecardRow(entries: sortedEntries.filter { $0.holeNumber > 9 }, label: "IN")
        }
        .cardStyle()
    }

    private func scorecardRow(entries: [HoleEntry], label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(entries) { entry in
                    VStack(spacing: 2) {
                        Text("\(entry.holeNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(entry.par)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(entry.score)")
                            .font(.caption.bold())
                            .frame(width: 26, height: 26)
                            .background(scoreBackground(for: entry.scoreToPar))
                            .clipShape(Circle())
                            .foregroundStyle(entry.scoreToPar <= -1 ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                VStack(spacing: 2) {
                    Text("")
                    Text(label)
                        .font(.caption2.bold())
                    Text("\(entries.reduce(0) { $0 + $1.score })")
                        .font(.caption.bold())
                }
                .frame(width: 36)
            }
        }
    }

    private func scoreBackground(for toPar: Int) -> Color {
        switch toPar {
        case ...(-2): return Theme.eagle
        case -1: return Theme.birdie
        case 0: return .clear
        case 1: return Theme.bogey.opacity(0.2)
        default: return Theme.doublePlus.opacity(0.2)
        }
    }

    // MARK: - Share Text
    private var roundSummaryText: String {
        """
        TeeMetrics Round Summary
        \(round.course?.name ?? "Unknown") - \(round.date.shortFormatted)
        Score: \(round.totalScore) (\(round.scoreToParString))
        Front: \(round.frontNine) | Back: \(round.backNine)
        Putts: \(round.totalPutts) | FW: \(String(format: "%.0f%%", round.fairwayPercentage)) | GIR: \(String(format: "%.0f%%", round.girPercentage))
        """
    }
}

// MARK: - Hole Detail Row
struct HoleDetailRow: View {
    let entry: HoleEntry

    var body: some View {
        HStack {
            Text("#\(entry.holeNumber)")
                .font(.caption.bold())
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Par \(entry.par)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let info = entry.holeInfo {
                        Text("\(info.yardage)y")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if entry.fairwayHit == true {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if entry.greenInRegulation {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Text("\(entry.putts)P")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(entry.score)")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.scoreColor(for: entry.scoreToPar))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
    }
}
