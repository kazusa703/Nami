//
//  SharedModels.swift
//  NamiWidget
//
//  メインアプリと共有するモデル定義
//

import Foundation
import SwiftData

/// App Groupの識別子
enum WidgetConstants {
    static let appGroupIdentifier = "group.com.imai.Nami"
    static let themeKey = "selectedTheme"
    static let scoreRangeMaxKey = "scoreRangeMax"
    static let scoreRangeMinKey = "scoreRangeMin"

    /// App Group共有のUserDefaults
    static var sharedUserDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// SwiftData共有ストアのURL
    static var sharedStoreURL: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return container.appendingPathComponent("Nami.store")
    }
}

/// 気分記録エントリ（ウィジェット用の複製）
/// メインアプリのMoodEntryと同じスキーマを持つ
@Model
class MoodEntry {
    var id: UUID = UUID()
    var score: Int = 5
    var memo: String?
    var createdAt: Date = Date.now
    var maxScore: Int = 10
    var photoPath: String?
    var voiceMemoPath: String?
    var tags: [String] = []
    var source: String = "app" // 記録元: "app", "widget", "watch"
    var minScore: Int = 1 // 記録時のスコア範囲下限（軽量マイグレーション対応）

    init(score: Int, maxScore: Int = 10, minScore: Int = 1, memo: String? = nil, tags: [String] = [], source: String = "app", createdAt: Date = .now) {
        id = UUID()
        let safeMax = max(2, maxScore)
        self.score = max(minScore, min(safeMax, score))
        self.maxScore = safeMax
        self.minScore = minScore
        self.memo = memo
        self.tags = tags
        self.source = source
        self.createdAt = createdAt
    }

    /// 0.0〜1.0に正規化したスコア
    var normalizedScore: Double {
        let range = maxScore - minScore
        guard range > 0 else { return 1.0 }
        return Double(score - minScore) / Double(range)
    }

    /// 指定レンジにスケーリングしたスコアを返す
    func scaledScore(to targetMax: Int, from targetMin: Int = 1) -> Double {
        return normalizedScore * Double(targetMax - targetMin) + Double(targetMin)
    }
}

/// ウィジェット用の読み取り専用ModelContainerを生成する
func makeSharedModelContainer() -> ModelContainer? {
    let schema = Schema([MoodEntry.self])
    let config = ModelConfiguration(
        schema: schema,
        url: WidgetConstants.sharedStoreURL,
        allowsSave: false // 読み取り専用
    )
    return try? ModelContainer(for: schema, configurations: [config])
}

/// ウィジェット用の書き込み可能なModelContainerを生成する
/// インタラクティブウィジェットからのスコア記録に使用
func makeWritableSharedModelContainer() -> ModelContainer? {
    let schema = Schema([MoodEntry.self])
    let config = ModelConfiguration(
        schema: schema,
        url: WidgetConstants.sharedStoreURL,
        allowsSave: true,
        cloudKitDatabase: .none // ウィジェットからはCloudKit同期しない
    )
    return try? ModelContainer(for: schema, configurations: [config])
}
