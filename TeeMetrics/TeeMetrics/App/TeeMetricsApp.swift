// MARK: - TeeMetrics App Entry Point
// Main app configuration with SwiftData container and tab navigation

import SwiftUI
import SwiftData

@main
struct TeeMetricsApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedAppearance") private var selectedAppearance = "system"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Golfer.self,
            GolfCourse.self,
            HoleInfo.self,
            CourseTee.self,      // Phase 2: multi-tee scorecards
            TeeHole.self,        // Phase 2: per-tee hole data
            HazardPin.self,      // Phase 2 GPS: bunker + water hazard pins
            GolfRound.self,
            HoleEntry.self,
            ShotEntry.self,
            Club.self,
            Bag.self,
            Goal.self,
            PracticeSession.self,
            PracticeShot.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                        .onAppear {
                            NotificationManager.requestPermission()
                            NotificationManager.scheduleWeeklySummary()
                            CourseDetectionManager.shared.requestLocation()
                            // Activate WatchConnectivity so round-start
                            // payloads can reach the paired Apple Watch.
                            WatchSyncManager.shared.activate()
                        }
                } else {
                    OnboardingView()
                }
            }
            .preferredColorScheme(colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
