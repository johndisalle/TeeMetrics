// MARK: - Home Dashboard
// Quick-start round, last 5 rounds, key stats widgets, hot streaks, pro banner

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.date, order: .reverse) private var allRounds: [GolfRound]
    @Query private var golfers: [Golfer]
    @State private var showNewRound = false

    private var completedRounds: [GolfRound] {
        allRounds.filter { $0.isCompleted }
    }

    private var activeRound: GolfRound? {
        allRounds.first { !$0.isCompleted }
    }

    private var recentRounds: [GolfRound] {
        Array(completedRounds.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Quick Start / Resume
                    quickStartSection

                    // MARK: - Key Stats
                    if !completedRounds.isEmpty {
                        statsGrid
                    }

                    // MARK: - Recent Rounds
                    if !recentRounds.isEmpty {
                        recentRoundsSection
                    }

                    // MARK: - Hot Streaks
                    if completedRounds.count >= 3 {
                        hotStreaksSection
                    }

                    // MARK: - Pro Banner
                    if !SubscriptionManager.shared.isProUser {
                        proBanner
                    }
                }
                .padding()
            }
            .navigationTitle("TeeMetrics")
            .sheet(isPresented: $showNewRound) {
                NewRoundView()
            }
        }
    }

    // MARK: - Quick Start Button
    private var quickStartSection: some View {
        VStack(spacing: 12) {
            if let active = activeRound {
                NavigationLink {
                    LiveRoundView(round: active)
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Resume Round")
                                .font(.headline)
                            Text("Hole \(active.currentHole) \u{2022} \(active.course?.name ?? "Unknown")")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Theme.golfGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Button {
                    Haptics.medium()
                    showNewRound = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Start New Round")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Theme.golfGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Avg Score",
                value: String(format: "%.1f", StatsCalculator.averageScore(rounds: completedRounds)),
                icon: "number.circle.fill"
            )
            StatCard(
                title: "Fairways",
                value: String(format: "%.0f%%", StatsCalculator.averageFairways(rounds: completedRounds)),
                icon: "leaf.fill"
            )
            StatCard(
                title: "GIR",
                value: String(format: "%.0f%%", StatsCalculator.averageGIR(rounds: completedRounds)),
                icon: "target"
            )
            StatCard(
                title: "Avg Putts",
                value: String(format: "%.1f", StatsCalculator.averagePutts(rounds: completedRounds)),
                icon: "circle.fill"
            )
        }
    }

    // MARK: - Recent Rounds
    private var recentRoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rounds")
                .font(.headline)

            ForEach(recentRounds) { round in
                NavigationLink {
                    RoundDetailView(round: round)
                } label: {
                    RoundRowView(round: round)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hot Streaks
    private var hotStreaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hot Streaks")
                .font(.headline)

            let trend = StatsCalculator.scoreTrend(rounds: completedRounds)
            if trend > 0 {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Scores improving by \(String(format: "%.1f", trend)) strokes on average!")
                        .font(.subheadline)
                }
                .cardStyle()
            } else if let best = StatsCalculator.bestScore(rounds: completedRounds) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Personal best: \(best)")
                        .font(.subheadline)
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Pro Banner
    private var proBanner: some View {
        NavigationLink {
            SubscriptionView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Pro")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Advanced stats, strokes gained & more")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
            .padding()
            .background(Theme.primary.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.primary)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Round Row
struct RoundRowView: View {
    let round: GolfRound

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.course?.name ?? "Unknown Course")
                    .font(.subheadline.bold())
                Text(round.date.relativeFormatted)
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
        }
        .cardStyle()
    }
}
