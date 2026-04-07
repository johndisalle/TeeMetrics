// MARK: - Subscription View
// StoreKit 2 paywall: monthly, yearly, lifetime options

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
                }
                .padding(.top, 32)

                // MARK: - Feature List
                VStack(alignment: .leading, spacing: 12) {
                    proFeature("chart.line.uptrend.xyaxis", "Advanced analytics & trends")
                    proFeature("scope", "Strokes gained breakdown")
                    proFeature("map.fill", "Unlimited offline course maps")
                    proFeature("square.and.arrow.up", "CSV & PDF export")
                    proFeature("bag.fill", "Custom club sets")
                    proFeature("icloud.fill", "iCloud sync")
                    proFeature("infinity", "Unlimited round history")
                    proFeature("hand.thumbsup.fill", "Ad-free experience")
                }
                .padding()
                .background(Theme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // MARK: - Pricing
                if manager.isProUser {
                    Label("You're a Pro member!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        pricingCard(
                            title: "Monthly",
                            price: "$4.99/mo",
                            subtitle: "Cancel anytime",
                            productID: SubscriptionManager.monthlyID
                        )
                        pricingCard(
                            title: "Yearly",
                            price: "$29.99/yr",
                            subtitle: "Save 50% — best value",
                            productID: SubscriptionManager.yearlyID,
                            highlighted: true
                        )
                        pricingCard(
                            title: "Lifetime",
                            price: "$49.99",
                            subtitle: "One-time purchase",
                            productID: SubscriptionManager.lifetimeID
                        )
                    }

                    Button("Restore Purchases") {
                        Task { await manager.restore() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // MARK: - Legal (required by App Store for paywall)
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

    private func proFeature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func pricingCard(
        title: String,
        price: String,
        subtitle: String,
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
