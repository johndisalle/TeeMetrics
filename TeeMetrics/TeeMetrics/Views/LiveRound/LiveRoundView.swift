// MARK: - Live Round Logger
// Horizontal pager per hole, big tappable score/putts/penalties,
// fairway/GIR/sand save toggles, shot-by-shot tracking, voice notes, auto-save

import SwiftUI
import SwiftData

struct LiveRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var round: GolfRound

    @State private var currentHole = 1
    @State private var showShotTracker = false
    @State private var showFinishAlert = false
    @State private var showCelebration = false
    @State private var isPersonalBest = false
    @State private var previousBest: Int?

    private var sortedEntries: [HoleEntry] {
        round.holeEntries.sorted { $0.holeNumber < $1.holeNumber }
    }

    private var currentEntry: HoleEntry? {
        sortedEntries.first { $0.holeNumber == currentHole }
    }

    /// True when the round's course has at least one hole with green pins
    /// placed. Used to decide whether to start high-accuracy GPS tracking
    /// for this round — no pins anywhere means nothing to measure
    /// distance to, so we keep the battery asleep.
    private var anyHoleHasPins: Bool {
        round.course?.holes.contains { $0.hasGreenPins } ?? false
    }

    private var runningTotal: Int {
        sortedEntries.filter { $0.holeNumber <= currentHole && $0.score > 0 }
            .reduce(0) { $0 + $1.score }
    }

    private var runningToPar: Int {
        sortedEntries.filter { $0.holeNumber <= currentHole && $0.score > 0 }
            .reduce(0) { $0 + $1.scoreToPar }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Running Score Header
            scoreHeader

            // MARK: - Hole Pager
            TabView(selection: $currentHole) {
                ForEach(sortedEntries) { entry in
                    HoleLoggerView(entry: entry, onShowShotTracker: {
                        showShotTracker = true
                    })
                    .tag(entry.holeNumber)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // MARK: - Hole Navigation
            holeNavigator
        }
        .navigationTitle("Hole \(currentHole)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") { showFinishAlert = true }
            }
        }
        .alert("Finish Round?", isPresented: $showFinishAlert) {
            Button("Finish", role: .destructive) { finishRound() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Score: \(runningTotal) (\(runningToPar.scoreToParString))")
        }
        .sheet(isPresented: $showShotTracker) {
            if let entry = currentEntry {
                ShotTrackerView(holeEntry: entry)
            }
        }
        .fullScreenCover(isPresented: $showCelebration) {
            RoundCelebrationView(
                round: round,
                isPersonalBest: isPersonalBest,
                previousBest: previousBest,
                onDismiss: { dismiss() }
            )
        }
        .onAppear {
            currentHole = round.currentHole
            // Start high-accuracy GPS tracking only if there's something
            // to measure — saves battery on rounds at courses with no pins.
            if anyHoleHasPins {
                RoundLocationManager.shared.startTracking()
            }
        }
        .onDisappear {
            // Guarantees the GPS stream is off when the user leaves the
            // round view — handles backgrounding, navigating away, or any
            // path that doesn't go through finishRound().
            RoundLocationManager.shared.stopTracking()
        }
        .onChange(of: currentHole) { _, newVal in
            round.currentHole = newVal
            Haptics.selection()
            WidgetDataWriter.updateActiveRound(
                hole: newVal,
                courseName: round.course?.name ?? "",
                runningScore: runningTotal
            )
        }
    }

    // MARK: - Score Header
    private var scoreHeader: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("TOTAL")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text("\(runningTotal)")
                    .font(.title.bold())
            }
            Divider().frame(height: 40)
            VStack(spacing: 2) {
                Text("TO PAR")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(runningToPar.scoreToParString)
                    .font(.title.bold())
                    .foregroundStyle(Theme.scoreColor(for: runningToPar))
            }
            Divider().frame(height: 40)
            VStack(spacing: 2) {
                Text("PUTTS")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                let totalPutts = sortedEntries.reduce(0) { $0 + $1.putts }
                Text("\(totalPutts)")
                    .font(.title.bold())
            }
            Divider().frame(height: 40)
            VStack(spacing: 2) {
                Text("THRU")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                let completed = sortedEntries.filter { $0.score > 0 }.count
                Text("\(completed)")
                    .font(.title.bold())
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
    }

    // MARK: - Hole Navigator
    private var holeNavigator: some View {
        HStack {
            Button {
                withAnimation { currentHole = max(1, currentHole - 1) }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
            }
            .disabled(currentHole == 1)

            Spacer()

            // Hole dots
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...18, id: \.self) { hole in
                        Button {
                            withAnimation { currentHole = hole }
                        } label: {
                            let entry = sortedEntries.first { $0.holeNumber == hole }
                            let scored = entry?.score ?? 0 > 0
                            Text("\(hole)")
                                .font(.caption2.bold())
                                .frame(width: 28, height: 28)
                                .background(
                                    hole == currentHole ? Theme.primary :
                                    scored ? Theme.primary.opacity(0.3) :
                                    Color.gray.opacity(0.2)
                                )
                                .foregroundStyle(hole == currentHole ? .white : .primary)
                                .clipShape(Circle())
                        }
                    }
                }
            }

            Spacer()

            Button {
                withAnimation { currentHole = min(18, currentHole + 1) }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title)
            }
            .disabled(currentHole == 18)
        }
        .padding()
        .background(Theme.secondaryBackground)
    }

    private func finishRound() {
        // Release GPS immediately — before any SwiftData / CloudKit work
        // so the radio powers down as fast as possible.
        RoundLocationManager.shared.stopTracking()

        round.recalculateTotals()
        round.isCompleted = true

        // Check personal best BEFORE saving
        let descriptor = FetchDescriptor<GolfRound>(predicate: #Predicate { $0.isCompleted == true })
        if let allRounds = try? modelContext.fetch(descriptor) {
            let otherScores = allRounds.filter { $0.id != round.id }.compactMap { $0.totalScore > 0 ? $0.totalScore : nil }
            previousBest = otherScores.min()
            isPersonalBest = previousBest.map { round.totalScore < $0 } ?? (allRounds.count <= 1)

            // Achievements
            let previouslyEarned = Set(UserDefaults.standard.stringArray(forKey: "earnedAchievements") ?? [])
            let newAchievements = AchievementsManager.newlyEarned(rounds: allRounds, previouslyEarned: previouslyEarned)
            for achievement in newAchievements {
                NotificationManager.notifyAchievement(achievement)
            }
            let allEarned = AchievementsManager.evaluateAchievements(rounds: allRounds).map(\.rawValue)
            UserDefaults.standard.set(allEarned, forKey: "earnedAchievements")
        }

        // Update widget + Siri data
        WidgetDataWriter.updateLastRound(round: round)
        WidgetDataWriter.clearActiveRound()
        GatingManager.shared.updateRoundCount(from: modelContext)

        // Cache handicap for Siri
        if let allCompleted = try? modelContext.fetch(FetchDescriptor<GolfRound>(predicate: #Predicate { $0.isCompleted == true })) {
            let hcp = StatsCalculator.handicapIndex(rounds: allCompleted)
            UserDefaults.standard.set(hcp, forKey: "cachedHandicap")
            WidgetDataWriter.updateStats(handicap: hcp, roundCount: allCompleted.count)
        }
        NotificationManager.scheduleInactivityReminder(lastRoundDate: round.date)

        // Show celebration instead of dismiss
        showCelebration = true
    }
}
