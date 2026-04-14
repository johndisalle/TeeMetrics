// MARK: - Round History
// Searchable list of all rounds with score, stats, and course info

import SwiftUI
import SwiftData

struct RoundHistoryView: View {
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @State private var searchText = ""

    private var completedRounds: [GolfRound] {
        rounds.filter { $0.isCompleted }
    }

    private var filteredRounds: [GolfRound] {
        if searchText.isEmpty { return completedRounds }
        return completedRounds.filter {
            $0.course?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if completedRounds.isEmpty {
                    ContentUnavailableView(
                        "No Rounds Yet",
                        systemImage: "flag.fill",
                        description: Text("Complete a round to see it here")
                    )
                } else {
                    List {
                        // Stats summary header
                        Section {
                            HStack(spacing: 16) {
                                miniHeader("Rounds", value: "\(completedRounds.count)")
                                miniHeader("Best", value: StatsCalculator.bestScore(rounds: completedRounds).map { "\($0)" } ?? "-")
                                miniHeader("Avg", value: String(format: "%.0f", StatsCalculator.averageScore(rounds: completedRounds)))
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        }

                        // Round list
                        ForEach(filteredRounds) { round in
                            NavigationLink {
                                RoundDetailView(round: round)
                            } label: {
                                RoundHistoryRow(round: round)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Rounds")
            .searchable(text: $searchText, prompt: "Search by course")
        }
    }

    private func miniHeader(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Round History Row
struct RoundHistoryRow: View {
    let round: GolfRound

    var body: some View {
        HStack(spacing: 12) {
            // Score badge
            ZStack {
                Circle()
                    .fill(Theme.scoreColor(for: round.scoreToPar).opacity(0.12))
                    .frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Text("\(round.totalScore)")
                        .font(.subheadline.bold())
                    Text(round.scoreToParString)
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.scoreColor(for: round.scoreToPar))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(round.course?.name ?? "Unknown")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    // Subtle indicator for rounds that have GPS-captured
                    // shots. Lets the user spot which rounds have
                    // shot-by-shot detail before tapping in.
                    if !round.shots.isEmpty {
                        Image(systemName: "scope")
                            .font(.caption2)
                            .foregroundStyle(Theme.primary)
                            .accessibilityLabel("Has shot tracking data")
                    }
                }
                HStack(spacing: 6) {
                    Text(round.date.shortFormatted)
                    Text("\u{2022}")
                    Text("\(round.totalPutts)P")
                    Text("\u{2022}")
                    Text(String(format: "%.0f%%FW", round.fairwayPercentage))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
