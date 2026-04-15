// MARK: - Subscription Manager
// StoreKit 2 integration for freemium Pro tier

import SwiftUI
import StoreKit

@MainActor @Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    var isProUser: Bool = false
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []

    // MARK: - Product IDs
    // Annual auto-renewing subscription with a 3-day intro trial (price
    // configured in App Store Connect — code reads `displayPrice` at
    // runtime so a price change in ASC doesn't require a binary update).
    static let yearlyID = "com.teemetrics.pro.yearly"

    // Lifetime non-consumable IAP — single purchase, never expires.
    // Verified via the same `Transaction.currentEntitlements` path
    // since StoreKit returns non-consumables there indefinitely.
    static let lifetimeID = "com.teemetrics.pro.lifetime"

    // NOTE: A monthly subscription used to be offered. Legacy monthly
    // subscribers KEEP Pro automatically — `updatePurchasedProducts()`
    // iterates `Transaction.currentEntitlements`, which still surfaces
    // their active subscription regardless of whether the monthly
    // product is loaded in `Product.products(for:)` below. They just
    // can't see the monthly card on the paywall anymore.

    init() {
        listenForTransactions()
        Task { await updatePurchasedProducts() }
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                Self.yearlyID,
                Self.lifetimeID
            ])
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore
    func restore() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }


    // MARK: - Update Purchased State
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                continue
            }
        }
        purchasedProductIDs = purchased
        isProUser = !purchased.isEmpty
    }

    // MARK: - Verification (static, nonisolated)
    nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
