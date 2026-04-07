// MARK: - Subscription Manager
// StoreKit 2 integration for freemium Pro tier

import SwiftUI
import StoreKit

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    var isProUser: Bool = false
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []

    static let monthlyID = "com.teemetrics.pro.monthly"
    static let yearlyID = "com.teemetrics.pro.yearly"
    static let lifetimeID = "com.teemetrics.pro.lifetime"

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task { await updatePurchasedProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    @MainActor
    func loadProducts() async {
        do {
            products = try await Product.products(for: [
                Self.monthlyID,
                Self.yearlyID,
                Self.lifetimeID
            ])
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
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
    @MainActor
    func restore() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    // MARK: - Update Purchased State
    @MainActor
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                continue
            }
        }
        purchasedProductIDs = purchased
        isProUser = !purchased.isEmpty
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
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
