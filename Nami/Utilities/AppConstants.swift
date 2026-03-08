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
    /// UserDefaultsキー：スコア範囲下限
    static let scoreRangeMinKey = "scoreRangeMin"
    /// UserDefaultsキー：スコア範囲の最終変更日
    static let lastScoreRangeChangeDateKey = "lastScoreRangeChangeDate"

    /// iCloudコンテナの識別子
    static let iCloudContainerIdentifier = "iCloud.com.imai.Nami"
}

/// スコア範囲のプリセット
enum ScoreRange: String, CaseIterable, Identifiable {
    case ten
    case hundred
    case bipolar

    var id: String {
        rawValue
    }

    var minScore: Int {
        switch self {
        case .bipolar: return -10
        default: return 1
        }
    }

    var maxScore: Int {
        switch self {
        case .hundred: return 100
        default: return 10
        }
    }

    /// 表示名
    var displayName: String {
        switch self {
        case .ten: return String(localized: "1〜10")
        case .hundred: return String(localized: "1〜100")
        case .bipolar: return String(localized: "-10〜10")
        }
    }

    /// 説明
    var description: String {
        switch self {
        case .ten: return String(localized: "シンプル")
        case .hundred: return String(localized: "詳細")
        case .bipolar: return String(localized: "ネガティブ〜ポジティブ")
        }
    }

    /// UserDefaults の min/max 値から ScoreRange を復元
    static func from(min: Int, max: Int) -> ScoreRange {
        if min == -10 && max == 10 { return .bipolar }
        if max == 100 { return .hundred }
        return .ten
    }
}

/// スコア入力方式
enum ScoreInputType: String, CaseIterable, Identifiable {
    case buttons
    case slider

    var id: String {
        rawValue
    }

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
