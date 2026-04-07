// MARK: - Round History
// Searchable list of all rounds, filterable by course/date

import SwiftUI
import SwiftData

struct RoundHistoryView: View {
    @Query(sort: \GolfRound.date, order: .reverse) private var rounds: [GolfRound]
    @State private var searchText = ""
    @State private var filterCourse: GolfCourse?

    private var filteredRounds: [GolfRound] {
        var result = rounds.filter { $0.isCompleted }
        if !searchText.isEmpty {
            result = result.filter {
                $0.course?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        if let course = filterCourse {
            result = result.filter { $0.course?.id == course.id }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredRounds.isEmpty {
                    ContentUnavailableView(
                        "No Rounds Yet",
                        systemImage: "flag.fill",
                        description: Text("Complete a round to see it here")
                    )
                } else {
                    List {
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
}

// MARK: - Round History Row
struct RoundHistoryRow: View {
    let round: GolfRound

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.course?.name ?? "Unknown")
                    .font(.headline)
                Text(round.date.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(round.totalScore)")
                    .font(.title3.bold())
                Text(round.scoreToParString)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.scoreColor(for: round.scoreToPar))
            }
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Label("\(round.totalPutts)", systemImage: "circle.fill")
                    Label(String(format: "%.0f%%", round.fairwayPercentage), systemImage: "leaf.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
