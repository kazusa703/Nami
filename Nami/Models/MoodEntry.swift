//
//  MoodEntry.swift
//  Nami
//
//  気分記録のデータモデル
//

import Foundation
import SwiftData

/// 気分記録エントリ
/// スコア（1〜maxScore）、任意メモ、写真・ボイスメモパス、記録日時を保持する
@Model
class MoodEntry {
    var id: UUID = UUID()
    var score: Int = 5 // 1〜maxScore（1=最低、maxScore=最高）
    var memo: String? // 任意メモ（最大100文字）
    var createdAt: Date = Date.now // 記録日時
    var maxScore: Int = 10 // 記録時のスコア範囲（デフォルト10、軽量マイグレーション対応）
    var photoPath: String? // App Group内の写真相対パス
    var voiceMemoPath: String? // App Group内のボイスメモ相対パス
    var tags: [String] = [] // 感情タグ名の配列（軽量マイグレーション対応）
    var source: String = "app" // 記録元: "app", "widget", "watch"（軽量マイグレーション対応）
    var minScore: Int = 1 // 記録時のスコア範囲下限（軽量マイグレーション対応）

    // 天気データ（軽量マイグレーション対応：全てオプショナル）
    var weatherCondition: String? // 天気名（例: "晴れ", "曇り"）
    var weatherTemperature: Double? // 気温℃
    var weatherPressure: Double? // 気圧hPa
    var weatherHumidity: Double? // 湿度%
    var latitude: Double? // 記録地点の緯度
    var longitude: Double? // 記録地点の経度

    init(score: Int, maxScore: Int = 10, minScore: Int = 1, memo: String? = nil, photoPath: String? = nil, voiceMemoPath: String? = nil, tags: [String] = [], source: String = "app", createdAt: Date = .now) {
        id = UUID()
        let safeMax = max(2, maxScore)
        self.score = max(minScore, min(safeMax, score))
        self.maxScore = safeMax
        self.minScore = minScore
        self.memo = memo
        self.photoPath = photoPath
        self.voiceMemoPath = voiceMemoPath
        self.tags = tags
        self.source = source
        self.createdAt = createdAt
    }

    /// ウィジェットから記録され、メモ・タグ・写真・ボイスメモが未追加のエントリか
    var needsEnrichment: Bool {
        source == "widget" && memo == nil && tags.isEmpty && photoPath == nil && voiceMemoPath == nil
    }

    /// 0.0〜1.0に正規化したスコア（異なるレンジ間の比較用）
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
