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

    init(score: Int, maxScore: Int = 10, memo: String? = nil, tags: [String] = [], source: String = "app", createdAt: Date = .now) {
        self.id = UUID()
        self.score = score
        self.maxScore = maxScore
        self.memo = memo
        self.tags = tags
        self.source = source
        self.createdAt = createdAt
    }

    /// 0.0〜1.0に正規化したスコア
    var normalizedScore: Double {
        guard maxScore > 1 else { return 1.0 }
        return Double(score - 1) / Double(maxScore - 1)
    }

    /// 指定レンジにスケーリングしたスコアを返す
    func scaledScore(to targetMax: Int) -> Double {
        return normalizedScore * Double(targetMax - 1) + 1.0
    }
}

/// ウィジェット用の読み取り専用ModelContainerを生成する
func makeSharedModelContainer() -> ModelContainer? {
    let schema = Schema([MoodEntry.self])
    let config = ModelConfiguration(
        schema: schema,
        url: WidgetConstants.sharedStoreURL,
        allowsSave: false  // 読み取り専用
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
        cloudKitDatabase: .none  // ウィジェットからはCloudKit同期しない
    )
    return try? ModelContainer(for: schema, configurations: [config])
}
