// MARK: - HazardPin Model (Phase 2 GPS)
// A single-point marker for a bunker or water hazard on a golf hole.
// Used by HoleGPSEditorView for placement and by HazardCalculator +
// HazardCard for live next-hazard distance display during rounds.
//
// Single-point hazards only in this phase — the carry and "into"
// distances are computed from the same lat/lng. A future phase could
// extend to polygons (front/back edges) for more accurate "into" values.
//
// The enum HazardKind is the source of truth for the `kind` string so
// typos are impossible at compile time. SwiftData stores the rawValue.

import Foundation
import SwiftData

// MARK: - HazardKind enum
enum HazardKind: String, CaseIterable, Identifiable {
    case bunker
    case water

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bunker: return "Bunker"
        case .water: return "Water"
        }
    }

    /// SF Symbol used for map annotations and card icons.
    var systemImage: String {
        switch self {
        case .bunker: return "sun.dust.fill"
        case .water: return "drop.fill"
        }
    }

    /// Returns a Color for UI tinting. Import SwiftUI where used; this
    /// property is kept as a hex-style factory so HazardPin.swift stays
    /// UIKit-free and importable from non-UI services.
    var colorName: String {
        switch self {
        case .bunker: return "bunker"    // sand beige
        case .water: return "water"      // pool blue
        }
    }
}

// MARK: - HazardPin @Model
@Model
final class HazardPin {
    var id: UUID
    /// HazardKind rawValue: "bunker" or "water". Use `hazardKind` for the
    /// typed accessor.
    var kind: String
    var latitude: Double
    var longitude: Double

    // MARK: - Relationships
    /// Back-reference to the parent hole. Inverse side of
    /// `HoleInfo.hazards`.
    var hole: HoleInfo?

    /// Typed accessor over the stored `kind` rawValue string.
    /// Returns nil only if a corrupted value slipped in.
    var hazardKind: HazardKind? {
        HazardKind(rawValue: kind)
    }

    init(
        kind: HazardKind,
        latitude: Double,
        longitude: Double,
        hole: HoleInfo? = nil
    ) {
        self.id = UUID()
        self.kind = kind.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.hole = hole
    }
}
