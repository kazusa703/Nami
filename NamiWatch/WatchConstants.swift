//
//  WatchConstants.swift
//  NamiWatch
//
//  Apple Watch用の共有定数
//

import Foundation

/// Watch側で使用する定数
enum WatchConstants {
    /// App Groupの識別子（iPhone/Watch共通）
    static let appGroupIdentifier = "group.com.imai.Nami"

    /// App Group共有のUserDefaults
    static var sharedUserDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// UserDefaultsキー：スコア範囲上限
    static let scoreRangeMaxKey = "scoreRangeMax"

    /// UserDefaultsキー：選択テーマ
    static let themeKey = "selectedTheme"
}
