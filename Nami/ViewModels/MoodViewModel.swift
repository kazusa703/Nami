//
//  MoodViewModel.swift
//  Nami
//
//  気分記録の保存ロジック
//

import SwiftData
import SwiftUI
import WidgetKit

/// 気分記録のビジネスロジックを管理するViewModel
@Observable
class MoodViewModel {
    /// 最後に記録したエントリ（メモ追加用に保持）
    var lastRecordedEntry: MoodEntry?
    /// 統合記録シートの表示状態
    var showRecordingSheet = false
    /// 記録完了アニメーション用フラグ
    var showRecordedAnimation = false
    /// 記録完了時に表示するスコア
    var recordedScore: Int = 0
    /// 記録時のmaxScore
    var recordedMaxScore: Int = 10
    /// 記録時のscoreRangeMin
    var recordedScoreRangeMin: Int = 1
    /// 連続タップ防止フラグ
    var isRecording = false

    /// 気分スコアを記録する
    /// - Parameters:
    ///   - score: 気分スコア（scoreRangeMin〜maxScore）
    ///   - maxScore: スコアの上限値
    ///   - scoreRangeMin: スコアの下限値
    ///   - context: SwiftDataのモデルコンテキスト
    ///   - weatherManager: 天気マネージャー（nilの場合は天気取得しない）
    func recordMood(score: Int, maxScore: Int = 10, scoreRangeMin: Int = 1, context: ModelContext, weatherManager: WeatherManager? = nil) {
        // 連続タップによる重複記録を防止
        guard !isRecording else { return }
        isRecording = true

        let entry = MoodEntry(score: score, maxScore: maxScore, scoreRangeMin: scoreRangeMin)
        context.insert(entry)
        lastRecordedEntry = entry
        recordedScore = score
        recordedMaxScore = maxScore
        recordedScoreRangeMin = scoreRangeMin

        // ハプティックフィードバック
        HapticManager.recordFeedback()

        // ウィジェットのタイムラインを更新
        WidgetCenter.shared.reloadAllTimelines()

        // Track recording time for smart reminder + cancel win-back
        NotificationManager.trackRecordingTime()
        NotificationManager.updateLastRecordDate()
        NotificationManager.cancelWinback()

        // Write mood data for Nemuri (bidirectional sync)
        NamiDataWriter.writeMoodData(
            latestEntry: entry,
            weeklyAvg: Double(score),
            weeklyCount: 1
        )

        // Fetch weather asynchronously after entry creation
        if let weatherManager {
            let capturedEntry = entry
            Task {
                let weather = await weatherManager.fetchCurrentWeather()
                capturedEntry.weatherCondition = weather.condition
                capturedEntry.weatherTemperature = weather.temperature
            }
        }

        // 記録完了アニメーション表示
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showRecordedAnimation = true
        }

        // 統合記録シートを少し遅延して表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showRecordingSheet = true
            self?.showRecordedAnimation = false
            self?.isRecording = false
        }
    }

    /// 統合記録を保存する（メモ + 写真 + ボイスメモ + タグ + エネルギー）
    /// - Parameters:
    ///   - memo: メモテキスト
    ///   - photo: 撮影した写真（任意）
    ///   - voiceMemoURL: ボイスメモの一時URL（任意）
    ///   - tags: 選択されたタグ名の配列
    ///   - energyLevel: エネルギーレベル（1=低, 2=普通, 3=高, nil=スキップ）
    func saveRecording(memo: String, photo: UIImage?, voiceMemoURL: URL?, tags: [String] = [], energyLevel: Int? = nil) {
        guard let entry = lastRecordedEntry else { return }

        // メモ保存
        if !memo.isEmpty {
            entry.memo = String(memo.prefix(100))
        }

        // 写真保存
        if let photo {
            entry.photoPath = MediaManager.savePhoto(photo)
        }

        // ボイスメモ保存
        if let voiceMemoURL {
            entry.voiceMemoPath = MediaManager.saveVoiceMemo(from: voiceMemoURL)
        }

        // タグ保存
        entry.tags = tags

        // エネルギーレベル保存
        entry.energyLevel = energyLevel

        showRecordingSheet = false
        lastRecordedEntry = nil
        isRecording = false
    }

    /// 詳細追加をスキップしてシートを閉じる（記録自体は保持される）
    func skipRecording() {
        showRecordingSheet = false
        lastRecordedEntry = nil
        isRecording = false
    }

    /// 既存エントリのメモを編集する
    /// - Parameters:
    ///   - entry: 編集対象のエントリ
    ///   - memo: 新しいメモテキスト（空の場合はnilに設定）
    func editMemo(entry: MoodEntry, memo: String) {
        entry.memo = memo.isEmpty ? nil : String(memo.prefix(100))
    }
}
