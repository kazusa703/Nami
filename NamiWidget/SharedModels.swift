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
    static let scoreRangeKey = "scoreRange"
    static let pendingWidgetRecordsKey = "pendingWidgetRecords"

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
    var scoreRangeMin: Int = 1
    var photoPath: String?
    var voiceMemoPath: String?
    var tags: [String] = []
    var source: String = "app" // 記録元: "app", "widget", "watch"
    var energyLevel: Int? // 1=低, 2=普通, 3=高, nil=スキップ
    var weatherCondition: String? // "sunny","cloudy","rainy","snowy","stormy","foggy"
    var weatherTemperature: Double? // 摂氏

    init(score: Int, maxScore: Int = 10, scoreRangeMin: Int = 1, memo: String? = nil, tags: [String] = [], source: String = "app", createdAt: Date = .now) {
        id = UUID()
        self.score = score
        self.maxScore = maxScore
        self.scoreRangeMin = scoreRangeMin
        self.memo = memo
        self.tags = tags
        self.source = source
        self.createdAt = createdAt
    }

    /// 0.0〜1.0に正規化したスコア
    var normalizedScore: Double {
        let range = maxScore - scoreRangeMin
        guard range > 0 else { return 1.0 }
        return Double(score - scoreRangeMin) / Double(range)
    }

    /// 指定レンジにスケーリングしたスコアを返す
    func scaledScore(to targetMax: Int, targetMin: Int = 1) -> Double {
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
            guard let data = data(forKey: WidgetConstants.pendingWidgetRecordsKey) else { return [] }
            return (try? JSONDecoder().decode([PendingMoodRecord].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: WidgetConstants.pendingWidgetRecordsKey)
        }
    }
}
