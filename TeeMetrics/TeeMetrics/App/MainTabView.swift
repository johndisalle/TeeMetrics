// MARK: - Main Tab View
// Root navigation with 5 tabs: Dashboard, Rounds, Stats, Bag, Settings.
//
// SF Symbol naming convention: pass the OUTLINE name to `systemImage:`.
// iOS 14+ automatically swaps in the `.fill` variant when the tab is the
// active selection, which gives us free outline-when-unselected /
// filled-when-selected behavior without any manual state tracking.

import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    init() {
        // Configure the global UITabBar appearance so dark mode gets a
        // translucent material and light mode gets the off-white surface
        // with a subtle hairline. Set once on init — the `.tint()` view
        // modifier handles selected-icon color.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Light-mode override: warm off-white surface (Theme.surface).
        // Dark-mode keeps the system blur material so contrast over
        // photos / map views stays clean.
        let lightSurface = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.clear // let the default blur show through
                : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        appearance.backgroundColor = lightSurface

        // Subtle top hairline in light mode, removed in dark.
        let hairline = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.clear
                : UIColor.black.withAlphaComponent(0.08)
        }
        appearance.shadowColor = hairline

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            CoursesView()
                .tabItem { Label("Courses", systemImage: "flag") }
                .tag(1)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(2)
            BagManagerView()
                .tabItem { Label("Bag", systemImage: "bag") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(Theme.primary)
        .onAppear {
            GatingManager.shared.updateRoundCount(from: modelContext)
        }
    }
}
