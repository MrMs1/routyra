//
//  StoreKitManager.swift
//  Routyra
//
//  In-app purchase manager using StoreKit 2.
//

import Combine
import Foundation
import os.log
import StoreKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.routyra", category: "StoreKit")

/// Purchase product types
enum PurchaseProduct: String, CaseIterable {
    case removeAds = "com.mrms.routyra.removeads"

    var displayName: String {
        switch self {
        case .removeAds:
            return L10n.tr("premium_remove_ads_title")
        }
    }

    var description: String {
        switch self {
        case .removeAds:
            return L10n.tr("premium_remove_ads_description")
        }
    }
}

/// Purchase errors
enum PurchaseError: Error {
    case failedVerification
    case productNotFound
    case purchaseFailed
    case userCancelled
    case pending

    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return L10n.tr("purchase_error_verification")
        case .productNotFound:
            return L10n.tr("purchase_error_not_found")
        case .purchaseFailed:
            return L10n.tr("purchase_error_failed")
        case .userCancelled:
            return L10n.tr("purchase_error_cancelled")
        case .pending:
            return L10n.tr("purchase_error_pending")
        }
    }
}

/// StoreKit manager for handling in-app purchases
@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    /// Available products
    @Published private(set) var products: [Product] = []

    /// Purchased product IDs
    @Published private(set) var purchasedProductIDs: Set<String> = []

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    private var updateListenerTask: Task<Void, Error>?

    nonisolated let instanceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.routyra",
        category: "StoreKit"
    )

    private init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Load products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = PurchaseProduct.allCases.map { $0.rawValue }
            logger.info("Loading products: \(productIDs)")
            products = try await Product.products(for: productIDs)
            logger.info("Loaded \(self.products.count) products")
            isLoading = false
        } catch {
            errorMessage = L10n.tr("purchase_error_load_failed")
            isLoading = false
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case let .success(verification):
                let transaction = try Self.checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                isLoading = false

            case .userCancelled:
                isLoading = false
                throw PurchaseError.userCancelled

            case .pending:
                isLoading = false
                throw PurchaseError.pending

            @unknown default:
                isLoading = false
                throw PurchaseError.purchaseFailed
            }
        } catch {
            isLoading = false

            if let purchaseError = error as? PurchaseError {
                errorMessage = purchaseError.localizedDescription
            } else {
                errorMessage = L10n.tr("purchase_error_failed")
            }

            throw error
        }
    }

    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            logger.info("Restoring purchases...")
            try await AppStore.sync()
            await updatePurchasedProducts()
            isLoading = false
            logger.info("Restore completed")
        } catch {
            errorMessage = L10n.tr("purchase_error_restore_failed")
            isLoading = false
            logger.error("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        logger.info("Checking purchased products...")
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                purchasedIDs.insert(transaction.productID)
                logger.info("Verified purchase: \(transaction.productID)")
            } catch {
                logger.error("Transaction verification failed: \(error.localizedDescription)")
            }
        }

        purchasedProductIDs = purchasedIDs
        logger.info("Total purchased products: \(purchasedIDs.count)")
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [instanceLogger] in
            instanceLogger.info("Starting transaction listener")
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    instanceLogger.info("New transaction: \(transaction.productID)")
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    instanceLogger.error("Transaction update error: \(error.localizedDescription)")
                }
            }
        }
    }

    private nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case let .verified(safe):
            return safe
        }
    }
}

// MARK: - Convenience Methods

extension StoreKitManager {
    /// Check if a product is purchased
    func isPurchased(_ productType: PurchaseProduct) -> Bool {
        purchasedProductIDs.contains(productType.rawValue)
    }

    /// Get a specific product
    func product(for productType: PurchaseProduct) -> Product? {
        products.first { $0.id == productType.rawValue }
    }
}
