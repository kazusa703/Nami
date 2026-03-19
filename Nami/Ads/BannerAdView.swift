//
//  BannerAdView.swift
//  Nami
//
//  AdMob バナー広告
//  アプリID: ca-app-pub-9569882864362674~3306187437
//  パブリッシャーID: pub-9569882864362674
//

import SwiftUI
import GoogleMobileAds

/// 広告ユニットID
enum AdUnitID {
    /// バナー広告ユニットID（本番）
    static let banner = "ca-app-pub-9569882864362674/8847220935"

    /// テスト用バナー広告ID（デバッグ時に使用）
    static let bannerTest = "ca-app-pub-3940256099942544/2435281174"

    /// 現在使用する広告ID（DEBUGビルドではテストIDを使用）
    static var current: String {
        #if DEBUG
        return bannerTest
        #else
        return banner
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

    func updateUIView(_ bannerView: BannerView, context: Context) {
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

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            withAnimation(.easeInOut(duration: 0.2)) {
                adLoaded = true
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            withAnimation(.easeInOut(duration: 0.2)) {
                adLoaded = false
            }
        }
    }
}
