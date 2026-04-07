// MARK: - Siri Shortcuts / App Intents
// "Hey Siri, start a round" + "Hey Siri, what's my handicap?"

import AppIntents
import SwiftData

// MARK: - Start Round Intent
struct StartRoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Golf Round"
    static var description: IntentDescription = "Open TeeMetrics and start a new round"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Opens the app — the UI handles round creation
        return .result()
    }
}

// MARK: - Check Handicap Intent
struct CheckHandicapIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Handicap"
    static var description: IntentDescription = "Get your current handicap index from TeeMetrics"

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let handicap = UserDefaults.standard.double(forKey: "cachedHandicap")
        if handicap > 0 {
            return .result(value: String(format: "Your handicap index is %.1f", handicap))
        }
        return .result(value: "Play a few rounds to calculate your handicap")
    }
}

// MARK: - Check Last Round Intent
struct CheckLastRoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Last Round"
    static var description: IntentDescription = "Get your most recent round score from TeeMetrics"

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: "group.com.teemetrics.shared")
        let score = defaults?.integer(forKey: "widget_lastScore") ?? 0
        let course = defaults?.string(forKey: "widget_lastCourseName") ?? "Unknown"
        let scoreToPar = defaults?.string(forKey: "widget_lastScoreToPar") ?? ""

        if score > 0 {
            return .result(value: "Your last round was \(score) (\(scoreToPar)) at \(course)")
        }
        return .result(value: "No rounds logged yet")
    }
}

// MARK: - App Shortcuts Provider
struct TeeMetricsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRoundIntent(),
            phrases: [
                "Start a round in \(.applicationName)",
                "Start a golf round with \(.applicationName)",
                "Open \(.applicationName) for golf",
                "Log a round in \(.applicationName)",
            ],
            shortTitle: "Start Round",
            systemImageName: "flag.fill"
        )
        AppShortcut(
            intent: CheckHandicapIntent(),
            phrases: [
                "What's my handicap in \(.applicationName)",
                "Check my handicap with \(.applicationName)",
                "My golf handicap from \(.applicationName)",
            ],
            shortTitle: "Check Handicap",
            systemImageName: "chart.line.downtrend.xyaxis"
        )
        AppShortcut(
            intent: CheckLastRoundIntent(),
            phrases: [
                "How did my last round go in \(.applicationName)",
                "Check my last round in \(.applicationName)",
                "My last golf score from \(.applicationName)",
            ],
            shortTitle: "Last Round",
            systemImageName: "number.circle.fill"
        )
    }
}
