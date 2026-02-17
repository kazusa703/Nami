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
struct BannerAdView: View {
    @Environment(\.premiumManager) private var premiumManager

    var body: some View {
        if !premiumManager.isPremium {
            AdBannerRepresentable(adUnitID: AdUnitID.current)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        }
    }
}

// MARK: - BannerView ラッパー

/// Google AdMob バナー広告の UIViewRepresentable ラッパー
struct AdBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
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
}
