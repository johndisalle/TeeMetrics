// MARK: - Achievements Manager
// Tracks milestones: first birdie, rounds played, personal bests, streaks

import Foundation
import SwiftData

enum Achievement: String, CaseIterable, Identifiable {
    // Round milestones
    case firstRound = "First Round"
    case fiveRounds = "Getting Serious"
    case tenRounds = "Regular"
    case twentyFiveRounds = "Dedicated"
    case fiftyRounds = "Committed"
    case hundredRounds = "Centurion"

    // Score milestones
    case firstBirdie = "First Birdie"
    case firstEagle = "Eagle Eye"
    case breakHundred = "Sub-100 Club"
    case breakNinety = "Sub-90 Club"
    case breakEighty = "Single Digits Incoming"
    case breakSeventy = "Scratch Territory"

    // Stat milestones
    case tenGIR = "Green Machine"
    case fiftyPercentFairways = "Fairway Finder"
    case underThirtyPutts = "Putting Wizard"

    // Streaks
    case threeRoundStreak = "Three-Peat"
    case improvingTrend = "On the Rise"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .firstRound: return "Complete your first round"
        case .fiveRounds: return "Complete 5 rounds"
        case .tenRounds: return "Complete 10 rounds"
        case .twentyFiveRounds: return "Complete 25 rounds"
        case .fiftyRounds: return "Complete 50 rounds"
        case .hundredRounds: return "Complete 100 rounds"
        case .firstBirdie: return "Score your first birdie"
        case .firstEagle: return "Score your first eagle or better"
        case .breakHundred: return "Shoot under 100"
        case .breakNinety: return "Shoot under 90"
        case .breakEighty: return "Shoot under 80"
        case .breakSeventy: return "Shoot under 70"
        case .tenGIR: return "Hit 10+ greens in regulation in a round"
        case .fiftyPercentFairways: return "Hit 50%+ fairways in a round"
        case .underThirtyPutts: return "Finish a round with under 30 putts"
        case .threeRoundStreak: return "Play 3 rounds in one week"
        case .improvingTrend: return "Lower your average over 5 rounds"
        }
    }

    var icon: String {
        switch self {
        case .firstRound, .fiveRounds, .tenRounds, .twentyFiveRounds, .fiftyRounds, .hundredRounds:
            return "flag.checkered"
        case .firstBirdie: return "bird.fill"
        case .firstEagle: return "star.fill"
        case .breakHundred, .breakNinety, .breakEighty, .breakSeventy: return "trophy.fill"
        case .tenGIR: return "target"
        case .fiftyPercentFairways: return "leaf.fill"
        case .underThirtyPutts: return "circle.fill"
        case .threeRoundStreak: return "flame.fill"
        case .improvingTrend: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: String {
        switch self {
        case .hundredRounds, .breakSeventy, .firstEagle: return "gold"
        case .fiftyRounds, .breakEighty: return "silver"
        default: return "bronze"
        }
    }
}

@MainActor
enum AchievementsManager {

    // MARK: - Check all achievements for current state
    static func evaluateAchievements(rounds: [GolfRound]) -> [Achievement] {
        let completed = rounds.filter { $0.isCompleted }
        var earned: [Achievement] = []

        // Round count milestones
        let count = completed.count
        if count >= 1 { earned.append(.firstRound) }
        if count >= 5 { earned.append(.fiveRounds) }
        if count >= 10 { earned.append(.tenRounds) }
        if count >= 25 { earned.append(.twentyFiveRounds) }
        if count >= 50 { earned.append(.fiftyRounds) }
        if count >= 100 { earned.append(.hundredRounds) }

        // Score milestones
        let allEntries = completed.flatMap { $0.holeEntries }
        if allEntries.contains(where: { $0.scoreToPar <= -1 }) { earned.append(.firstBirdie) }
        if allEntries.contains(where: { $0.scoreToPar <= -2 }) { earned.append(.firstEagle) }

        let scores = completed.map(\.totalScore)
        if scores.contains(where: { $0 < 100 }) { earned.append(.breakHundred) }
        if scores.contains(where: { $0 < 90 }) { earned.append(.breakNinety) }
        if scores.contains(where: { $0 < 80 }) { earned.append(.breakEighty) }
        if scores.contains(where: { $0 < 70 }) { earned.append(.breakSeventy) }

        // Stat milestones
        if completed.contains(where: { round in
            round.holeEntries.filter { $0.greenInRegulation }.count >= 10
        }) { earned.append(.tenGIR) }

        if completed.contains(where: { $0.fairwayPercentage >= 50 }) {
            earned.append(.fiftyPercentFairways)
        }
        if completed.contains(where: { $0.totalPutts < 30 }) {
            earned.append(.underThirtyPutts)
        }

        // Streak: 3 rounds in 7 days
        if hasThreeRoundWeek(completed) { earned.append(.threeRoundStreak) }

        // Improving trend
        if StatsCalculator.scoreTrend(rounds: completed) > 0 {
            earned.append(.improvingTrend)
        }

        return earned
    }

    // MARK: - Newly earned (compare to previously seen)
    static func newlyEarned(rounds: [GolfRound], previouslyEarned: Set<String>) -> [Achievement] {
        let current = evaluateAchievements(rounds: rounds)
        return current.filter { !previouslyEarned.contains($0.rawValue) }
    }

    private static func hasThreeRoundWeek(_ rounds: [GolfRound]) -> Bool {
        let sorted = rounds.sorted { $0.date > $1.date }
        for i in 0..<max(0, sorted.count - 2) {
            let span = sorted[i].date.timeIntervalSince(sorted[i + 2].date)
            if span <= 7 * 24 * 3600 { return true }
        }
        return false
    }
}
