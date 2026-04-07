// MARK: - Widget Data Writer
// Writes round data to shared App Group UserDefaults for the widget to read

import Foundation
import WidgetKit

enum WidgetDataKeys {
    static let suiteName = "group.com.teemetrics.shared"
    static let lastCourseName = "widget_lastCourseName"
    static let lastScore = "widget_lastScore"
    static let lastScoreToPar = "widget_lastScoreToPar"
    static let lastPutts = "widget_lastPutts"
    static let lastFairway = "widget_lastFairway"
    static let lastDate = "widget_lastDate"
    static let activeHole = "widget_activeHole"
    static let activeCourseName = "widget_activeCourseName"
    static let activeRunningScore = "widget_activeRunningScore"
    static let isRoundActive = "widget_isRoundActive"
    static let handicap = "widget_handicap"
    static let roundCount = "widget_roundCount"
}

enum WidgetDataWriter {
    static func updateLastRound(round: GolfRound) {
        guard let defaults = UserDefaults(suiteName: WidgetDataKeys.suiteName) else { return }
        defaults.set(round.course?.name ?? "Unknown", forKey: WidgetDataKeys.lastCourseName)
        defaults.set(round.totalScore, forKey: WidgetDataKeys.lastScore)
        defaults.set(round.scoreToParString, forKey: WidgetDataKeys.lastScoreToPar)
        defaults.set(round.totalPutts, forKey: WidgetDataKeys.lastPutts)
        defaults.set(String(format: "%.0f%%", round.fairwayPercentage), forKey: WidgetDataKeys.lastFairway)
        defaults.set(round.date.shortFormatted, forKey: WidgetDataKeys.lastDate)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateActiveRound(hole: Int, courseName: String, runningScore: Int) {
        guard let defaults = UserDefaults(suiteName: WidgetDataKeys.suiteName) else { return }
        defaults.set(true, forKey: WidgetDataKeys.isRoundActive)
        defaults.set(hole, forKey: WidgetDataKeys.activeHole)
        defaults.set(courseName, forKey: WidgetDataKeys.activeCourseName)
        defaults.set(runningScore, forKey: WidgetDataKeys.activeRunningScore)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearActiveRound() {
        guard let defaults = UserDefaults(suiteName: WidgetDataKeys.suiteName) else { return }
        defaults.set(false, forKey: WidgetDataKeys.isRoundActive)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateStats(handicap: Double, roundCount: Int) {
        guard let defaults = UserDefaults(suiteName: WidgetDataKeys.suiteName) else { return }
        defaults.set(handicap, forKey: WidgetDataKeys.handicap)
        defaults.set(roundCount, forKey: WidgetDataKeys.roundCount)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
