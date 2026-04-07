// MARK: - Round Comparison View
// Overlay two rounds on the same course side by side

import SwiftUI
import SwiftData
import Charts

struct RoundComparisonView: View {
    @Query(sort: \GolfRound.date, order: .reverse) private var allRounds: [GolfRound]
    @State private var round1: GolfRound?
    @State private var round2: GolfRound?

    private var completedRounds: [GolfRound] {
        allRounds.filter { $0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Round Selectors
                HStack(spacing: 12) {
                    roundPicker(label: "Round 1", selection: $round1, color: Theme.primary)
                    roundPicker(label: "Round 2", selection: $round2, color: Theme.accent)
                }

                if let r1 = round1, let r2 = round2 {
                    // MARK: - Score Comparison
                    comparisonHeader(r1: r1, r2: r2)

                    // MARK: - Hole-by-Hole Chart
                    holeByHoleChart(r1: r1, r2: r2)

                    // MARK: - Stat Comparison
                    statComparison(r1: r1, r2: r2)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.primary.opacity(0.3))
                        Text("Select two rounds to compare")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 48)
                }
            }
            .padding()
        }
        .navigationTitle("Compare Rounds")
    }

    private func roundPicker(label: String, selection: Binding<GolfRound?>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
            Picker(label, selection: selection) {
                Text("Select...").tag(nil as GolfRound?)
                ForEach(completedRounds) { round in
                    Text("\(round.course?.name ?? "?") — \(round.totalScore) (\(round.date.shortFormatted))")
                        .tag(round as GolfRound?)
                }
            }
            .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity)
    }

    private func comparisonHeader(r1: GolfRound, r2: GolfRound) -> some View {
        HStack(spacing: 0) {
            scoreBox(round: r1, color: Theme.primary, label: "R1")
            Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1, height: 80)
            scoreBox(round: r2, color: Theme.accent, label: "R2")
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func scoreBox(round: GolfRound, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(color)
            Text("\(round.totalScore)")
                .font(.title.bold())
            Text(round.scoreToParString)
                .font(.caption.bold())
                .foregroundStyle(Theme.scoreColor(for: round.scoreToPar))
            Text(round.date.shortFormatted)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func holeByHoleChart(r1: GolfRound, r2: GolfRound) -> some View {
        let e1 = r1.holeEntries.sorted { $0.holeNumber < $1.holeNumber }
        let e2 = r2.holeEntries.sorted { $0.holeNumber < $1.holeNumber }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Hole-by-Hole")
                .font(.headline)
            Chart {
                ForEach(Array(e1.enumerated()), id: \.offset) { i, entry in
                    LineMark(x: .value("Hole", i + 1), y: .value("Score", entry.score), series: .value("Round", "R1"))
                        .foregroundStyle(Theme.primary)
                }
                ForEach(Array(e2.enumerated()), id: \.offset) { i, entry in
                    LineMark(x: .value("Hole", i + 1), y: .value("Score", entry.score), series: .value("Round", "R2"))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(height: 200)
            .chartForegroundStyleScale(["R1": Theme.primary, "R2": Theme.accent])
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statComparison(r1: GolfRound, r2: GolfRound) -> some View {
        VStack(spacing: 12) {
            compRow("Total Score", v1: "\(r1.totalScore)", v2: "\(r2.totalScore)", better: r1.totalScore < r2.totalScore ? 1 : r1.totalScore > r2.totalScore ? 2 : 0)
            compRow("Putts", v1: "\(r1.totalPutts)", v2: "\(r2.totalPutts)", better: r1.totalPutts < r2.totalPutts ? 1 : r1.totalPutts > r2.totalPutts ? 2 : 0)
            compRow("FW%", v1: String(format: "%.0f%%", r1.fairwayPercentage), v2: String(format: "%.0f%%", r2.fairwayPercentage), better: r1.fairwayPercentage > r2.fairwayPercentage ? 1 : 2)
            compRow("GIR%", v1: String(format: "%.0f%%", r1.girPercentage), v2: String(format: "%.0f%%", r2.girPercentage), better: r1.girPercentage > r2.girPercentage ? 1 : 2)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func compRow(_ label: String, v1: String, v2: String, better: Int) -> some View {
        HStack {
            Text(v1)
                .font(.subheadline.bold())
                .foregroundStyle(better == 1 ? .green : .primary)
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60)
            Text(v2)
                .font(.subheadline.bold())
                .foregroundStyle(better == 2 ? .green : .primary)
                .frame(maxWidth: .infinity)
        }
    }
}
