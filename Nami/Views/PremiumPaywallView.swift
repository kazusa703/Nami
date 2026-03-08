//
//  PremiumPaywallView.swift
//  Nami
//
//  Unified premium paywall — 2-screen flow:
//  Page 1: Feature benefits + fixed bottom CTA
//  Page 2: Plan selection + purchase
//

import StoreKit
import SwiftUI

/// Full-screen premium paywall presented as a sheet
/// Single-page design: benefits + plan selection + purchase on one screen
struct PremiumPaywallView: View {
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// Inline mode: displayed inside a tab (no dismiss button, no auto-dismiss on purchase)
    var isInline: Bool = false

    @State private var headerAppeared = false
    @State private var benefitsAppeared = false
    /// Selected plan index: 0=monthly, 1=yearly, 2=lifetime
    @State private var selectedPlanIndex = 1
    @State private var showSuccessAlert = false

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection(colors: colors)

                        benefitsSection(colors: colors)
                            .padding(.top, 24)

                        // Plan selection
                        planSelectionSection(colors: colors)
                            .padding(.top, 24)

                        if !availablePlans().isEmpty {
                            trustSection(colors: colors)
                                .padding(.top, 16)
                        }

                        footerSection()
                            .padding(.top, 24)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !availablePlans().isEmpty {
                    purchaseBottomBar(colors: colors)
                } else {
                    loadingBottomBar(colors: colors)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    headerAppeared = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                    benefitsAppeared = true
                }
            }
            .toolbar {
                if !isInline {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color(.systemGray5)))
                        }
                    }
                }
            }
        }
        .onChange(of: premiumManager.isPremium) { _, isPremium in
            if isPremium, !isInline { dismiss() }
        }
        .onChange(of: premiumManager.showPurchaseSuccess) { _, newValue in
            if newValue {
                showSuccessAlert = true
                premiumManager.showPurchaseSuccess = false
            }
        }
        .alert("購入完了", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("プレミアムへのアップグレードありがとうございます！")
        }
        .interactiveDismissDisabled(premiumManager.isPurchasing)
    }

    // MARK: - Header

    private func headerSection(colors: ThemeColors) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(colors.accent.opacity(0.08))
                    .frame(width: 96, height: 96)
                    .scaleEffect(headerAppeared ? 1 : 0.5)
                    .opacity(headerAppeared ? 1 : 0)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [colors.accent, colors.accent.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: colors.accent.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(headerAppeared ? 1 : 0.6)
                    .opacity(headerAppeared ? 1 : 0)
            }
            .padding(.top, 8)

            Text("Nami PRO")
                .font(.system(.title, design: .rounded, weight: .bold))
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 10)

            Text("波をもっと深く読む")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 10)
        }
    }

    // MARK: - Benefits

    @ViewBuilder
    private func benefitsSection(colors: ThemeColors) -> some View {
        let items: [(icon: String, title: String, subtitle: String)] = [
            ("eye.slash", "広告なしのすっきり画面", "バナー・全画面広告が消え、記録だけに集中できる"),
            ("tag", "カスタムタグ無制限", "20個の制限なし。自分だけの感情を細かく分類"),
            ("cloud.sun", "天気と気分の自動連携", "天気・気温・気圧を自動記録し、体調との相関を発見"),
            ("chart.bar.xaxis", "タグ影響度分析", "どのタグが気分にどれだけ影響しているか数値で確認"),
            ("arrow.triangle.branch", "連鎖・シナジー分析", "タグの組み合わせ効果や連鎖パターンを可視化"),
            ("arrow.uturn.up", "回復トリガー", "気分が落ちた後、何がきっかけで回復したか特定"),
            ("doc.text", "月間レポート", "1ヶ月の気分の波をレポートで振り返り"),
            ("exclamationmark.triangle", "乖離アラート", "行動と気分のズレを検知し、無理をしていないかチェック"),
        ]

        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                benefitRow(
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    colors: colors
                )
                .opacity(benefitsAppeared ? 1 : 0)
                .offset(x: benefitsAppeared ? 0 : -20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05),
                    value: benefitsAppeared
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colors.accent.opacity(0.05))
        )
    }

    private func benefitRow(icon: String, title: String, subtitle: String, colors: ThemeColors) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(colors.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(colors.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Plan Selection

    @ViewBuilder
    private func planSelectionSection(colors: ThemeColors) -> some View {
        let plans = availablePlans()

        VStack(spacing: 8) {
            Text("プランを選ぶ")
                .font(.system(.headline, design: .rounded, weight: .bold))

            Text("すべてのプランで全PRO機能が使えます")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)

        if plans.isEmpty {
            if premiumManager.productFetchFailed {
                VStack(spacing: 8) {
                    Text("商品情報の取得に失敗しました")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await premiumManager.fetchProducts() }
                    } label: {
                        Label("再読み込み", systemImage: "arrow.clockwise")
                            .font(.system(.caption, design: .rounded))
                    }
                }
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("プランを読み込み中...")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(Array(plans.enumerated()), id: \.offset) { _, plan in
                    planCard(
                        plan: plan,
                        isSelected: selectedPlanIndex == plan.sortIndex,
                        colors: colors
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlanIndex = plan.sortIndex
                        }
                        HapticManager.lightFeedback()
                    }
                }
            }
        }
    }

    private func planCard(plan: PlanInfo, isSelected: Bool, colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(plan.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))

                if let savings = plan.savingsLabel {
                    Text(savings)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(plan.sortIndex == 2 ? .orange : colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill((plan.sortIndex == 2 ? Color.orange : colors.accent).opacity(0.12))
                        )
                }

                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(plan.billedAmount)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(plan.billedPeriod)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let monthly = plan.monthlyEquivalent {
                Text(monthly)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Text(plan.description)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? colors.accent.opacity(0.06) : Color(.systemBackground).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSelected ? colors.accent : Color(.systemGray4).opacity(0.5),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if let badge = plan.badge {
                Text(badge)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(colors.accent))
                    .offset(x: -8, y: -10)
            }
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }

    // MARK: - Trust Signals

    private func trustSection(colors: ThemeColors) -> some View {
        VStack(spacing: 8) {
            if selectedPlanIndex != 2 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.accent)
                    Text("いつでもキャンセル可能・自動更新")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if selectedPlanIndex == 2 {
                HStack(spacing: 6) {
                    Image(systemName: "infinity")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("一度きりの購入・自動更新なし")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Apple IDで安全に管理")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(billingDescription())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Bottom Purchase Bar

    private func purchaseBottomBar(colors: ThemeColors) -> some View {
        VStack(spacing: 6) {
            Button {
                guard let product = selectedProduct() else { return }
                Task { await premiumManager.purchase(product) }
            } label: {
                HStack(spacing: 8) {
                    if premiumManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaText())
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [colors.accent, colors.accent.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: colors.accent.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(premiumManager.isPurchasing || premiumManager.products.isEmpty)

            if let error = premiumManager.errorMessage {
                Text(error)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.red)
                    .task {
                        try? await Task.sleep(for: .seconds(5))
                        premiumManager.errorMessage = nil
                    }
            }

            if premiumManager.productFetchFailed {
                Button {
                    Task { await premiumManager.fetchProducts() }
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func loadingBottomBar(colors _: ThemeColors) -> some View {
        VStack(spacing: 10) {
            Button {
                Task { await premiumManager.restore() }
            } label: {
                HStack(spacing: 4) {
                    if premiumManager.isRestoring {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Text("購入を復元")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(premiumManager.isRestoring)

            if let error = premiumManager.errorMessage {
                Text(error)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.red)
                    .task {
                        try? await Task.sleep(for: .seconds(5))
                        premiumManager.errorMessage = nil
                    }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Footer

    private func footerSection() -> some View {
        VStack(spacing: 12) {
            Button {
                Task { await premiumManager.restore() }
            } label: {
                HStack(spacing: 4) {
                    if premiumManager.isRestoring {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Text("購入を復元")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(premiumManager.isRestoring || premiumManager.isPurchasing)

            HStack(spacing: 16) {
                Link("利用規約", destination: URL(string: "https://kazusa703.github.io/nami-support/ja/terms.html")!)
                Text("・").foregroundStyle(.quaternary)
                Link("プライバシーポリシー", destination: URL(string: "https://kazusa703.github.io/nami-support/ja/privacy.html")!)
            }
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Data Helpers

    private struct PlanInfo {
        let sortIndex: Int
        let title: String
        let billedAmount: String
        let billedPeriod: String
        let monthlyEquivalent: String?
        let description: String
        let badge: String?
        let savingsLabel: String?
        let product: Product
    }

    private func availablePlans() -> [PlanInfo] {
        var plans: [PlanInfo] = []

        if let monthly = premiumManager.product(for: PremiumManager.monthlyProductID) {
            plans.append(PlanInfo(
                sortIndex: 0,
                title: "月額プラン",
                billedAmount: monthly.displayPrice,
                billedPeriod: " / 月",
                monthlyEquivalent: nil,
                description: "自動更新・いつでもキャンセル可能",
                badge: nil,
                savingsLabel: nil,
                product: monthly
            ))
        }

        if let yearly = premiumManager.product(for: PremiumManager.yearlyProductID) {
            let monthlyEquiv = monthlyEquivalent(yearly: yearly)
            let savings = savingsPercent(monthly: premiumManager.product(for: PremiumManager.monthlyProductID), yearly: yearly)

            plans.append(PlanInfo(
                sortIndex: 1,
                title: "年額プラン",
                billedAmount: yearly.displayPrice,
                billedPeriod: " / 年",
                monthlyEquivalent: "月あたり約\(monthlyEquiv)",
                description: "自動更新・いつでもキャンセル可能",
                badge: "おすすめ",
                savingsLabel: savings,
                product: yearly
            ))
        }

        if let lifetime = premiumManager.product(for: PremiumManager.lifetimeProductID) {
            plans.append(PlanInfo(
                sortIndex: 2,
                title: "永久プラン（買い切り）",
                billedAmount: lifetime.displayPrice,
                billedPeriod: "（一度きり）",
                monthlyEquivalent: nil,
                description: "全PRO機能を永久に利用（将来の追加機能も含む）",
                badge: nil,
                savingsLabel: "自動更新なし",
                product: lifetime
            ))
        }

        return plans
    }

    private func monthlyEquivalent(yearly: Product) -> String {
        let yearlyPrice = yearly.price
        let monthlyPrice = yearlyPrice / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = yearly.priceFormatStyle.locale
        formatter.maximumFractionDigits = 0
        return formatter.string(from: monthlyPrice as NSDecimalNumber) ?? ""
    }

    private func savingsPercent(monthly: Product?, yearly: Product) -> String? {
        guard let monthly else { return nil }
        let yearOfMonthly = monthly.price * 12
        guard yearOfMonthly > 0 else { return nil }
        let savings = ((yearOfMonthly - yearly.price) / yearOfMonthly * 100) as NSDecimalNumber
        let percent = savings.intValue
        guard percent > 0 else { return nil }
        return "\(percent)%OFF"
    }

    private func selectedProduct() -> Product? {
        switch selectedPlanIndex {
        case 0: return premiumManager.product(for: PremiumManager.monthlyProductID)
        case 1: return premiumManager.product(for: PremiumManager.yearlyProductID)
        case 2: return premiumManager.product(for: PremiumManager.lifetimeProductID)
        default: return nil
        }
    }

    private func ctaText() -> String {
        switch selectedPlanIndex {
        case 0: return "月額プランで始める"
        case 1: return "年額プランで始める"
        case 2: return "買い切りで購入"
        default: return "PROを始める"
        }
    }

    private func billingDescription() -> String {
        guard let product = selectedProduct() else { return "" }
        switch selectedPlanIndex {
        case 0:
            return "毎月 \(product.displayPrice) が自動更新されます。Apple IDに紐付けられ、設定から管理できます。"
        case 1:
            return "年額 \(product.displayPrice) が自動更新されます。Apple IDに紐付けられ、設定から管理できます。"
        case 2:
            return "一度の購入で全PRO機能が永久に使えます。サブスクリプションではないため自動更新はありません。"
        default:
            return ""
        }
    }
}

#Preview {
    PremiumPaywallView()
        .environment(\.premiumManager, PremiumManager())
        .environment(\.themeManager, ThemeManager())
}
