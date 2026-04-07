// MARK: - Home Dashboard
// Quick-start round, last 5 rounds, key stats widgets, hot streaks, pro banner

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.date, order: .reverse) private var allRounds: [GolfRound]
    @Query private var golfers: [Golfer]
    @State private var showNewRound = false

    private var golfer: Golfer? { golfers.first }

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
                    // MARK: - Welcome Header
                    if let golfer {
                        welcomeHeader(golfer: golfer)
                    }

                    // MARK: - Quick Start / Resume
                    quickStartSection

                    if completedRounds.isEmpty {
                        // MARK: - Empty State
                        emptyState
                    } else {
                        // MARK: - Key Stats
                        statsGrid

                        // MARK: - Recent Rounds
                        recentRoundsSection

                        // MARK: - Hot Streaks
                        if completedRounds.count >= 3 {
                            hotStreaksSection
                        }
                    }

                    // MARK: - Pro Banner
                    if !SubscriptionManager.shared.isProUser {
                        proBanner
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("TeeMetrics")
            .sheet(isPresented: $showNewRound) {
                NewRoundView()
            }
        }
    }

    // MARK: - Welcome Header
    private func welcomeHeader(golfer: Golfer) -> some View {
        HStack(spacing: 14) {
            Image(systemName: golfer.avatarSystemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.golfGradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(golfer.name)
                    .font(.title3.bold())
            }
            Spacer()

            if !completedRounds.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("HCP")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", StatsCalculator.handicapIndex(rounds: completedRounds)))
                        .font(.title3.bold())
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.primary.opacity(0.4))

            VStack(spacing: 6) {
                Text("Ready to Hit the Course?")
                    .font(.title3.bold())
                Text("Start your first round or load sample data\nfrom Settings to explore the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                guideRow(step: "1", text: "Add a course in the round setup")
                guideRow(step: "2", text: "Score each hole as you play")
                guideRow(step: "3", text: "Review stats and track your progress")
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }

    private func guideRow(step: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Theme.primary)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
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
                        VStack(alignment: .leading, spacing: 2) {
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
                    .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)
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
                    .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Avg Score",
                    value: String(format: "%.1f", StatsCalculator.averageScore(rounds: completedRounds)),
                    icon: "number.circle.fill",
                    color: Theme.primary
                )
                StatCard(
                    title: "Fairways",
                    value: String(format: "%.0f%%", StatsCalculator.averageFairways(rounds: completedRounds)),
                    icon: "leaf.fill",
                    color: .green
                )
                StatCard(
                    title: "GIR",
                    value: String(format: "%.0f%%", StatsCalculator.averageGIR(rounds: completedRounds)),
                    icon: "target",
                    color: .blue
                )
                StatCard(
                    title: "Avg Putts",
                    value: String(format: "%.1f", StatsCalculator.averagePutts(rounds: completedRounds)),
                    icon: "circle.fill",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Recent Rounds
    private var recentRoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Rounds")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    RoundHistoryView()
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(Theme.primary)
                }
            }

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
            Text("Highlights")
                .font(.headline)

            let trend = StatsCalculator.scoreTrend(rounds: completedRounds)
            if trend > 0 {
                highlightCard(
                    icon: "flame.fill",
                    color: .orange,
                    title: "On Fire",
                    subtitle: "Scores improving by \(String(format: "%.1f", trend)) strokes on average"
                )
            }

            if let best = StatsCalculator.bestScore(rounds: completedRounds) {
                highlightCard(
                    icon: "trophy.fill",
                    color: Theme.accent,
                    title: "Personal Best",
                    subtitle: "Your lowest round: \(best)"
                )
            }

            if completedRounds.count >= 5 {
                highlightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    color: Theme.primary,
                    title: "\(completedRounds.count) Rounds Logged",
                    subtitle: "Keep tracking to unlock deeper insights"
                )
            }
        }
    }

    private func highlightCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Pro Banner
    private var proBanner: some View {
        NavigationLink {
            SubscriptionView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Pro")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Strokes gained, advanced charts & more")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text("$29.99/yr")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding()
            .background(Theme.golfGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.primary.opacity(0.25), radius: 8, y: 4)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = Theme.primary

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Round Row
struct RoundRowView: View {
    let round: GolfRound

    var body: some View {
        HStack(spacing: 14) {
            // Score circle
            ZStack {
                Circle()
                    .fill(Theme.scoreColor(for: round.scoreToPar).opacity(0.12))
                    .frame(width: 48, height: 48)
                VStack(spacing: 0) {
                    Text("\(round.totalScore)")
                        .font(.headline.bold())
                    Text(round.scoreToParString)
                        .font(.caption2.bold())
                        .foregroundStyle(Theme.scoreColor(for: round.scoreToPar))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(round.course?.name ?? "Unknown Course")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(round.date.relativeFormatted)
                    Text("\u{2022}")
                    Text("\(round.totalPutts) putts")
                    Text("\u{2022}")
                    Text(String(format: "%.0f%% FW", round.fairwayPercentage))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
