// MARK: - Theme
// App-wide color palette and styling constants

import SwiftUI

enum Theme {
    static let primary = Color(red: 0, green: 0.39, blue: 0) // #006400
    static let accent = Color(red: 1, green: 0.84, blue: 0)  // #FFD700
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let cardBackground = Color(.tertiarySystemBackground)

    // Score colors
    static let eagle = Color.yellow
    static let birdie = Color.red
    static let par = Color.green
    static let bogey = Color.blue
    static let doublePlus = Color.purple

    static func scoreColor(for scoreToPar: Int) -> Color {
        switch scoreToPar {
        case ...(-2): return eagle
        case -1: return birdie
        case 0: return par
        case 1: return bogey
        default: return doublePlus
        }
    }

    // Gradient for headers / onboarding
    static let golfGradient = LinearGradient(
        colors: [primary, Color(red: 0, green: 0.5, blue: 0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [accent, Color(red: 0.85, green: 0.7, blue: 0)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
