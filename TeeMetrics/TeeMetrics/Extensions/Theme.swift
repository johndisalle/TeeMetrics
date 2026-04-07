// MARK: - Theme
// App-wide color palette and styling constants

import SwiftUI

enum Theme {
    static let primary = Color(red: 0.13, green: 0.37, blue: 0.25) // #215F40 — muted emerald
    static let accent = Color(red: 0.93, green: 0.79, blue: 0.39)  // #EDCA64 — warm gold
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
        colors: [Color(red: 0.10, green: 0.30, blue: 0.20), Color(red: 0.18, green: 0.45, blue: 0.32)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [accent, Color(red: 0.82, green: 0.68, blue: 0.30)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
