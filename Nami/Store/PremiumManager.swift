//
//  PremiumManager.swift
//  Nami
//
//  Premium state management with 3 plan support
//  StoreKit 2: monthly subscription, yearly subscription, lifetime purchase
//

import StoreKit
import SwiftUI

// MARK: - PremiumPlan

/// Represents the active premium plan type
enum PremiumPlan: String {
    case yearly
    case lifetime

    var displayName: String {
        switch self {
        case .yearly:
            return String(localized: "年額プラン")
        case .lifetime:
            return String(localized: "買い切りプラン")
        }
    }
}

/// Manages premium status with StoreKit 2
/// Supports monthly/yearly subscriptions and lifetime non-consumable purchase
@Observable
class PremiumManager {
    // MARK: - Product IDs

    static let yearlyProductID = "com.imai.Nami.premium.yearly"
    static let lifetimeProductID = "com.imai.Nami.removeAds"
    static let allProductIDs: Set<String> = [yearlyProductID, lifetimeProductID]

    // MARK: - Properties

    /// Whether user has any active premium plan
    var isPremium: Bool = false
    /// Currently active plan (nil if not premium)
    var activePlan: PremiumPlan?

    /// Fetched products
    var yearlyProduct: Product?
    var lifetimeProduct: Product?

    /// Purchasing state
    var isPurchasing: Bool = false
    /// Restoring state
    var isRestoring: Bool = false
    /// Error message for UI
    var errorMessage: String?
    /// Whether product fetch failed
    var productFetchFailed: Bool = false
    /// Purchase success flag for UI
    var showPurchaseSuccess: Bool = false

    /// Free user custom tag limit
    let freeCustomTagLimit = 10

    /// Legacy single product access (for backward compatibility with existing views)
    var product: Product? {
        lifetimeProduct
    }

    /// Transaction listener task
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Init

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await updatePurchasedStatus()
            await fetchProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Fetch Products

    /// Fetch all 3 product infos from App Store Connect (retry up to 3 times)
    @MainActor
    func fetchProducts() async {
        productFetchFailed = false
        for attempt in 1 ... 3 {
            do {
                let products = try await Product.products(for: Self.allProductIDs)
                for p in products {
                    switch p.id {
                    case Self.yearlyProductID:
                        yearlyProduct = p
                    case Self.lifetimeProductID:
                        lifetimeProduct = p
                    default:
                        break
                    }
                }
                let anyFetched = yearlyProduct != nil || lifetimeProduct != nil
                productFetchFailed = !anyFetched
                return
            } catch {
                if attempt == 3 {
                    productFetchFailed = true
                } else {
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }
    }

    /// Legacy method name for backward compatibility
    @MainActor
    func fetchProduct() async {
        await fetchProducts()
    }

    // MARK: - Purchase

    /// Purchase a specific product
    @MainActor
    func purchase(product: Product) async {
        guard !isPurchasing else { return }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case let .success(verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedStatus()
                showPurchaseSuccess = true
                HapticManager.recordFeedback()

            case .userCancelled:
                break

            case .pending:
                errorMessage = String(localized: "購入が保留中です")

            @unknown default:
                break
            }
        } catch {
            errorMessage = String(localized: "購入に失敗しました: \(error.localizedDescription)")
        }

        isPurchasing = false
    }

    /// Legacy purchase method — purchases lifetime product for backward compatibility
    @MainActor
    func purchase() async {
        guard let lifetimeProduct else {
            errorMessage = String(localized: "商品情報を取得できませんでした")
            return
        }
        await purchase(product: lifetimeProduct)
    }

    // MARK: - Restore

    /// Restore purchased transactions
    @MainActor
    func restore() async {
        isRestoring = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedStatus()

            if !isPremium {
                errorMessage = String(localized: "復元可能な購入が見つかりませんでした")
            }
        } catch {
            errorMessage = String(localized: "復元に失敗しました: \(error.localizedDescription)")
        }

        isRestoring = false
    }

    // MARK: - Custom Tag Limits

    /// Whether user can create another custom tag
    func canCreateCustomTag(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < freeCustomTagLimit
    }

    /// Remaining custom tags the user can create
    func remainingCustomTags(currentCount: Int) -> Int {
        if isPremium { return .max }
        return max(0, freeCustomTagLimit - currentCount)
    }

    /// Free user history limit in days
    static let freeHistoryDays = 30

    /// Cutoff date for free users (entries older than this are hidden)
    var historyLimitDate: Date? {
        if isPremium { return nil }
        return Calendar.current.date(byAdding: .day, value: -Self.freeHistoryDays, to: .now)
    }

    // MARK: - Internal

    /// Check all current entitlements and update premium status
    @MainActor
    private func updatePurchasedStatus() async {
        var foundPlan: PremiumPlan?

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }

            switch transaction.productID {
            case Self.lifetimeProductID:
                // Non-consumable: always valid if present in entitlements
                if transaction.revocationDate == nil {
                    foundPlan = .lifetime
                }

            case Self.yearlyProductID:
                if transaction.revocationDate == nil,
                   let expiration = transaction.expirationDate,
                   expiration > Date.now
                {
                    // Prefer lifetime, then yearly over monthly
                    if foundPlan != .lifetime {
                        foundPlan = .yearly
                    }
                }

            default:
                break
            }
        }

        activePlan = foundPlan
        isPremium = foundPlan != nil
    }

    /// Listen for transaction updates (renewals, revocations, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case let .verified(transaction) = result {
                    await transaction.finish()
                    if PremiumManager.allProductIDs.contains(transaction.productID) {
                        await self.updatePurchasedStatus()
                    }
                }
            }
        }
    }

    /// Verify transaction signature
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .unverified(_, error):
            throw error
        case let .verified(value):
            return value
        }
    }
}

// MARK: - Environment Key

/// EnvironmentKey for PremiumManager
struct PremiumManagerKey: EnvironmentKey {
    static let defaultValue = PremiumManager()
}

extension EnvironmentValues {
    var premiumManager: PremiumManager {
        get { self[PremiumManagerKey.self] }
        set { self[PremiumManagerKey.self] = newValue }
    }
}
