import Foundation
import StoreKit
import SwiftUI
import Observation

/// Single source of truth for Pro purchase state.
/// Uses StoreKit 2 for purchases and UserDefaults as a fallback cache.
@MainActor
@Observable
final class ProManager {

    // MARK: - Singleton
    static let shared = ProManager()

    // MARK: - Product
    static let productID = "com.fetchdish.pro"

    // MARK: - Free tier limits
    static let freeRecipeLimit     = 5
    static let freeIngredientLimit = 4
    static let freeConversionLimit = 4 // number of conversions unlocked in free tier

    // MARK: - State
    private(set) var isPro: Bool = false
    private(set) var product: Product? = nil
    private(set) var purchaseState: PurchaseState = .unknown

    enum PurchaseState: Equatable {
        case unknown
        case notPurchased
        case purchased
        case pending
        case failed(String)
    }

    // MARK: - Init
    private init() {
        // Restore cached state immediately so UI doesn't flash
        isPro = UserDefaults.standard.bool(forKey: "isPro")
    }

    // MARK: - Launch verification
    /// Call on app launch. Loads product info and verifies purchase state with StoreKit.
    func verifyOnLaunch() async {
        await loadProduct()
        await verifyPurchase()
    }

    // MARK: - Load product
    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            print("[ProManager] Failed to load product: \(error)")
        }
    }

    // MARK: - Verify existing purchase
    private func verifyPurchase() async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.productID {
                    setPro(true)
                    return
                }
            case .unverified:
                break
            }
        }
        // No valid entitlement found — respect cached UserDefaults for offline
        if !UserDefaults.standard.bool(forKey: "isPro") {
            setPro(false)
        }
    }

    // MARK: - Purchase
    func purchase() async {
        guard let product else {
            purchaseState = .failed("Product not available.")
            return
        }
        purchaseState = .pending
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    setPro(true)
                    purchaseState = .purchased
                case .unverified(_, let error):
                    purchaseState = .failed("Verification failed: \(error.localizedDescription)")
                }
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .notPurchased
            @unknown default:
                purchaseState = .notPurchased
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await verifyPurchase()
        } catch {
            print("[ProManager] Restore failed: \(error)")
        }
    }

    // MARK: - Helpers
    func canSaveMoreRecipes(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeRecipeLimit
    }

    func canSelectMoreIngredients(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeIngredientLimit
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: "isPro")
        purchaseState = value ? .purchased : .notPurchased
    }
}
