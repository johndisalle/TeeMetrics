// MARK: - Main Tab View
// Root navigation with 5 tabs: Dashboard, Rounds, Stats, Bag, Settings

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            RoundHistoryView()
                .tabItem { Label("Rounds", systemImage: "list.bullet.clipboard.fill") }
                .tag(1)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)
            BagManagerView()
                .tabItem { Label("Bag", systemImage: "bag.fill") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Theme.primary)
    }
}
