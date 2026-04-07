// MARK: - Apple Watch App Entry
// Minimal Watch app for quick score entry during rounds

import SwiftUI

@main
struct TeeMetricsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRoundView()
        }
    }
}
