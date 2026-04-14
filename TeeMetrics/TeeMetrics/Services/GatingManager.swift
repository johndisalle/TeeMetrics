// MARK: - Gating Manager
// Progressive feature gating: 5 free rounds, then stats lock
// 3-day free trial on yearly plan

import SwiftUI
import SwiftData

@MainActor @Observable
final class GatingManager {
    static let shared = GatingManager()

    // MARK: - Free tier limits
    static let freeRoundLimit = 5
    static let trialDurationDays = 3

    var completedRoundCount: Int = 0

    var isProUser: Bool {
        SubscriptionManager.shared.isProUser
    }

    // MARK: - Can user access advanced stats?
    var canAccessAdvancedStats: Bool {
        isProUser || completedRoundCount <= Self.freeRoundLimit
    }

    // MARK: - Can user log unlimited rounds?
    var canLogUnlimitedRounds: Bool {
        true // Free tier always allows logging — we gate stats, not logging
    }

    // MARK: - Should show upgrade prompt?
    var shouldShowUpgradePrompt: Bool {
        !isProUser && completedRoundCount > Self.freeRoundLimit
    }

    // MARK: - Rounds remaining in free tier
    var freeRoundsRemaining: Int {
        max(0, Self.freeRoundLimit - completedRoundCount)
    }

    // MARK: - Feature check
    func requiresPro(feature: ProFeature) -> Bool {
        guard !isProUser else { return false }
        switch feature {
        case .advancedStats:
            return completedRoundCount > Self.freeRoundLimit
        case .strokesGained:
            return completedRoundCount > Self.freeRoundLimit
        case .pdfExport:
            return true
        case .csvExport:
            return completedRoundCount > Self.freeRoundLimit
        case .unlimitedHistory:
            return false // Always show history, gate detailed stats
        case .roundComparison:
            return completedRoundCount > Self.freeRoundLimit
        case .clubRecommendation:
            return completedRoundCount > Self.freeRoundLimit
        case .pinEditing:
            // Gated at the call site based on course origin (community/bundled)
            // via canEditPins(for:) below.
            return true
        case .hazardDistances:
            // Pure Pro feature — hazard editing and live hazard HUD are
            // locked for every non-Pro user on every course.
            return true
        case .playsLikeDistance:
            // Pure Pro feature — elevation + wind adjusted "plays like"
            // yardage on the on-course HUD.
            return true
        case .shotTracking:
            // Pure Pro feature — manual-tap GPS shot capture during a
            // round. Mirrors the playsLikeDistance gate exactly.
            return true
        }
    }

    // MARK: - Pin Editing Gate (Phase 1B)
    /// Returns true if the user can edit GPS pins on this course without Pro.
    /// User-created courses are always free to edit; community/bundled courses
    /// require Pro.
    func canEditPins(for course: GolfCourse) -> Bool {
        if isProUser { return true }
        return course.isUserCreated
    }

    // MARK: - Update count from SwiftData
    func updateRoundCount(from context: ModelContext) {
        let descriptor = FetchDescriptor<GolfRound>(
            predicate: #Predicate { $0.isCompleted == true }
        )
        completedRoundCount = (try? context.fetchCount(descriptor)) ?? 0
    }
}

// MARK: - Pro Feature Enum
enum ProFeature: String, CaseIterable {
    case advancedStats = "Advanced Stats"
    case strokesGained = "Strokes Gained"
    case pdfExport = "PDF Export"
    case csvExport = "CSV Export"
    case unlimitedHistory = "Unlimited History"
    case roundComparison = "Round Comparison"
    case clubRecommendation = "Club Recommendation"
    case pinEditing = "GPS Pin Editing"
    case hazardDistances = "Hazard Distances"
    case playsLikeDistance = "Plays-Like Distance"
    case shotTracking = "Shot Tracking"
}

// MARK: - Pro Gate View Modifier
struct ProGateModifier: ViewModifier {
    let feature: ProFeature
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if GatingManager.shared.requiresPro(feature: feature) {
            Button {
                showPaywall = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .foregroundStyle(Theme.accent)
                    Text("Unlock \(feature.rawValue)")
                        .font(.subheadline.bold())
                    Text("Upgrade to Pro to access this feature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                NavigationStack { SubscriptionView() }
            }
        } else {
            content
        }
    }
}

extension View {
    func proGated(_ feature: ProFeature) -> some View {
        modifier(ProGateModifier(feature: feature))
    }
}
