// MARK: - TeeMetrics App Entry Point
// Main app configuration with SwiftData container and tab navigation

import SwiftUI
import SwiftData

@main
struct TeeMetricsApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Golfer.self,
            GolfCourse.self,
            HoleInfo.self,
            GolfRound.self,
            HoleEntry.self,
            ShotEntry.self,
            Club.self,
            Bag.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
