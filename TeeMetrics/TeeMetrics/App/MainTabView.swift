// MARK: - Main Tab View
// Root navigation with 5 tabs: Dashboard, Rounds, Stats, Bag, Settings

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView()
            }
            Tab("Rounds", systemImage: "list.bullet.clipboard.fill", value: 1) {
                RoundHistoryView()
            }
            Tab("Stats", systemImage: "chart.bar.fill", value: 2) {
                StatsView()
            }
            Tab("Bag", systemImage: "bag.fill", value: 3) {
                BagManagerView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                SettingsView()
            }
        }
        .tint(Theme.primary)
    }
}
