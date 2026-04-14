// MARK: - Theme
// Dark-first semantic color system. Every token is defined with explicit
// hex values for both color schemes via UIColor's dynamic provider, so
// nothing leaks the default SwiftUI gray-on-white palette.
//
// Design intent:
//   - Dark mode is the "hero" — deep near-black background with a
//     near-charcoal surface ladder, emerald accents, warm gold highlights.
//   - Light mode is a warm off-white (#FAF9F6) base, NOT pure white. Card
//     surfaces sit a hair brighter than the canvas with subtle warmth.
//     Text is a near-black (#1A1A1F), never pure black.
//
// All raw `Color(.systemBackground)` / `Color(.secondarySystemBackground)`
// usages elsewhere in the app should route through these tokens. The
// legacy `background` / `secondaryBackground` / `cardBackground` aliases
// at the bottom of this enum keep older call sites working.

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Hex helper
    /// Builds a SwiftUI Color that resolves to one of two hex values
    /// depending on the current trait collection's user interface style.
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // MARK: - Surfaces
    /// Page background. Light = warm off-white. Dark = near-black green.
    static let background = dynamic(light: 0xFAF9F6, dark: 0x0E1410)

    /// Slightly elevated surface — list rows, section backgrounds.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x161D18)

    /// Stronger elevation — cards on top of surfaces, sheets, modals.
    static let surfaceElevated = dynamic(light: 0xF3F1EC, dark: 0x1F2823)

    // MARK: - Brand
    /// Emerald, the brand primary. Slightly brightened in dark mode so it
    /// reads against the deep background without losing saturation.
    static let primary = dynamic(light: 0x215F40, dark: 0x2E7D52)

    /// Subdued primary for chips, fills, and "is selected" backgrounds.
    static let primaryMuted = dynamic(light: 0xD7E5DC, dark: 0x1C3528)

    /// Warm gold accent — used sparingly for highlights, badges, the
    /// onboarding flag glow.
    static let accent = dynamic(light: 0xCFA84F, dark: 0xEDCA64)

    // MARK: - Text
    /// Primary text — near-black on light, near-white on dark.
    static let text = dynamic(light: 0x1A1A1F, dark: 0xF2F2F2)

    /// Secondary / muted text.
    static let textMuted = dynamic(light: 0x6B6B70, dark: 0x9A9DA4)

    // MARK: - Status
    static let success = dynamic(light: 0x2E7D52, dark: 0x4CAF7B)
    static let warning = dynamic(light: 0xC67A20, dark: 0xE89945)
    static let danger  = dynamic(light: 0xB23A3A, dark: 0xE25555)

    // MARK: - Score colors (adaptive, matched to status palette)
    static let eagle = Color(red: 0.85, green: 0.65, blue: 0.0)
    static let birdie = Color(red: 0.9, green: 0.25, blue: 0.2)
    static let par = Color(red: 0.2, green: 0.65, blue: 0.35)
    static let bogey = Color(red: 0.3, green: 0.5, blue: 0.85)
    static let doublePlus = Color(red: 0.6, green: 0.35, blue: 0.7)

    static func scoreColor(for scoreToPar: Int) -> Color {
        switch scoreToPar {
        case ...(-2): return eagle
        case -1: return birdie
        case 0: return par
        case 1: return bogey
        default: return doublePlus
        }
    }

    // MARK: - Gradients
    /// Header / onboarding deep emerald gradient — kept for any view
    /// that still wants a directional fill instead of a flat surface.
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

    // MARK: - Legacy aliases
    /// Older code references `secondaryBackground` and `cardBackground`.
    /// Map them onto the new token ladder so call sites don't churn.
    static let secondaryBackground = surface
    static let cardBackground = surfaceElevated
}

// MARK: - UIColor hex helper
private extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
