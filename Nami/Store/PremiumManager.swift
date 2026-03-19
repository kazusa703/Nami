//
//  PremiumManager.swift
//  Nami
//
//  プレミアム（広告除去）状態の管理
//  StoreKit 2 を使用した課金処理
//

import SwiftUI
import StoreKit

/// プレミアム状態を管理するクラス
/// StoreKit 2 で広告除去（Non-Consumable）の購入・復元を提供する
@Observable
class PremiumManager {

    // MARK: - プロパティ

    /// プレミアム（広告除去）が購入済みかどうか
    var isPremium: Bool = false
    /// 商品情報（取得済み）
    var product: Product?
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

    /// 無料ユーザーのカスタムタグ上限
    let freeCustomTagLimit = 10
    /// 商品ID
    static let removeAdsProductID = "com.imai.Nami.removeAds"

    /// トランザクション監視タスク
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - 初期化

    init() {
        // トランザクションの監視を開始
        updateListenerTask = listenForTransactions()
        // 起動時に購入状態を復元
        Task {
            await updatePurchasedStatus()
            await fetchProduct()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 商品取得

    /// App Store Connect から商品情報を取得する（最大3回リトライ）
    @MainActor
    func fetchProduct() async {
        productFetchFailed = false
        for attempt in 1...3 {
            do {
                let products = try await Product.products(for: [Self.removeAdsProductID])
                product = products.first
                productFetchFailed = product == nil
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

    // MARK: - 購入

    /// 広告除去を購入する
    @MainActor
    func purchase() async {
        guard let product else {
            errorMessage = String(localized: "商品情報を取得できませんでした")
            return
        }
        guard !isPurchasing else { return }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPremium = true
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
            // App Storeとの同期をリクエスト
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

    // MARK: - 内部ロジック

    /// 購入済みステータスを確認・更新する
    @MainActor
    private func updatePurchasedStatus() async {
        // 現在の全エンタイトルメントを確認
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsProductID {
                isPremium = true
                return
            }
        }
        isPremium = false
    }

    /// トランザクションの更新を監視する
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        if transaction.productID == PremiumManager.removeAdsProductID {
                            self.isPremium = true
                        }
                    }
                }
            }
        }
    }

    /// トランザクションの検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
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
