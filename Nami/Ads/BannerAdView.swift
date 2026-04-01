//
//  BannerAdView.swift
//  Nami
//
//  Rewarded ad manager for tag slot expansion + legacy stub
//

import GoogleMobileAds
import SwiftUI

// MARK: - Ad Unit IDs

enum AdUnitID {
    static let rewarded = "ca-app-pub-9569882864362674/2460855459"
    static let rewardedTest = "ca-app-pub-3940256099942544/1712485313"

    static var currentRewarded: String {
        #if DEBUG
            return rewardedTest
        #else
            return rewarded
        #endif
    }
}

// MARK: - Stub BannerAdView (legacy compatibility)

/// Stub view — banner ads have been removed from the app
struct BannerAdView: View {
    var body: some View {
        EmptyView()
    }
}

// MARK: - Rewarded Ad Manager

@MainActor
@Observable
final class RewardedAdManager: NSObject {
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    var isAdReady: Bool {
        rewardedAd != nil
    }

    var onRewardEarned: (() -> Void)?

    /// Preload a rewarded ad
    func loadAd() {
        #if DEBUG
            return
        #endif
        guard !isLoading, rewardedAd == nil else { return }
        isLoading = true

        RewardedAd.load(with: AdUnitID.currentRewarded) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Rewarded ad load error: \(error.localizedDescription)")
                    return
                }
                self.rewardedAd = ad
            }
        }
    }

    /// Show the rewarded ad. Calls onRewardEarned on success.
    func showAd() {
        #if DEBUG
            // In DEBUG, simulate reward without showing ad
            onRewardEarned?()
            return
        #endif
        guard let ad = rewardedAd else { return }

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        guard let rootVC = scene?.windows.first?.rootViewController else { return }

        ad.present(from: rootVC) { [weak self] in
            self?.onRewardEarned?()
        }
        rewardedAd = nil
        loadAd()
    }
}

// MARK: - LimitReachedView

/// Modal shown when user hits custom tag limit
/// Offers: Pro upgrade or watch rewarded ad
struct LimitReachedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.colorScheme) private var colorScheme

    let rewardedAdManager: RewardedAdManager
    let onRewardUnlocked: () -> Void

    /// Show ProView sheet
    @State private var showProView = false

    var body: some View {
        let colors = themeManager.colors

        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // Icon
            ZStack {
                Circle()
                    .fill(colors.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "tag.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(colors.accent)
            }
            .padding(.bottom, 16)

            // Title
            Text(String(localized: "タグ枠がいっぱいです"))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .padding(.bottom, 6)

            // Description
            Text(String(localized: "カスタムタグの上限に達しました。\n枠を増やすには以下の方法があります。"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)

            // Option A: Pro upgrade
            Button {
                showProView = true
                HapticManager.lightFeedback()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Nami Proにアップグレード"))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        Text(String(localized: "タグ無制限 + 全履歴 + すべての機能"))
                            .font(.system(.caption2, design: .rounded))
                            .opacity(0.85)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [colors.accent, colors.accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: colors.accent.opacity(0.3), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Divider with "or"
            HStack {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 0.5)
                Text(String(localized: "または"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)

            // Option B: Watch rewarded ad
            Button {
                rewardedAdManager.onRewardEarned = {
                    premiumManager.unlockTagWithReward()
                    onRewardUnlocked()
                    dismiss()
                }
                rewardedAdManager.showAd()
                HapticManager.lightFeedback()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "動画広告を見て枠を1つ追加"))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text(String(localized: "短い動画を見ると、タグ枠が1つ増えます"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(colors.accent)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Cancel
            Button {
                dismiss()
            } label: {
                Text(String(localized: "あとで"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showProView) {
            NavigationStack {
                ProView()
            }
        }
    }
}
