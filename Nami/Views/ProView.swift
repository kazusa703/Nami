//
//  ProView.swift
//  Nami
//
//  Premium feature showcase + plan selection paywall screen
//

import StoreKit
import SwiftUI

struct ProView: View {
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPlan: PremiumPlan = .yearly
    @State private var showPurchaseSuccessAlert = false
    @State private var showProHelp = false

    var body: some View {
        let colors = themeManager.colors

        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection(colors: colors)

                // Feature list
                featureListSection(colors: colors)

                // Help button for PRO feature details
                Button { showProHelp = true } label: {
                    Label(String(localized: "PRO機能の詳細"), systemImage: "questionmark.circle")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(premiumManager.isPremium ? colors.accent : .secondary)
                }

                if !premiumManager.isPremium {
                    // Plan selection
                    planSelectionSection(colors: colors)

                    // Purchase button
                    purchaseButton(colors: colors)

                    // Restore button
                    Button {
                        Task { await premiumManager.restore() }
                    } label: {
                        Text(String(localized: "購入を復元"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .disabled(premiumManager.isRestoring || premiumManager.isPurchasing)

                    // Error message
                    if let error = premiumManager.errorMessage {
                        Text(error)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                // Footer
                footerSection()

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .alert(String(localized: "購入完了"), isPresented: $showPurchaseSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(String(localized: "プレミアムへのアップグレードありがとうございます！"))
        }
        .onChange(of: premiumManager.showPurchaseSuccess) { _, newValue in
            if newValue {
                showPurchaseSuccessAlert = true
                premiumManager.showPurchaseSuccess = false
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

                Text(String(localized: "すべての機能が解放されています"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Nami Premium")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text(String(localized: "すべての機能を解放"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Feature List

    @ViewBuilder
    private func featureListSection(colors: ThemeColors) -> some View {
        let features: [(icon: String, text: String, free: Bool)] = [
            ("pencil.circle", String(localized: "気分記録・基本チャート"), true),
            ("calendar.badge.clock", String(localized: "直近30日の履歴"), true),
            ("clock.arrow.circlepath", String(localized: "全履歴の無制限アクセス"), false),
            ("tag.fill", String(localized: "無制限のカスタムタグ作成"), false),
            ("lightbulb.fill", String(localized: "パーソナルインサイト"), false),
            ("brain.head.profile", String(localized: "AIスコア予測"), false),
            ("arrow.triangle.branch", String(localized: "タグ遷移マップ"), false),
            ("chart.bar.doc.horizontal", String(localized: "高度な分析"), false),
            ("doc.text.fill", String(localized: "月間レポートカード"), false),
            ("heart.fill", String(localized: "HealthKit相関分析"), false),
        ]

        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(feature.free ? .green : (premiumManager.isPremium ? colors.accent : .orange))
                        .frame(width: 28)

                    Text(feature.text)
                        .font(.system(.subheadline, design: .rounded))

                    Spacer()

                    if feature.free {
                        Text(String(localized: "無料"))
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.green.opacity(0.1)))
                    } else if premiumManager.isPremium {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                    } else {
                        Text("PRO")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange.opacity(0.1)))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Plan Selection

    private func planSelectionSection(colors: ThemeColors) -> some View {
        VStack(spacing: 12) {
            // Yearly (recommended)
            planCard(
                plan: .yearly,
                product: premiumManager.yearlyProduct,
                badge: String(localized: "おすすめ"),
                sublabel: String(localized: "/年"),
                colors: colors
            )

            // Lifetime
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
                                .background(Capsule().fill(.orange))
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
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .disabled(premiumManager.isPurchasing || selectedProduct == nil)
        .padding(.top, 8)
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
