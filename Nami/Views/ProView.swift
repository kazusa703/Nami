//
//  ProView.swift
//  Nami
//
//  Premium paywall — 3 highlights + plan selection + success animation
//

import StoreKit
import SwiftUI

struct ProView: View {
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PremiumPlan = .yearly
    @State private var showProHelp = false
    @State private var showSuccessAnimation = false
    @State private var expandedFAQ: String?

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            // Main content
            ScrollView {
                VStack(spacing: 32) {
                    // Header with wave animation
                    headerSection(colors: colors)

                    if premiumManager.isPremium {
                        // Already premium — show confirmation
                        premiumActiveSection(colors: colors)
                    } else {
                        // 3 Highlights
                        highlightsSection(colors: colors)

                        // Plan selection
                        planSelectionSection(colors: colors)

                        // Purchase button
                        purchaseButton(colors: colors)

                        // Restore + Error
                        restoreSection()
                    }

                    // PRO FAQ
                    proFAQSection()

                    // Help link
                    Button { showProHelp = true } label: {
                        Label(String(localized: "PRO機能の詳細"), systemImage: "questionmark.circle")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // Footer
                    footerSection()

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            // Success animation overlay
            if showSuccessAnimation {
                successOverlay(colors: colors)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSuccessAnimation)
        .onChange(of: premiumManager.showPurchaseSuccess) { _, newValue in
            if newValue {
                premiumManager.showPurchaseSuccess = false
                withAnimation {
                    showSuccessAnimation = true
                }
                HapticManager.successFeedback()
                // Auto-dismiss after 2.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showSuccessAnimation = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showProHelp) {
            FeatureHelpSheet(title: String(localized: "PRO機能"), items: HelpContent.proFeatureHelp, accentColor: themeManager.colors.accent)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(colors: ThemeColors) -> some View {
        if premiumManager.isPremium {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(colors.accent)

                Text(String(localized: "プレミアム会員"))
                    .font(.system(.title, design: .rounded, weight: .bold))

                if let plan = premiumManager.activePlan {
                    Text(plan.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(colors.accent)
                }
            }
            .padding(.vertical, 16)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "water.waves")
                    .font(.system(size: 64))
                    .foregroundStyle(colors.accent.gradient)
                    .symbolEffect(.variableColor.iterative, options: .repeating)

                Text("Nami Premium")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(colors.accent)

                Text(String(localized: "あなたの気分記録をもっと深く"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Premium Active

    private func premiumActiveSection(colors: ThemeColors) -> some View {
        VStack(spacing: 8) {
            Text(String(localized: "すべての機能が解放されています"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            Text(String(localized: "ご利用ありがとうございます"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(colors.accent.opacity(0.7))
        }
    }

    // MARK: - 3 Highlights

    private func highlightsSection(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            highlightCard(
                icon: "tag.fill",
                title: String(localized: "無制限のカスタマイズ"),
                description: String(localized: "タグ作り放題。あなただけの気分トラッキングを。"),
                colors: colors
            )
            highlightCard(
                icon: "sparkles",
                title: String(localized: "深いAIインサイト"),
                description: String(localized: "隠れた気分の波や、睡眠との相関をAIが解き明かします。"),
                colors: colors
            )
            highlightCard(
                icon: "leaf.fill",
                title: String(localized: "美しく、ノイズレス"),
                description: String(localized: "広告を非表示にして、より洗練された心地よい空間へ。"),
                colors: colors
            )
        }
    }

    private func highlightCard(icon: String, title: String, description: String, colors: ThemeColors) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(colors.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(colors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Plan Selection

    private func planSelectionSection(colors: ThemeColors) -> some View {
        VStack(spacing: 12) {
            planCard(
                plan: .yearly,
                product: premiumManager.yearlyProduct,
                badge: String(localized: "おすすめ"),
                sublabel: String(localized: "/年"),
                colors: colors
            )

            planCard(
                plan: .lifetime,
                product: premiumManager.lifetimeProduct,
                badge: String(localized: "一度きり"),
                sublabel: String(localized: "買い切り"),
                colors: colors
            )
        }
    }

    @ViewBuilder
    private func planCard(
        plan: PremiumPlan,
        product: Product?,
        badge: String?,
        sublabel: String,
        colors: ThemeColors
    ) -> some View {
        let isSelected = selectedPlan == plan

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = plan
            }
            HapticManager.lightFeedback()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.displayName)
                            .font(.system(.headline, design: .rounded))

                        if let badge {
                            Text(badge)
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(colors.accent))
                                .foregroundStyle(.white)
                        }
                    }

                    if let product {
                        Text(product.displayPrice + sublabel)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("---")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? colors.accent : .secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? colors.accent.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? colors.accent : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(product == nil)
    }

    // MARK: - Purchase Button

    @ViewBuilder
    private func purchaseButton(colors _: ThemeColors) -> some View {
        let selectedProduct: Product? = {
            switch selectedPlan {
            case .yearly: return premiumManager.yearlyProduct
            case .lifetime: return premiumManager.lifetimeProduct
            }
        }()

        Button {
            guard let selectedProduct else { return }
            Task { await premiumManager.purchase(product: selectedProduct) }
        } label: {
            HStack(spacing: 10) {
                if premiumManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(String(localized: "プランを選んで購入"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)
            )
        }
        .disabled(premiumManager.isPurchasing || selectedProduct == nil)
    }

    // MARK: - Restore

    private func restoreSection() -> some View {
        VStack(spacing: 8) {
            Button {
                Task { await premiumManager.restore() }
            } label: {
                if premiumManager.isRestoring {
                    ProgressView()
                } else {
                    Text(String(localized: "購入を復元"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(premiumManager.isRestoring || premiumManager.isPurchasing)

            if let error = premiumManager.errorMessage {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - PRO FAQ

    private func proFAQSection() -> some View {
        let faqs: [(id: String, q: String, a: String)] = [
            (
                "diff",
                String(localized: "無料版との違いは何ですか？"),
                String(localized: "PRO版では、無制限の過去データ閲覧、高度なAIインサイト（逆インサイト・タグ連鎖・回復トリガー等）、無制限のカスタムタグ作成、HealthKit詳細分析、月間レポートなどすべての機能が解放されます。")
            ),
            (
                "cancel",
                String(localized: "解約方法は？自動更新されますか？"),
                String(localized: "年額サブスクリプションは期間終了の24時間前までに解除しない限り自動更新されます。解約はiPhoneの「設定」→ [ユーザー名] →「サブスクリプション」から行えます。買い切りプランは一度の購入で永久に利用できます。")
            ),
            (
                "restore",
                String(localized: "機種変更時の購入の復元方法は？"),
                String(localized: "この画面にある「購入を復元」ボタンをタップするだけで、同じApple IDであれば追加費用なしで以前の購入状態を引き継げます。")
            ),
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "よくある質問"))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                ForEach(faqs, id: \.id) { faq in
                    let isExpanded = expandedFAQ == faq.id

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedFAQ = isExpanded ? nil : faq.id
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .padding(.top, 2)

                                Text(faq.q)
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 4)
                            }
                            .padding(.vertical, 12)

                            if isExpanded {
                                Text(faq.a)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.leading, 24)
                                    .padding(.bottom, 12)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if faq.id != faqs.last?.id {
                        Divider().padding(.horizontal, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.orange.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Footer

    private func footerSection() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link(String(localized: "利用規約"),
                     destination: URL(string: "https://kazusa703.github.io/nami-support/ja/terms.html")!)
                    .font(.system(.caption, design: .rounded))

                Link(String(localized: "プライバシーポリシー"),
                     destination: URL(string: "https://kazusa703.github.io/nami-support/ja/privacy.html")!)
                    .font(.system(.caption, design: .rounded))
            }

            Text(String(localized: "サブスクリプションはApple IDに紐付けられます"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Success Animation Overlay

    private func successOverlay(colors: ThemeColors) -> some View {
        ZStack {
            // Frosted glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(colors.accent)
                    .symbolEffect(.bounce, options: .nonRepeating)

                VStack(spacing: 8) {
                    Text("Nami Premium")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(colors.accent)

                    Text(String(localized: "ようこそ！"))
                        .font(.system(.title3, design: .rounded, weight: .semibold))

                    Text(String(localized: "すべての機能が解放されました"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccessAnimation)
        }
    }
}

// MARK: - Decimal helper

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

#Preview {
    ProView()
        .environment(\.premiumManager, PremiumManager())
        .environment(\.themeManager, ThemeManager())
}
