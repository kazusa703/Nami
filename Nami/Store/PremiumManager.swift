//
//  PremiumManager.swift
//  Nami
//
//  プレミアム状態の管理
//  StoreKit 2 を使用した課金処理（月額/年額サブスク + 買い切り）
//

import os
import StoreKit
import SwiftUI

private let logger = Logger(subsystem: "com.imai.Nami", category: "PremiumManager")

/// プレミアム状態を管理するクラス
/// StoreKit 2 で月額・年額サブスクリプションおよび買い切り（Lifetime）の購入・復元を提供する
@Observable
class PremiumManager {
    // MARK: - プロパティ

    /// プレミアムが有効かどうか（サブスクまたは買い切り）
    var isPremium: Bool = false
    /// 商品情報（3商品）
    var products: [Product] = []
    /// 購入処理中フラグ
    var isPurchasing: Bool = false
    /// 復元処理中フラグ
    var isRestoring: Bool = false
    /// エラーメッセージ
    var errorMessage: String?
    /// 商品取得に失敗したかどうか
    var productFetchFailed: Bool = false
    /// 購入成功フラグ（UI表示用）
    var showPurchaseSuccess: Bool = false
    /// 現在のサブスクリプション有効期限（あれば）
    var subscriptionExpirationDate: Date?
    /// 現在のプランタイプ
    var currentPlanType: PlanType?

    /// 無料ユーザーのカスタムタグ上限
    let freeCustomTagLimit = 20

    /// 商品ID
    static let monthlyProductID = "com.imai.Nami.premium.monthly"
    static let yearlyProductID = "com.imai.Nami.premium.yearly"
    static let lifetimeProductID = "com.imai.Nami.removeAds"

    /// 全商品IDリスト
    static let allProductIDs: Set<String> = [
        monthlyProductID,
        yearlyProductID,
        lifetimeProductID,
    ]

    /// トランザクション監視タスク
    private var updateListenerTask: Task<Void, Error>?

    /// プランタイプ
    enum PlanType: String {
        case monthly
        case yearly
        case lifetime
    }

    // MARK: - 初期化

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

    // MARK: - 商品取得

    /// App Store Connect から全商品情報を取得する（最大5回リトライ、空配列もリトライ）
    @MainActor
    func fetchProducts() async {
        productFetchFailed = false

        logger.notice("========== STOREKIT DIAGNOSTICS ==========")
        logger.notice("Requesting product IDs: \(Self.allProductIDs.sorted().joined(separator: ", "))")

        #if DEBUG
            logger.notice("Build config: DEBUG")
        #else
            logger.notice("Build config: RELEASE")
        #endif

        #if targetEnvironment(simulator)
            logger.notice("Environment: SIMULATOR")
        #else
            logger.notice("Environment: DEVICE")
        #endif

        // Check Storefront info
        if let storefront = await Storefront.current {
            logger.notice("Storefront: \(storefront.countryCode) (id: \(storefront.id))")
        } else {
            logger.error("Storefront is nil — StoreKit Configuration may not be loaded!")
        }

        // Try fetching each product individually to isolate which ID fails
        logger.notice("--- Individual product fetch test ---")
        for productID in Self.allProductIDs.sorted() {
            do {
                let result = try await Product.products(for: [productID])
                if result.isEmpty {
                    logger.error("  \(productID) → empty (0 results, no error)")
                } else {
                    logger.notice("  \(productID) → \(result[0].displayName) \(result[0].displayPrice) type=\(result[0].type.rawValue)")
                }
            } catch {
                logger.error("  \(productID) → ERROR: \(error.localizedDescription)")
                logger.error("    Error type: \(String(describing: type(of: error)))")
                if let skError = error as? StoreKitError {
                    logger.error("    StoreKitError: \(String(describing: skError))")
                }
            }
        }
        logger.notice("--- End individual test ---")

        // Check current entitlements
        logger.notice("Checking Transaction.currentEntitlements...")
        var entitlementCount = 0
        for await result in Transaction.currentEntitlements {
            entitlementCount += 1
            switch result {
            case let .verified(tx):
                logger.notice("  Entitlement: \(tx.productID) (verified)")
            case let .unverified(tx, error):
                logger.error("  Entitlement: \(tx.productID) (UNVERIFIED: \(error.localizedDescription))")
            }
        }
        logger.notice("Total entitlements: \(entitlementCount)")
        logger.notice("========== END DIAGNOSTICS ==========")

        // Main fetch with retries
        for attempt in 1 ... 5 {
            do {
                let storeProducts = try await Product.products(for: Self.allProductIDs)
                logger.notice("Attempt \(attempt)/5: fetched \(storeProducts.count) products")
                for p in storeProducts {
                    logger.notice("  → \(p.id) | \(p.displayName) | \(p.displayPrice) | type=\(p.type.rawValue)")
                }

                if storeProducts.isEmpty {
                    logger.warning("Empty result on attempt \(attempt)")
                    if attempt < 5 {
                        let delay = Double(attempt)
                        logger.notice("  Retrying in \(delay)s...")
                        try? await Task.sleep(for: .seconds(delay))
                        continue
                    }
                }

                // Sort: monthly → yearly → lifetime
                products = storeProducts.sorted { a, b in
                    let order: [String: Int] = [
                        Self.monthlyProductID: 0,
                        Self.yearlyProductID: 1,
                        Self.lifetimeProductID: 2,
                    ]
                    return (order[a.id] ?? 99) < (order[b.id] ?? 99)
                }
                productFetchFailed = products.isEmpty
                if products.isEmpty {
                    logger.error("FINAL: No products loaded after attempt \(attempt)")
                    logger.error("Possible causes:")
                    logger.error("  1. StoreKit Configuration file not set in scheme")
                    logger.error("  2. Product IDs in .storekit file don't match code")
                    logger.error("  3. Xcode beta bug — try Product > Manage StoreKit Configuration")
                } else {
                    let count = products.count
                    logger.notice("Successfully loaded \(count) products")
                }
                return
            } catch {
                logger.error("Attempt \(attempt)/5 threw error:")
                logger.error("  Description: \(error.localizedDescription)")
                logger.error("  Type: \(String(describing: type(of: error)))")
                logger.error("  Full: \(String(describing: error))")
                if let skError = error as? StoreKitError {
                    switch skError {
                    case let .networkError(urlError):
                        logger.error("  StoreKitError.networkError: \(urlError.localizedDescription)")
                    case let .systemError(underlying):
                        logger.error("  StoreKitError.systemError: \(underlying.localizedDescription)")
                    default:
                        logger.error("  StoreKitError: \(String(describing: skError))")
                    }
                }
                if attempt == 5 {
                    productFetchFailed = true
                } else {
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }
        logger.error("All 5 attempts exhausted. productFetchFailed = true")
    }

    /// 指定した商品IDの Product を返す
    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - 購入

    /// 指定した商品を購入する
    @MainActor
    func purchase(_ product: Product) async {
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

    // MARK: - 復元

    /// 購入済みのトランザクションを復元する
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

    // MARK: - カスタムタグ制限

    /// カスタムタグを追加できるかどうか
    func canCreateCustomTag(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < freeCustomTagLimit
    }

    /// 残り作成可能数
    func remainingCustomTags(currentCount: Int) -> Int {
        if isPremium { return .max }
        return max(0, freeCustomTagLimit - currentCount)
    }

    /// プレミアム失効後にタグの非アクティブ化が必要かどうか
    func needsTagDeactivation(activeCustomTagCount: Int) -> Bool {
        return !isPremium && activeCustomTagCount > freeCustomTagLimit
    }

    // MARK: - 内部ロジック

    /// 購入済みステータスを確認・更新する
    @MainActor
    func updatePurchasedStatus() async {
        var foundPremium = false
        var expiration: Date?
        var plan: PlanType?

        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result {
                if Self.allProductIDs.contains(transaction.productID) {
                    // 失効チェック（サブスクのみ）
                    if let revocationDate = transaction.revocationDate {
                        if revocationDate < Date() {
                            continue
                        }
                    }

                    foundPremium = true

                    switch transaction.productID {
                    case Self.lifetimeProductID:
                        // Lifetime は最優先 — 一度見つけたら上書きしない
                        plan = .lifetime
                        expiration = nil
                    case Self.monthlyProductID:
                        if plan != .lifetime {
                            plan = .monthly
                            expiration = transaction.expirationDate
                        }
                    case Self.yearlyProductID:
                        if plan != .lifetime {
                            plan = .yearly
                            expiration = transaction.expirationDate
                        }
                    default:
                        break
                    }
                }
            }
        }

        isPremium = foundPremium
        subscriptionExpirationDate = expiration
        currentPlanType = foundPremium ? plan : nil
    }

    /// トランザクションの更新を監視する（weak self で循環参照を防止）
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = result {
                    await transaction.finish()
                    await self.updatePurchasedStatus()
                }
            }
        }
    }

    /// トランザクションの検証
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

/// PremiumManagerの環境キー
struct PremiumManagerKey: EnvironmentKey {
    static let defaultValue = PremiumManager()
}

extension EnvironmentValues {
    var premiumManager: PremiumManager {
        get { self[PremiumManagerKey.self] }
        set { self[PremiumManagerKey.self] = newValue }
    }
}
