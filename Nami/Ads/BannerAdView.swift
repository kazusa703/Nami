//
//  BannerAdView.swift
//  Nami
//
//  AdMob バナー広告
//  アプリID: ca-app-pub-9569882864362674~3306187437
//  パブリッシャーID: pub-9569882864362674
//

import GoogleMobileAds
import SwiftUI

/// AdMob safety layer — prevents accidental use of production ad IDs in development
///
/// ACCOUNT SUSPENSION PREVENTION:
/// 1. DEBUG builds ALWAYS use Google's official test Ad Unit ID (hardcoded, cannot be overridden)
/// 2. Production Ad Unit ID is only compiled into RELEASE builds
/// 3. Test device identifiers are registered in NamiApp.swift for additional safety
/// 4. This enum is the ONLY place where Ad Unit IDs should be defined
///
/// NEVER use production Ad Unit IDs outside of this enum.
/// NEVER remove the #if DEBUG guard.
enum AdUnitID {
    /// Google's official test banner ID — safe for unlimited impressions/clicks
    static let bannerTest = "ca-app-pub-3940256099942544/2435281174"

    /// Current Ad Unit ID (compile-time safe: test in DEBUG, production in RELEASE only)
    static var current: String {
        #if DEBUG
            // SAFETY: Always use test ID in development to prevent AdMob account suspension
            return bannerTest
        #else
            // Production Ad Unit ID — only used in App Store release builds
            return "ca-app-pub-9569882864362674/8847220935"
        #endif
    }
}

/// AdMob バナー広告ビュー
/// プレミアムユーザーの場合は非表示になる
/// 広告ロード失敗時は高さ0で非表示になる
struct BannerAdView: View {
    @Environment(\.premiumManager) private var premiumManager
    @State private var adLoaded = false

    var body: some View {
        if !premiumManager.isPremium {
            AdBannerRepresentable(adUnitID: AdUnitID.current, adLoaded: $adLoaded)
                .frame(height: adLoaded ? 50 : 0)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, adLoaded ? nil : 0)
                .clipped()
        }
    }
}

// MARK: - BannerView ラッパー

/// Google AdMob バナー広告の UIViewRepresentable ラッパー
struct AdBannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    @Binding var adLoaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(adLoaded: $adLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        return bannerView
    }

    func updateUIView(_ bannerView: BannerView, context _: Context) {
        // rootViewController が未設定なら設定して広告をロード
        if bannerView.rootViewController == nil {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            bannerView.rootViewController = scene?.windows.first?.rootViewController
            bannerView.load(Request())
        }
    }

    /// 広告のロード状態を監視するデリゲート
    class Coordinator: NSObject, BannerViewDelegate {
        @Binding var adLoaded: Bool

        init(adLoaded: Binding<Bool>) {
            _adLoaded = adLoaded
        }

        func bannerViewDidReceiveAd(_: BannerView) {
            withAnimation(.easeInOut(duration: 0.2)) {
                adLoaded = true
            }
        }

        func bannerView(_: BannerView, didFailToReceiveAdWithError _: Error) {
            withAnimation(.easeInOut(duration: 0.2)) {
                adLoaded = false
            }
        }
    }
}
