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
    /// UserDefaultsキー：スコア範囲上限（旧キー、ウィジェット互換用に引き続き書き込む）
    static let scoreRangeMaxKey = "scoreRangeMax"
    /// UserDefaultsキー：スコア範囲下限（App Group共有用）
    static let scoreRangeMinKey = "scoreRangeMin"
    /// UserDefaultsキー：スコアレンジID（新キー: ScoreRange.rawValue を保存）
    static let scoreRangeKey = "scoreRange"
    /// UserDefaultsキー：スコア入力方式
    static let scoreInputTypeKey = "scoreInputType"

    /// UserDefaultsキー：オンボーディング完了フラグ
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    /// iCloudコンテナの識別子
    static let iCloudContainerIdentifier = "iCloud.com.imai.Nami"

    /// UserDefaultsキー：ウィジェットからの未取り込みレコードキュー
    static let pendingWidgetRecordsKey = "pendingWidgetRecords"
}

// MARK: - Pending Widget Record

/// Widget records mood data to UserDefaults; main app imports on launch
struct PendingMoodRecord: Codable {
    let score: Int
    let maxScore: Int
    let scoreRangeMin: Int
    let createdAt: Date
    let id: UUID
}

extension UserDefaults {
    /// Queue of mood records written by the widget, pending import by the main app
    var pendingWidgetRecords: [PendingMoodRecord] {
        get {
            guard let data = data(forKey: AppConstants.pendingWidgetRecordsKey) else { return [] }
            return (try? JSONDecoder().decode([PendingMoodRecord].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: AppConstants.pendingWidgetRecordsKey)
        }
    }
}

/// スコア範囲のプリセット（8パターン: 正のみ4 + 負あり4）
enum ScoreRange: String, CaseIterable, Identifiable {
    case pos10
    case pos30
    case pos50
    case pos100
    case neg10
    case neg30
    case neg50
    case neg100

    var id: String {
        rawValue
    }

    /// スコアの最小値
    var minValue: Int {
        switch self {
        case .pos10, .pos30, .pos50, .pos100: return 1
        case .neg10: return -10
        case .neg30: return -30
        case .neg50: return -50
        case .neg100: return -100
        }
    }

    /// スコアの最大値
    var maxValue: Int {
        switch self {
        case .pos10, .neg10: return 10
        case .pos30, .neg30: return 30
        case .pos50, .neg50: return 50
        case .pos100, .neg100: return 100
        }
    }

    /// 負の値を持つかどうか
    var isNegative: Bool {
        minValue < 0
    }

    /// 正のみパターンか
    var isPositiveOnly: Bool {
        !isNegative
    }

    /// 正のみのパターン一覧
    static var positiveRanges: [ScoreRange] {
        [.pos10, .pos30, .pos50, .pos100]
    }

    /// 負ありのパターン一覧
    static var negativeRanges: [ScoreRange] {
        [.neg10, .neg30, .neg50, .neg100]
    }

    /// 表示名
    var displayName: String {
        switch self {
        case .pos10: return String(localized: "1〜10")
        case .pos30: return String(localized: "1〜30")
        case .pos50: return String(localized: "1〜50")
        case .pos100: return String(localized: "1〜100")
        case .neg10: return String(localized: "-10〜10")
        case .neg30: return String(localized: "-30〜30")
        case .neg50: return String(localized: "-50〜50")
        case .neg100: return String(localized: "-100〜100")
        }
    }

    /// 説明
    var description: String {
        switch self {
        case .pos10: return String(localized: "シンプル（正のみ）")
        case .pos30: return String(localized: "標準（正のみ）")
        case .pos50: return String(localized: "詳細（正のみ）")
        case .pos100: return String(localized: "超詳細（正のみ）")
        case .neg10: return String(localized: "シンプル（負あり）")
        case .neg30: return String(localized: "標準（負あり）")
        case .neg50: return String(localized: "詳細（負あり）")
        case .neg100: return String(localized: "超詳細（負あり）")
        }
    }

    /// カテゴリ名
    var categoryName: String {
        isNegative ? String(localized: "負あり") : String(localized: "正のみ")
    }

    /// 旧 scoreRangeMax (Int) → 新 ScoreRange に変換
    static func migrateFromMax(_ maxScore: Int) -> ScoreRange {
        switch maxScore {
        case 10: return .pos10
        case 30: return .pos30
        case 100: return .pos100
        default: return .pos10
        }
    }

    /// App Group UserDefaults から現在のレンジを読み取る
    static func current(from defaults: UserDefaults = AppConstants.sharedUserDefaults) -> ScoreRange {
        // 新キーを優先
        if let raw = defaults.string(forKey: AppConstants.scoreRangeKey),
           let range = ScoreRange(rawValue: raw)
        {
            return range
        }
        // 旧キーからマイグレーション
        let oldMax = defaults.integer(forKey: AppConstants.scoreRangeMaxKey)
        if oldMax > 0 {
            return migrateFromMax(oldMax)
        }
        return .pos10
    }

    /// UserDefaults に保存する（標準 + App Group + 旧キー互換）
    func save(to defaults: UserDefaults = AppConstants.sharedUserDefaults) {
        // 新キー
        defaults.set(rawValue, forKey: AppConstants.scoreRangeKey)
        UserDefaults.standard.set(rawValue, forKey: AppConstants.scoreRangeKey)
        // 旧キー互換（ウィジェットが scoreRangeMax を読むため）
        defaults.set(maxValue, forKey: AppConstants.scoreRangeMaxKey)
        UserDefaults.standard.set(maxValue, forKey: AppConstants.scoreRangeMaxKey)
        // scoreRangeMin もApp Groupに書き込む
        defaults.set(minValue, forKey: AppConstants.scoreRangeMinKey)
        UserDefaults.standard.set(minValue, forKey: AppConstants.scoreRangeMinKey)
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
