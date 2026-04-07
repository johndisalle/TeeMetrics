// MARK: - Stats & Analytics Dashboard
// Swift Charts: score trend, fairway %, GIR %, putts, club dispersion,
// strokes gained breakdown, handicap progress, insight cards

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \GolfRound.date, order: .reverse) private var allRounds: [GolfRound]

    private var completedRounds: [GolfRound] {
        allRounds.filter { $0.isCompleted }
    }

    private var chronologicalRounds: [GolfRound] {
        completedRounds.reversed()
    }

    var body: some View {
        NavigationStack {
            Group {
                if completedRounds.isEmpty {
                    ContentUnavailableView(
                        "No Stats Yet",
                        systemImage: "chart.bar.fill",
                        description: Text("Complete a round to see analytics")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            overviewCards
                                .slideIn(delay: 0)
                            scoreTrendChart
                                .slideIn(delay: 0.05)
                            puttsTrendChart
                                .slideIn(delay: 0.1)
                            fairwayGIRChart
                                .slideIn(delay: 0.15)

                            strokesGainedChart
                                .proGated(.strokesGained)
                                .slideIn(delay: 0.2)
                            handicapChart
                                .proGated(.advancedStats)
                                .slideIn(delay: 0.25)

                            insightsSection
                                .slideIn(delay: 0.3)

                            // MARK: - Feature Links
                            statsQuickLinks
                                .slideIn(delay: 0.35)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Overview Cards
    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            miniStat("Rounds", value: "\(completedRounds.count)")
            miniStat("Best", value: StatsCalculator.bestScore(rounds: completedRounds).map { "\($0)" } ?? "-")
            miniStat("Handicap", value: String(format: "%.1f", StatsCalculator.handicapIndex(rounds: completedRounds)))
        }
    }

    private func miniStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Score Trend Chart
    private var scoreTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Trend")
                .font(.headline)

            Chart {
                ForEach(Array(chronologicalRounds.suffix(20).enumerated()), id: \.offset) { index, round in
                    LineMark(
                        x: .value("Round", index + 1),
                        y: .value("Score", round.totalScore)
                    )
                    .foregroundStyle(Theme.primary)

                    PointMark(
                        x: .value("Round", index + 1),
                        y: .value("Score", round.totalScore)
                    )
                    .foregroundStyle(Theme.primary)

                    if let course = round.course {
                        RuleMark(y: .value("Par", course.totalPar))
                            .foregroundStyle(.gray.opacity(0.3))
                            .lineStyle(StrokeStyle(dash: [5, 5]))
                    }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: .automatic(includesZero: false))
        }
        .cardStyle()
    }

    // MARK: - Putts Trend
    private var puttsTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Putts Per Round")
                .font(.headline)

            Chart {
                ForEach(Array(chronologicalRounds.suffix(20).enumerated()), id: \.offset) { index, round in
                    BarMark(
                        x: .value("Round", index + 1),
                        y: .value("Putts", round.totalPutts)
                    )
                    .foregroundStyle(Theme.primary.gradient)
                }
            }
            .frame(height: 160)
        }
        .cardStyle()
    }

    // MARK: - Fairway & GIR Chart
    private var fairwayGIRChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fairways & GIR")
                .font(.headline)

            Chart {
                ForEach(Array(chronologicalRounds.suffix(20).enumerated()), id: \.offset) { index, round in
                    LineMark(
                        x: .value("Round", index + 1),
                        y: .value("FW%", round.fairwayPercentage),
                        series: .value("Stat", "Fairway")
                    )
                    .foregroundStyle(.green)

                    LineMark(
                        x: .value("Round", index + 1),
                        y: .value("GIR%", round.girPercentage),
                        series: .value("Stat", "GIR")
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 180)
            .chartForegroundStyleScale(["Fairway": .green, "GIR": .blue])
        }
        .cardStyle()
    }

    // MARK: - Strokes Gained Chart (Pro)
    private var strokesGainedChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strokes Gained (Last 10)")
                .font(.headline)

            let recent = Array(completedRounds.prefix(10))
            let avgOffTee = recent.map { StatsCalculator.strokesGainedOffTee(round: $0) }.reduce(0, +) / max(1, Double(recent.count))
            let avgApproach = recent.map { StatsCalculator.strokesGainedApproach(round: $0) }.reduce(0, +) / max(1, Double(recent.count))
            let avgShort = recent.map { StatsCalculator.strokesGainedShortGame(round: $0) }.reduce(0, +) / max(1, Double(recent.count))
            let avgPutt = recent.map { StatsCalculator.strokesGainedPutting(round: $0) }.reduce(0, +) / max(1, Double(recent.count))

            let data: [(String, Double)] = [
                ("Off Tee", avgOffTee),
                ("Approach", avgApproach),
                ("Short Game", avgShort),
                ("Putting", avgPutt),
            ]

            Chart(data, id: \.0) { item in
                BarMark(
                    x: .value("Category", item.0),
                    y: .value("SG", item.1)
                )
                .foregroundStyle(item.1 >= 0 ? Color.green : Color.red)
            }
            .frame(height: 180)
        }
        .cardStyle()
    }

    // MARK: - Handicap Chart (Pro)
    private var handicapChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Handicap Progress")
                .font(.headline)

            // Calculate rolling handicap at each point
            let rounds = chronologicalRounds
            Chart {
                ForEach(Array(rounds.enumerated()), id: \.offset) { index, _ in
                    if index >= 2 {
                        let subset = Array(rounds.prefix(index + 1))
                        let hcp = StatsCalculator.handicapIndex(rounds: subset)
                        LineMark(
                            x: .value("Round", index + 1),
                            y: .value("HCP", hcp)
                        )
                        .foregroundStyle(Theme.accent)
                    }
                }
            }
            .frame(height: 160)
            .chartYScale(domain: .automatic(includesZero: false))
        }
        .cardStyle()
    }

    // MARK: - Insights (rule-based)
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)

            let avgPutts = StatsCalculator.averagePutts(rounds: completedRounds)
            let avgGIR = StatsCalculator.averageGIR(rounds: completedRounds)
            let avgFW = StatsCalculator.averageFairways(rounds: completedRounds)

            if avgPutts > 2.0 {
                insightCard(
                    icon: "circle.fill",
                    color: .orange,
                    text: "Putting is your biggest opportunity. Averaging \(String(format: "%.1f", avgPutts)) putts/hole — focus on lag putting."
                )
            }
            if avgGIR < 35 {
                insightCard(
                    icon: "target",
                    color: .blue,
                    text: "GIR at \(String(format: "%.0f%%", avgGIR)). Dial in approach distances to save strokes."
                )
            }
            if avgFW < 50 {
                insightCard(
                    icon: "leaf.fill",
                    color: .green,
                    text: "Fairways at \(String(format: "%.0f%%", avgFW)). Consider a more consistent tee shot strategy."
                )
            }
            if completedRounds.count >= 10 {
                let trend = StatsCalculator.scoreTrend(rounds: completedRounds)
                if trend > 0 {
                    insightCard(icon: "arrow.down.right", color: .green, text: "Great trend! Scores dropping by \(String(format: "%.1f", trend)) on average.")
                }
            }
        }
    }

    private func insightCard(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
        .cardStyle()
    }

    // MARK: - Stats Quick Links
    private var statsQuickLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore")
                .font(.headline)

            NavigationLink {
                RoundComparisonView()
            } label: {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(Theme.primary)
                    Text("Compare Rounds")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)

            NavigationLink {
                AchievementsView()
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Achievements")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoalsView()
            } label: {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.blue)
                    Text("Goals")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }
}

