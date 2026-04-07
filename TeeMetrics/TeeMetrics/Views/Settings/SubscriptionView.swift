// MARK: - Subscription View
// StoreKit 2 paywall with all Pro features listed, 3-day trial, progressive gating

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = SubscriptionManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.accent)

                    Text("TeeMetrics Pro")
                        .font(.largeTitle.bold())

                    Text("Unlock the full power of your golf game")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Free rounds remaining
                    if !manager.isProUser {
                        let remaining = GatingManager.shared.freeRoundsRemaining
                        if remaining > 0 {
                            Text("\(remaining) free rounds remaining — upgrade anytime")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.top, 32)

                // MARK: - Feature List
                VStack(alignment: .leading, spacing: 14) {
                    Text("EVERYTHING IN PRO")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    // Analytics & Insights
                    proFeature("chart.line.uptrend.xyaxis", "Advanced analytics & score trends")
                    proFeature("scope", "Strokes gained breakdown (off-tee, approach, short game, putting)")
                    proFeature("chart.line.downtrend.xyaxis", "Handicap projection & progress tracking")
                    proFeature("arrow.left.arrow.right", "Round comparison — overlay two rounds side by side")
                    proFeature("lightbulb.fill", "Club recommendations — know exactly which club to hit")

                    Divider().padding(.vertical, 4)

                    // Tracking & Tools
                    proFeature("target", "Goal setting with progress tracking")
                    proFeature("trophy.fill", "Achievements & milestones")
                    proFeature("figure.golf", "Practice & range session tracking")
                    proFeature("doc.richtext", "Beautiful PDF round reports")
                    proFeature("photo.fill", "Shareable round cards (feed & story formats)")

                    Divider().padding(.vertical, 4)

                    // Data & Sync
                    proFeature("square.and.arrow.up", "CSV & PDF data export")
                    proFeature("bag.fill", "Custom club sets & distance tracking")
                    proFeature("infinity", "Unlimited round history & stats")
                    proFeature("bell.fill", "Smart notifications & weekly recaps")
                }
                .padding()
                .background(Theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Pricing
                if manager.isProUser {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You're a Pro member!")
                            .font(.headline)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        pricingCard(
                            title: "Yearly",
                            price: "$29.99/yr",
                            subtitle: "3-day free trial \u{2022} Save 50%",
                            badge: "BEST VALUE",
                            productID: SubscriptionManager.yearlyID,
                            highlighted: true
                        )
                        pricingCard(
                            title: "Monthly",
                            price: "$4.99/mo",
                            subtitle: "Cancel anytime",
                            productID: SubscriptionManager.monthlyID
                        )
                        pricingCard(
                            title: "Lifetime",
                            price: "$49.99",
                            subtitle: "One-time purchase \u{2022} Pay once, own forever",
                            productID: SubscriptionManager.lifetimeID
                        )
                    }

                    // MARK: - Guarantee
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .foregroundStyle(.green)
                        Text("Try free for 3 days. Cancel anytime before trial ends — no charge.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Button("Restore Purchases") {
                        Task { await manager.restore() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                    // MARK: - Legal
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: AppURLs.terms)
                        Text("·")
                        Link("Privacy Policy", destination: AppURLs.privacy)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Go Pro")
        .navigationBarTitleDisplayMode(.inline)
        .task { await manager.loadProducts() }
    }

    // MARK: - Feature Row
    private func proFeature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Pricing Card
    private func pricingCard(
        title: String,
        price: String,
        subtitle: String,
        badge: String? = nil,
        productID: String,
        highlighted: Bool = false
    ) -> some View {
        Button {
            Task {
                if let product = manager.products.first(where: { $0.id == productID }) {
                    _ = try? await manager.purchase(product)
                }
            }
        } label: {
            VStack(spacing: 0) {
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Theme.accent)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(highlighted ? .white.opacity(0.8) : .secondary)
                    }
                    Spacer()
                    Text(price)
                        .font(.title3.bold())
                }
                .padding()
            }
            .background(highlighted ? Theme.primary : Theme.cardBackground)
            .foregroundStyle(highlighted ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(highlighted ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
