//
//  RecordMoodIntent.swift
//  NamiWidget
//
//  ウィジェットからの気分記録用AppIntent
//

import AppIntents
import SwiftData
import WidgetKit

/// ウィジェットのボタンタップで気分スコアを記録するIntent
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
        // 書き込み可能なModelContainerを使用
        guard let container = makeWritableSharedModelContainer() else {
            return .result()
        }

        let context = ModelContext(container)

        // スコア範囲をApp Group UserDefaultsから取得
        let storedMax = WidgetConstants.sharedUserDefaults.integer(forKey: WidgetConstants.scoreRangeMaxKey)
        let maxScore = storedMax > 0 ? storedMax : 10
        let minScore = WidgetConstants.sharedUserDefaults.object(forKey: WidgetConstants.scoreRangeMinKey) as? Int ?? 1

        // source = "widget" で新規エントリを作成
        let entry = MoodEntry(score: score, maxScore: maxScore, minScore: minScore, source: "widget")
        context.insert(entry)

        do {
            try context.save()
        } catch {
            print("RecordMoodIntent: Failed to save mood entry: \(error)")
        }

        // ウィジェットのタイムラインを更新
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
