// MARK: - Stats Calculator
// Pure functions for handicap, strokes gained, and aggregate stats
// All calculations are rule-based and on-device

import Foundation

enum StatsCalculator {

    // MARK: - Handicap Index (simplified USGA formula)
    // Uses best 8 of last 20 score differentials
    // Differential = (Score - Course Rating) * 113 / Slope Rating
    static func handicapIndex(rounds: [GolfRound]) -> Double {
        let completedRounds = rounds
            .filter { $0.isCompleted && $0.course != nil }
            .sorted { $0.date > $1.date }

        let recentRounds = Array(completedRounds.prefix(20))
        guard recentRounds.count >= 3 else { return 0 }

        let differentials = recentRounds.compactMap { round -> Double? in
            guard let course = round.course else { return nil }
            return (Double(round.totalScore) - course.courseRating) * 113.0 / course.slopeRating
        }

        let count = differentials.count
        let bestCount: Int
        switch count {
        case 3...4: bestCount = 1
        case 5...6: bestCount = 2
        case 7...8: bestCount = 3
        case 9...10: bestCount = 4
        case 11...12: bestCount = 5
        case 13...14: bestCount = 6
        case 15...16: bestCount = 7
        case 17...20: bestCount = 8
        default: bestCount = 1
        }

        let sorted = differentials.sorted()
        let best = Array(sorted.prefix(bestCount))
        let avg = best.reduce(0, +) / Double(best.count)
        return (avg * 0.96 * 10).rounded() / 10 // Truncate to 1 decimal
    }

    // MARK: - Strokes Gained (simplified baseline model)
    // Baseline putts/strokes from distance to hole, using PGA averages
    static func strokesGainedPutting(round: GolfRound) -> Double {
        // Simplified: compare actual putts to expected putts (1.8 per hole baseline)
        let expectedPuttsPerHole = 1.8
        let totalExpected = expectedPuttsPerHole * Double(round.holeEntries.count)
        let actualPutts = Double(round.totalPutts)
        return totalExpected - actualPutts // Positive = better than baseline
    }

    static func strokesGainedApproach(round: GolfRound) -> Double {
        // Simplified: GIR-based proxy
        // Average PGA GIR is ~65%, amateur baseline ~40%
        let girCount = round.holeEntries.filter { $0.greenInRegulation }.count
        let girRate = Double(girCount) / max(1, Double(round.holeEntries.count))
        let baselineGIR = 0.40
        return (girRate - baselineGIR) * Double(round.holeEntries.count) * 0.5
    }

    static func strokesGainedOffTee(round: GolfRound) -> Double {
        // Simplified: fairway hit rate proxy for par 4+5 holes
        let eligible = round.holeEntries.filter { $0.par >= 4 }
        guard !eligible.isEmpty else { return 0 }
        let fwHit = eligible.filter { $0.fairwayHit == true }.count
        let fwRate = Double(fwHit) / Double(eligible.count)
        let baseline = 0.50 // amateur baseline ~50%
        return (fwRate - baseline) * Double(eligible.count) * 0.3
    }

    static func strokesGainedShortGame(round: GolfRound) -> Double {
        // Simplified: up-and-down / scramble rate proxy
        let missedGIR = round.holeEntries.filter { !$0.greenInRegulation }
        guard !missedGIR.isEmpty else { return 0 }
        let parOrBetter = missedGIR.filter { $0.scoreToPar <= 0 }.count
        let scrambleRate = Double(parOrBetter) / Double(missedGIR.count)
        let baseline = 0.25
        return (scrambleRate - baseline) * Double(missedGIR.count) * 0.4
    }

    // MARK: - Aggregate Stats across rounds
    static func averageScore(rounds: [GolfRound]) -> Double {
        let completed = rounds.filter { $0.isCompleted }
        guard !completed.isEmpty else { return 0 }
        return Double(completed.reduce(0) { $0 + $1.totalScore }) / Double(completed.count)
    }

    static func averagePutts(rounds: [GolfRound]) -> Double {
        let completed = rounds.filter { $0.isCompleted }
        guard !completed.isEmpty else { return 0 }
        return Double(completed.reduce(0) { $0 + $1.totalPutts }) / Double(completed.count)
    }

    static func averageFairways(rounds: [GolfRound]) -> Double {
        let completed = rounds.filter { $0.isCompleted }
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0.0) { $0 + $1.fairwayPercentage } / Double(completed.count)
    }

    static func averageGIR(rounds: [GolfRound]) -> Double {
        let completed = rounds.filter { $0.isCompleted }
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0.0) { $0 + $1.girPercentage } / Double(completed.count)
    }

    // MARK: - Best / Worst Round
    static func bestScore(rounds: [GolfRound]) -> Int? {
        rounds.filter { $0.isCompleted }.map(\.totalScore).min()
    }

    // MARK: - Trend (last 5 vs previous 5)
    static func scoreTrend(rounds: [GolfRound]) -> Double {
        let completed = rounds.filter { $0.isCompleted }.sorted { $0.date > $1.date }
        guard completed.count >= 10 else { return 0 }
        let recent5 = completed.prefix(5).reduce(0) { $0 + $1.totalScore }
        let prev5 = completed.dropFirst(5).prefix(5).reduce(0) { $0 + $1.totalScore }
        return Double(prev5 - recent5) / 5.0 // Positive = improving
    }
}
