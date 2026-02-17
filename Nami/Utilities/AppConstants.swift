//
//  AppConstants.swift
//  Nami
//
//  App Group共有定数
//

import Foundation

/// アプリ全体で使用する定数
enum AppConstants {
    /// App Groupの識別子（メインアプリとウィジェットで共有）
    static let appGroupIdentifier = "group.com.imai.Nami"

    /// App Group共有のUserDefaults
    static var sharedUserDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// App Group共有コンテナのURL
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// SwiftData共有ストアのURL（App Groupコンテナ内）
    /// App Groupが利用可能な場合のみ有効なURLを返す
    static var sharedStoreURL: URL? {
        sharedContainerURL?.appendingPathComponent("Nami.store")
    }

    /// UserDefaultsキー：選択テーマ
    static let themeKey = "selectedTheme"
    /// UserDefaultsキー：スコア範囲上限
    static let scoreRangeMaxKey = "scoreRangeMax"
    /// UserDefaultsキー：スコア入力方式
    static let scoreInputTypeKey = "scoreInputType"
    /// UserDefaultsキー：スコア範囲の最終変更日
    static let lastScoreRangeChangeDateKey = "lastScoreRangeChangeDate"

    /// iCloudコンテナの識別子
    static let iCloudContainerIdentifier = "iCloud.com.imai.Nami"
}

/// スコア範囲のプリセット
enum ScoreRange: Int, CaseIterable, Identifiable {
    case ten = 10
    case thirty = 30
    case hundred = 100

    var id: Int { rawValue }

    /// 表示名
    var displayName: String {
        switch self {
        case .ten: return String(localized: "1〜10")
        case .thirty: return String(localized: "1〜30")
        case .hundred: return String(localized: "1〜100")
        }
    }

    /// 説明
    var description: String {
        switch self {
        case .ten: return String(localized: "シンプル")
        case .thirty: return String(localized: "細かめ")
        case .hundred: return String(localized: "詳細")
        }
    }
}

/// スコア入力方式
enum ScoreInputType: String, CaseIterable, Identifiable {
    case buttons = "buttons"
    case slider = "slider"

    var id: String { rawValue }

    /// 表示名
    var displayName: String {
        switch self {
        case .buttons: return String(localized: "ボタングリッド")
        case .slider: return String(localized: "スライダー")
        }
    }

    /// アイコン
    var iconName: String {
        switch self {
        case .buttons: return "square.grid.3x3"
        case .slider: return "slider.horizontal.3"
        }
    }
}
