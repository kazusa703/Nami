//
//  RecordMoodIntent.swift
//  NamiWidget
//
//  ウィジェットからの気分記録用AppIntent
//

import AppIntents
import WidgetKit

/// ウィジェットのボタンタップで気分スコアを記録するIntent
/// Writes to App Group UserDefaults queue; main app imports on next launch.
struct RecordMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "気分を記録"
    static var description: IntentDescription = "ウィジェットから気分スコアを直接記録します"

    /// 記録するスコア
    @Parameter(title: "スコア")
    var score: Int

    init() {
        score = 5
    }

    init(score: Int) {
        self.score = score
    }

    func perform() async throws -> some IntentResult {
        // スコア範囲をApp Group UserDefaultsから取得
        let defaults = WidgetConstants.sharedUserDefaults
        let storedMax = defaults.integer(forKey: WidgetConstants.scoreRangeMaxKey)
        let maxScore = storedMax > 0 ? storedMax : 10
        let storedMin = defaults.integer(forKey: WidgetConstants.scoreRangeMinKey)
        let scoreRangeMin = storedMin != 0 ? storedMin : 1

        // Write to UserDefaults queue instead of SwiftData
        let record = PendingMoodRecord(
            score: score,
            maxScore: maxScore,
            scoreRangeMin: scoreRangeMin,
            createdAt: .now,
            id: UUID()
        )
        var pending = defaults.pendingWidgetRecords
        pending.append(record)
        defaults.pendingWidgetRecords = pending

        // ウィジェットのタイムラインを更新
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
