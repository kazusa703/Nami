//
//  BannerAdView.swift
//  Nami
//
//  AdMob banner & interstitial ads
//

import GoogleMobileAds
import SwiftUI

/// Ad unit IDs
enum AdUnitID {
    static let banner = "ca-app-pub-9569882864362674/8547352931"
    static let bannerTest = "ca-app-pub-3940256099942544/2435281174"

    static let interstitial = "ca-app-pub-9569882864362674/9936456228"
    static let interstitialTest = "ca-app-pub-3940256099942544/4411468910"

    static var currentBanner: String {
        #if DEBUG
            return bannerTest
        #else
            return banner
        #endif
    }

    static var currentInterstitial: String {
        #if DEBUG
            return interstitialTest
        #else
            return interstitial
        #endif
    }
}

/// AdMob banner ad view (hidden for premium users)
struct BannerAdView: View {
    @Environment(\.premiumManager) private var premiumManager
    var showRemoveLink: Bool = false
    var onRemoveTap: (() -> Void)?

    var body: some View {
        if !premiumManager.isPremium {
            VStack(spacing: 4) {
                AdBannerRepresentable(adUnitID: AdUnitID.currentBanner)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                if showRemoveLink, let onRemoveTap {
                    Button {
                        onRemoveTap()
                    } label: {
                        Text("広告を非表示にする")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - BannerView wrapper

struct AdBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context _: Context) -> UIView {
        #if DEBUG
            return UIView() // Empty view in DEBUG to prevent ATT
        #else
            let bannerView = BannerView(adSize: AdSizeBanner)
            bannerView.adUnitID = adUnitID
            return bannerView
        #endif
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        #if !DEBUG
            guard let bannerView = uiView as? BannerView else { return }
            if bannerView.rootViewController == nil {
                let scene = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first
                bannerView.rootViewController = scene?.windows.first?.rootViewController
                bannerView.load(Request())
            }
        #endif
    }
}

// MARK: - Interstitial Ad Manager

@MainActor
@Observable
final class InterstitialAdManager {
    private var interstitialAd: InterstitialAd?
    private var isLoading = false
    private var recordCount: Int = 0
    private let showEvery: Int = 4

    /// Preload an interstitial ad
    func loadAd() {
        #if DEBUG
            return // Skip ad loading in DEBUG to avoid ATT dialog
        #endif
        guard !isLoading, interstitialAd == nil else { return }
        isLoading = true

        InterstitialAd.load(with: AdUnitID.currentInterstitial) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Interstitial load error: \(error.localizedDescription)")
                    return
                }
                self.interstitialAd = ad
            }
        }
    }

    /// Whether an interstitial was just shown (for post-ad prompt)
    var didShowAd = false

    /// Call after each recording. Shows interstitial every N recordings.
    func recordCompleted() {
        recordCount += 1
        didShowAd = false

        guard recordCount % showEvery == 0,
              let ad = interstitialAd
        else {
            if interstitialAd == nil { loadAd() }
            return
        }

        // Delay to avoid conflict with fullScreenCover dismiss animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            guard let rootVC = scene?.windows.first?.rootViewController,
                  rootVC.presentedViewController == nil
            else { return }

            ad.present(from: rootVC)
            self?.interstitialAd = nil
            self?.didShowAd = true
            self?.loadAd()
        }
    }
}
