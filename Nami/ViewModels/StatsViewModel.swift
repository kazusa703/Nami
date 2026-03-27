//
//  StatsViewModel.swift
//  Nami
//
//  統計計算ロジック
//

import Foundation
import NaturalLanguage
import SwiftData

/// 時間帯の分類
enum TimeOfDay: Int, CaseIterable, Identifiable {
    case morning = 0 // 朝 5:00-10:59
    case afternoon = 1 // 昼 11:00-16:59
    case evening = 2 // 夕 17:00-20:59
    case night = 3 // 夜 21:00-4:59

    var id: Int {
        rawValue
    }

    /// 表示名
    var label: String {
        switch self {
        case .morning: return String(localized: "朝")
        case .afternoon: return String(localized: "昼")
        case .evening: return String(localized: "夕")
        case .night: return String(localized: "夜")
        }
    }

    /// アイコン名
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.fill"
        }
    }

    /// 時間帯の範囲
    var timeRange: String {
        switch self {
        case .morning: return "5:00-11:00"
        case .afternoon: return "11:00-17:00"
        case .evening: return "17:00-21:00"
        case .night: return "21:00-5:00"
        }
    }

    /// 時刻から時間帯を判定する
    static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 5 ..< 11: return .morning
        case 11 ..< 17: return .afternoon
        case 17 ..< 21: return .evening
        default: return .night // 21-23, 0-4
        }
    }
}

/// 週間レビューのハイライト/ローポイント
struct WeeklyReviewPoint {
    let score: Int
    let date: Date
    let memo: String?
}

/// 週間レビューのデータ
struct WeeklyReview {
    let weekStart: Date
    let weekEnd: Date
    let entryCount: Int
    let average: Double
    let highlight: WeeklyReviewPoint?
    let lowPoint: WeeklyReviewPoint?
    let topTags: [(tag: String, count: Int)]
    let summary: String
    let previousWeekAverage: Double?
}

// MARK: - プレミアム分析の構造体

/// 月間サマリーデータ
struct MonthlySummary {
    let month: Date
    let entryCount: Int
    let average: Double
    let previousMonthAverage: Double?
    let bestDay: (date: Date, score: Int, memo: String?)?
    let worstDay: (date: Date, score: Int, memo: String?)?
    let topTags: [(tag: String, count: Int)]
    let positiveTagRate: Double
    let negativeTagRate: Double
    let activeDays: Int
    let weekdayBest: String
    let volatility: Double
}

/// タグ連鎖パターン
struct TagChain {
    let fromTag: String
    let toTag: String
    let occurrences: Int
    let avgScoreChange: Double
    let isNegativeLoop: Bool
}

/// タグ残響効果
struct TagEcho {
    let tag: String
    let recoveryDays: Double
    let dayEffects: [Double]
    let sampleSize: Int
}

/// タグとスコアのズレ
struct TagDivergence {
    let tag: String
    let historicalAvg: Double
    let recentAvg: Double
    let divergence: Double
    let recentCount: Int
}

/// 回復トリガー
struct RecoveryTrigger {
    let tag: String
    let appearanceRate: Int
    let avgRecoveryBoost: Double
    let sampleSize: Int
}

/// タグシナジー
struct TagSynergy {
    let tag1: String
    let tag2: String
    let soloAvg1: Double
    let soloAvg2: Double
    let comboAvg: Double
    let synergyDelta: Double
    let comboCount: Int
    let isRedZone: Bool
}

/// 回復パターンイベント
struct RecoveryEvent {
    let lowPeriodStart: Date
    let recoveryDate: Date
    let daysToRecover: Int
    let recoveryTags: [String]
    let lowScore: Double
    let recoveryScore: Double
}

/// 統計データを計算するViewModel
@Observable
class StatsViewModel {
    // MARK: - 週間平均

    /// 今週の平均スコアを計算する（正規化ベース → 現在のレンジにスケール）
    func weeklyAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let weekEntries = entries.filter { $0.createdAt >= startOfWeek }
        return normalizedAverage(of: weekEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    /// 先週の平均スコアを計算する
    func lastWeekAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return nil }
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        let weekEntries = entries.filter { $0.createdAt >= lastWeekStart && $0.createdAt < thisWeekStart }
        return normalizedAverage(of: weekEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    // MARK: - 月間平均

    /// 今月の平均スコアを計算する
    func monthlyAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let monthEntries = entries.filter { $0.createdAt >= startOfMonth }
        return normalizedAverage(of: monthEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    /// 先月の平均スコアを計算する
    func lastMonthAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        guard let thisMonthStart = calendar.dateInterval(of: .month, for: .now)?.start else { return nil }
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
        let monthEntries = entries.filter { $0.createdAt >= lastMonthStart && $0.createdAt < thisMonthStart }
        return normalizedAverage(of: monthEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    // MARK: - 年間平均

    /// 今年の平均スコアを計算する
    func yearlyAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        let startOfYear = calendar.dateInterval(of: .year, for: .now)?.start ?? .now
        let yearEntries = entries.filter { $0.createdAt >= startOfYear }
        return normalizedAverage(of: yearEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    // MARK: - 合計・ストリーク

    /// 記録の合計回数
    func totalCount(entries: [MoodEntry]) -> Int {
        entries.count
    }

    /// 連続記録日数（ストリーク）を計算する
    /// 今日から遡って、毎日少なくとも1回記録がある連続日数を返す
    func currentStreak(entries: [MoodEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }

        let calendar = Calendar.current
        // 記録がある日付のセットを作成
        var recordedDays = Set<Date>()
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            recordedDays.insert(day)
        }

        let today = calendar.startOfDay(for: .now)
        var streak = 0
        var checkDate = today

        // 今日に記録がない場合、昨日から開始
        if !recordedDays.contains(today) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if recordedDays.contains(yesterday) {
                checkDate = yesterday
            } else {
                return 0
            }
        }

        // 連続日数をカウント
        while recordedDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    // MARK: - 最高・最低・モード値

    /// 最高スコアとその記録日を返す（現在のレンジにスケール）
    func highestScore(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> (score: Int, date: Date)? {
        guard !entries.isEmpty else { return nil }
        // 正規化スコアが最大のエントリを探す
        let entry = entries.max(by: { $0.normalizedScore < $1.normalizedScore })!
        let scaled = Int(entry.scaledScore(to: currentMax, targetMin: currentMin).rounded())
        return (scaled, entry.createdAt)
    }

    /// 最低スコアとその記録日を返す（現在のレンジにスケール）
    func lowestScore(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> (score: Int, date: Date)? {
        guard !entries.isEmpty else { return nil }
        let entry = entries.min(by: { $0.normalizedScore < $1.normalizedScore })!
        let scaled = Int(entry.scaledScore(to: currentMax, targetMin: currentMin).rounded())
        return (scaled, entry.createdAt)
    }

    /// 最も多く記録されたスコア（モード値）を返す（現在のレンジにスケール）
    func mostCommonScore(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Int? {
        guard !entries.isEmpty else { return nil }
        let distribution = scoreDistribution(entries: entries, minScore: currentMin, maxScore: currentMax)
        return distribution.max(by: { $0.value < $1.value })?.key
    }

    /// スコアの分布（各スコアの記録回数）を返す
    /// 異なるmaxScoreのエントリは現在のレンジにスケーリングして集計する
    func scoreDistribution(entries: [MoodEntry], minScore: Int = 1, maxScore: Int = 10) -> [Int: Int] {
        var distribution: [Int: Int] = [:]
        for i in minScore ... maxScore {
            distribution[i] = 0
        }
        for entry in entries {
            let scaled = (entry.maxScore == maxScore && entry.scoreRangeMin == minScore)
                ? entry.score
                : Int(entry.scaledScore(to: maxScore, targetMin: minScore).rounded())
            let clamped = max(minScore, min(maxScore, scaled))
            distribution[clamped, default: 0] += 1
        }
        return distribution
    }

    // MARK: - 週間トレンド

    /// 先週比のトレンド（上昇/下降/横ばい）を返す
    func weeklyTrend(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        guard let current = weeklyAverage(entries: entries, currentMax: currentMax, currentMin: currentMin),
              let previous = lastWeekAverage(entries: entries, currentMax: currentMax, currentMin: currentMin) else { return nil }
        return current - previous
    }

    // MARK: - 曜日別平均

    /// 曜日別の平均スコアを返す（1=日曜〜7=土曜 → [Int: Double]）
    func weekdayAverages(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> [Int: Double] {
        let calendar = Calendar.current
        var grouped: [Int: [MoodEntry]] = [:]
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.createdAt) // 1=日, 2=月, ...7=土
            grouped[weekday, default: []].append(entry)
        }
        var result: [Int: Double] = [:]
        for (weekday, group) in grouped {
            if let avg = normalizedAverage(of: group, scaleTo: currentMax, targetMin: currentMin) {
                result[weekday] = avg
            }
        }
        return result
    }

    // MARK: - 時間帯別平均

    /// 時間帯別の平均スコアを返す
    func timeOfDayAverages(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> [TimeOfDay: Double] {
        let calendar = Calendar.current
        var grouped: [TimeOfDay: [MoodEntry]] = [:]
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            let tod = TimeOfDay.from(hour: hour)
            grouped[tod, default: []].append(entry)
        }
        var result: [TimeOfDay: Double] = [:]
        for (tod, group) in grouped {
            if let avg = normalizedAverage(of: group, scaleTo: currentMax, targetMin: currentMin) {
                result[tod] = avg
            }
        }
        return result
    }

    // MARK: - 最長ストリーク

    /// 過去最長の連続記録日数を返す
    func longestStreak(entries: [MoodEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }

        let calendar = Calendar.current
        // 記録がある日付のセットを作成
        var recordedDays = Set<Date>()
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            recordedDays.insert(day)
        }

        // 日付をソートして連続をカウント
        let sortedDays = recordedDays.sorted()
        var maxStreak = 1
        var currentRun = 1

        for i in 1 ..< sortedDays.count {
            let diff = calendar.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day ?? 0
            if diff == 1 {
                currentRun += 1
                maxStreak = max(maxStreak, currentRun)
            } else {
                currentRun = 1
            }
        }
        return maxStreak
    }

    // MARK: - 週間リズムデータ（ムードリズム用）

    /// 月〜日の平均スコアを配列で返す（波線チャート用）
    func weeklyRhythmData(entries: [MoodEntry], currentMax: Int = 10, currentMin _: Int = 1) -> [(label: String, index: Int, average: Double)] {
        let averages = weekdayAverages(entries: entries, currentMax: currentMax)
        let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
        let weekdayLabels = [String(localized: "月曜"), String(localized: "火曜"), String(localized: "水曜"), String(localized: "木曜"), String(localized: "金曜"), String(localized: "土曜"), String(localized: "日曜")]

        return weekdayOrder.enumerated().map { index, weekday in
            (weekdayLabels[index], index, averages[weekday] ?? 0)
        }
    }

    // MARK: - ボラティリティ推移（週ごとの標準偏差）

    /// 週ごとのスコア標準偏差の推移を返す（安定度チャート用）
    func volatilityTrend(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> [(weekStart: Date, stdDev: Double)] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        var weeklyGroups: [(start: Date, scores: [Double])] = []
        var currentWeekStart: Date?
        var currentWeekScores: [Double] = []

        for entry in sorted {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: entry.createdAt) else { continue }
            let weekStart = weekInterval.start

            if weekStart != currentWeekStart {
                if let start = currentWeekStart, currentWeekScores.count >= 2 {
                    weeklyGroups.append((start, currentWeekScores))
                }
                currentWeekStart = weekStart
                currentWeekScores = []
            }
            let scaled = entry.normalizedScore * Double(currentMax - currentMin) + Double(currentMin)
            currentWeekScores.append(scaled)
        }
        if let start = currentWeekStart, currentWeekScores.count >= 2 {
            weeklyGroups.append((start, currentWeekScores))
        }

        return weeklyGroups.map { group in
            let mean = group.scores.reduce(0.0, +) / Double(group.scores.count)
            let variance = group.scores.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(group.scores.count)
            return (group.start, sqrt(variance))
        }
    }

    // MARK: - スパークラインデータ

    /// 指定日以降の正規化スコア配列を返す（シェア機能用）
    func sparklineData(entries: [MoodEntry], since: Date) -> [Double] {
        let filtered = entries
            .filter { $0.createdAt >= since }
            .sorted { $0.createdAt < $1.createdAt }
        return filtered.map { $0.normalizedScore }
    }

    // MARK: - タグ分析

    /// タグの使用頻度を降順で返す
    func tagFrequency(entries: [MoodEntry]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    /// タグ別の平均スコア（現在のレンジにスケール）を返す
    func tagAverageScores(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> [(tag: String, average: Double, count: Int)] {
        var grouped: [String: [MoodEntry]] = [:]
        for entry in entries {
            for tag in entry.tags {
                grouped[tag, default: []].append(entry)
            }
        }
        return grouped.compactMap { tag, tagEntries in
            guard let avg = normalizedAverage(of: tagEntries, scaleTo: currentMax, targetMin: currentMin) else { return nil }
            return (tag, avg, tagEntries.count)
        }.sorted { $0.average > $1.average }
    }

    /// タグの翌日効果を計算する（ベースラインとの差分）
    /// サンプル2件以上のタグのみ返す
    func nextDayEffect(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> [(tag: String, delta: Double, sampleSize: Int)] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        // 全体のベースライン（正規化平均）
        guard let baseline = normalizedAverage(of: sorted, scaleTo: currentMax, targetMin: currentMin) else { return [] }

        // 日別にグルーピング
        var dayEntries: [Date: [MoodEntry]] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayEntries[day, default: []].append(entry)
        }

        // タグごとに「翌日の平均スコア」を集計
        var tagNextDayScores: [String: [Double]] = [:]
        let allDays = dayEntries.keys.sorted()

        for day in allDays {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  let nextDayGroup = dayEntries[nextDay] else { continue }
            guard let nextAvg = normalizedAverage(of: nextDayGroup, scaleTo: currentMax, targetMin: currentMin) else { continue }

            let todayTags = Set(dayEntries[day]?.flatMap(\.tags) ?? [])
            for tag in todayTags {
                tagNextDayScores[tag, default: []].append(nextAvg)
            }
        }

        return tagNextDayScores.compactMap { tag, scores in
            guard scores.count >= 2 else { return nil }
            let avg = scores.reduce(0.0, +) / Double(scores.count)
            return (tag, avg - baseline, scores.count)
        }.sorted { abs($0.delta) > abs($1.delta) }
    }

    /// タグの共起パターンを返す（一緒に使われるタグのペア）
    func tagCoOccurrence(entries: [MoodEntry]) -> [(tag1: String, tag2: String, count: Int)] {
        var pairs: [String: Int] = [:]
        for entry in entries {
            let tags = entry.tags.sorted()
            for i in 0 ..< tags.count {
                for j in (i + 1) ..< tags.count {
                    let key = "\(tags[i])|\(tags[j])"
                    pairs[key, default: 0] += 1
                }
            }
        }
        return pairs.sorted { $0.value > $1.value }.prefix(10).map { key, count in
            let parts = key.split(separator: "|").map(String.init)
            return (parts[0], parts[1], count)
        }
    }

    // MARK: - タグインパクト分析（ビフォーアフター比較）

    /// 特定タグの影響データ（日レベルの比較）
    /// タグが付いた日 vs 付かなかった日の平均スコア・分布を返す
    func tagImpactData(tag: String, entries: [MoodEntry], currentMax: Int, currentMin: Int = 1)
        -> (withAvg: Double, withoutAvg: Double, delta: Double,
            withDays: Int, withoutDays: Int,
            withDist: [Int: Int], withoutDist: [Int: Int])?
    {
        let calendar = Calendar.current
        var dayEntries: [Date: [MoodEntry]] = [:]
        for entry in entries {
            dayEntries[calendar.startOfDay(for: entry.createdAt), default: []].append(entry)
        }

        var withNorms: [Double] = []
        var withoutNorms: [Double] = []
        var withAll: [MoodEntry] = []
        var withoutAll: [MoodEntry] = []

        for (_, group) in dayEntries {
            let hasTag = group.contains { $0.tags.contains(tag) }
            let dayNorm = group.reduce(0.0) { $0 + $1.normalizedScore } / Double(group.count)
            if hasTag {
                withNorms.append(dayNorm)
                withAll.append(contentsOf: group)
            } else {
                withoutNorms.append(dayNorm)
                withoutAll.append(contentsOf: group)
            }
        }

        guard !withNorms.isEmpty, !withoutNorms.isEmpty else { return nil }

        let withAvg = (withNorms.reduce(0, +) / Double(withNorms.count)) * Double(currentMax - currentMin) + Double(currentMin)
        let withoutAvg = (withoutNorms.reduce(0, +) / Double(withoutNorms.count)) * Double(currentMax - currentMin) + Double(currentMin)

        /// エントリレベルの分布（チャート用）
        func buildDist(_ list: [MoodEntry]) -> [Int: Int] {
            var dist: [Int: Int] = [:]
            for e in list {
                let s = e.maxScore == currentMax ? e.score : Int(e.scaledScore(to: currentMax, targetMin: currentMin).rounded())
                dist[max(1, min(currentMax, s)), default: 0] += 1
            }
            return dist
        }

        return (withAvg, withoutAvg, withAvg - withoutAvg,
                withNorms.count, withoutNorms.count,
                buildDist(withAll), buildDist(withoutAll))
    }

    /// エントリで使用されている全タグとその出現回数を返す
    func allTagCounts(entries: [MoodEntry]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: - 発見（隠れた相関）

    /// 記録回数とスコアの関係（複数回記録した日 vs 1回の日）
    func recordCountVsScore(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1)
        -> (multiAvg: Double, singleAvg: Double, multiDays: Int, singleDays: Int)?
    {
        let calendar = Calendar.current
        var dayEntries: [Date: [MoodEntry]] = [:]
        for entry in entries {
            dayEntries[calendar.startOfDay(for: entry.createdAt), default: []].append(entry)
        }

        let multiDays = dayEntries.filter { $0.value.count >= 2 }
        let singleDays = dayEntries.filter { $0.value.count == 1 }
        guard multiDays.count >= 5, singleDays.count >= 5 else { return nil }

        func dayAvg(_ days: [Date: [MoodEntry]]) -> Double {
            let norms = days.values.map { g in
                g.reduce(0.0) { $0 + $1.normalizedScore } / Double(g.count)
            }
            let n = norms.reduce(0.0, +) / Double(norms.count)
            return n * Double(currentMax - currentMin) + Double(currentMin)
        }

        return (dayAvg(multiDays), dayAvg(singleDays), multiDays.count, singleDays.count)
    }

    /// タグ使用とスコアの関係（タグありエントリ vs タグなしエントリ）
    func tagUsageVsScore(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1)
        -> (taggedAvg: Double, untaggedAvg: Double, taggedCount: Int, untaggedCount: Int)?
    {
        let tagged = entries.filter { !$0.tags.isEmpty }
        let untagged = entries.filter { $0.tags.isEmpty }
        guard tagged.count >= 5, untagged.count >= 5 else { return nil }

        guard let tAvg = normalizedAverage(of: tagged, scaleTo: currentMax, targetMin: currentMin),
              let uAvg = normalizedAverage(of: untagged, scaleTo: currentMax, targetMin: currentMin) else { return nil }
        return (tAvg, uAvg, tagged.count, untagged.count)
    }

    /// 詳細な共起パターン（共起率付き、上位5ペア）
    func detailedCoOccurrence(entries: [MoodEntry]) -> [(tag1: String, tag2: String, count: Int, rate: Int)] {
        var pairs: [String: Int] = [:]
        var tagCounts: [String: Int] = [:]

        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
            let sorted = entry.tags.sorted()
            for i in 0 ..< sorted.count {
                for j in (i + 1) ..< sorted.count {
                    pairs["\(sorted[i])|\(sorted[j])", default: 0] += 1
                }
            }
        }

        return pairs.sorted { $0.value > $1.value }.prefix(5).compactMap { key, count in
            guard count >= 3 else { return nil }
            let parts = key.split(separator: "|").map(String.init)
            let minCount = min(tagCounts[parts[0]] ?? 0, tagCounts[parts[1]] ?? 0)
            guard minCount > 0 else { return nil }
            return (parts[0], parts[1], count, Int(Double(count) / Double(minCount) * 100))
        }
    }

    // MARK: - 週間レビュー

    /// 先週の振り返りレビューを生成する
    /// 先週のエントリが3件以上ある場合のみ返す
    func weeklyReview(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> WeeklyReview? {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return nil }
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!

        let weekEntries = entries.filter { $0.createdAt >= lastWeekStart && $0.createdAt < thisWeekStart }
        guard weekEntries.count >= 3 else { return nil }

        // 平均スコア
        let avgNorm = weekEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(weekEntries.count)
        let average = avgNorm * Double(currentMax - currentMin) + Double(currentMin)

        // ハイライト（正規化スコアが最高のエントリ）
        let best = weekEntries.max(by: { $0.normalizedScore < $1.normalizedScore })
        let highlight = best.map {
            WeeklyReviewPoint(score: Int($0.scaledScore(to: currentMax, targetMin: currentMin).rounded()), date: $0.createdAt, memo: $0.memo)
        }

        // ローポイント（正規化スコアが最低のエントリ）
        let worst = weekEntries.min(by: { $0.normalizedScore < $1.normalizedScore })
        let lowPoint = worst.map {
            WeeklyReviewPoint(score: Int($0.scaledScore(to: currentMax, targetMin: currentMin).rounded()), date: $0.createdAt, memo: $0.memo)
        }

        // Top 3 タグ
        var tagCounts: [String: Int] = [:]
        for e in weekEntries {
            for t in e.tags {
                tagCounts[t, default: 0] += 1
            }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }

        // 前週の平均（比較用）
        let twoWeeksStart = calendar.date(byAdding: .weekOfYear, value: -2, to: thisWeekStart)!
        let prevEntries = entries.filter { $0.createdAt >= twoWeeksStart && $0.createdAt < lastWeekStart }
        let prevAvg: Double? = prevEntries.isEmpty ? nil : {
            let n = prevEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(prevEntries.count)
            return n * Double(currentMax - currentMin) + Double(currentMin)
        }()

        // サマリー生成
        let summary = generateWeeklySummary(
            entries: weekEntries, average: average, currentMax: currentMax, previousAverage: prevAvg
        )

        let weekEnd = calendar.date(byAdding: .day, value: -1, to: thisWeekStart)!

        return WeeklyReview(
            weekStart: lastWeekStart, weekEnd: weekEnd,
            entryCount: weekEntries.count, average: average,
            highlight: highlight, lowPoint: lowPoint,
            topTags: topTags, summary: summary,
            previousWeekAverage: prevAvg
        )
    }

    /// 週間サマリーの自動生成（スコアパターンに基づく1行テキスト）
    private func generateWeeklySummary(entries: [MoodEntry], average: Double, currentMax: Int, currentMin: Int = 1, previousAverage: Double?) -> String {
        let normAvg = (average - Double(currentMin)) / Double(currentMax - currentMin)
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        // 前半 vs 後半のトレンド
        let halfIndex = sorted.count / 2
        let firstHalf = Array(sorted.prefix(halfIndex))
        let secondHalf = Array(sorted.suffix(from: halfIndex))

        let firstNorm = firstHalf.isEmpty ? 0 : firstHalf.reduce(0.0) { $0 + $1.normalizedScore } / Double(firstHalf.count)
        let secondNorm = secondHalf.isEmpty ? 0 : secondHalf.reduce(0.0) { $0 + $1.normalizedScore } / Double(secondHalf.count)
        let trendDelta = secondNorm - firstNorm

        // ボラティリティ
        let scores = sorted.map(\.normalizedScore)
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(scores.count)
        let std = sqrt(variance)

        // パターンに応じてサマリーを選択
        if normAvg > 0.75 {
            if trendDelta > 0.08 {
                return String(localized: "後半にかけてさらに調子が上がった、充実した1週間でした")
            }
            return String(localized: "全体的に好調な1週間でした。この調子を大切に！")
        } else if normAvg > 0.55 {
            if trendDelta > 0.1 {
                return String(localized: "後半に盛り返しました。回復力がある証拠です")
            } else if trendDelta < -0.1 {
                return String(localized: "後半にかけて少し疲れが出たようです。今週はしっかり休息を")
            } else if std < 0.12 {
                return String(localized: "安定したリズムの1週間でした")
            }
            return String(localized: "穏やかな1週間でした")
        } else if normAvg > 0.35 {
            if trendDelta > 0.1 {
                return String(localized: "辛い時期もありましたが、後半に持ち直しました")
            } else if let prev = previousAverage {
                let prevNorm = (prev - Double(currentMin)) / Double(currentMax - currentMin)
                if normAvg > prevNorm + 0.05 {
                    return String(localized: "先週よりも少し上向いています。一歩ずつ前に進んでいます")
                }
            }
            return String(localized: "気分の波がある1週間でした。自分に優しくしてあげてください")
        } else {
            if trendDelta > 0.08 {
                return String(localized: "辛い日が多かったですが、少しずつ上向いています")
            }
            return String(localized: "少し辛い1週間でしたが、記録を続けているあなたは素晴らしいです")
        }
    }

    // MARK: - プレミアム分析 A: 逆インサイト

    /// 上位/下位25%スコアの日に共通するタグ・不在タグを抽出
    func reverseInsights(entries: [MoodEntry], currentMax _: Int, currentMin _: Int = 1)
        -> (highTags: [(tag: String, rate: Int)],
            highAbsentTags: [(tag: String, rate: Int)],
            lowTags: [(tag: String, rate: Int)])
    {
        let taggedEntries = entries.filter { !$0.tags.isEmpty }
        guard taggedEntries.count >= 30 else { return ([], [], []) }

        let sorted = taggedEntries.sorted { $0.normalizedScore > $1.normalizedScore }
        let q25 = max(1, sorted.count / 4)
        let highEntries = Array(sorted.prefix(q25))
        let lowEntries = Array(sorted.suffix(q25))

        // 全タグの出現回数
        var totalTagCounts: [String: Int] = [:]
        for e in taggedEntries {
            for t in e.tags {
                totalTagCounts[t, default: 0] += 1
            }
        }
        let allTags = Set(totalTagCounts.keys)

        func tagRates(in subset: [MoodEntry]) -> [String: Int] {
            var counts: [String: Int] = [:]
            for e in subset {
                for t in e.tags {
                    counts[t, default: 0] += 1
                }
            }
            return counts.mapValues { Int(Double($0) / Double(subset.count) * 100) }
        }

        let highRates = tagRates(in: highEntries)
        let lowRates = tagRates(in: lowEntries)

        // 好調時に多いタグ Top5
        let highTags = highRates.sorted { $0.value > $1.value }
            .prefix(5).map { (tag: $0.key, rate: $0.value) }

        // 好調時に不在のタグ Top3
        let highAbsentTags = allTags
            .filter { totalTagCounts[$0, default: 0] >= 3 }
            .filter { (highRates[$0] ?? 0) < 10 }
            .sorted { (lowRates[$0] ?? 0) > (lowRates[$1] ?? 0) }
            .prefix(3)
            .map { tag -> (tag: String, rate: Int) in
                let absenceRate = 100 - (highRates[tag] ?? 0)
                return (tag: tag, rate: absenceRate)
            }

        // 不調時に多いタグ Top5
        let lowTags = lowRates.sorted { $0.value > $1.value }
            .prefix(5).map { (tag: $0.key, rate: $0.value) }

        return (Array(highTags), Array(highAbsentTags), Array(lowTags))
    }

    // MARK: - プレミアム分析 B: 月間サマリー

    /// 指定月の包括レポートを生成
    func monthlySummary(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1, month: Date) -> MonthlySummary? {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return nil }
        let monthEntries = entries.filter { $0.createdAt >= monthInterval.start && $0.createdAt < monthInterval.end }
        guard !monthEntries.isEmpty else { return nil }

        // 平均
        let avgNorm = monthEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(monthEntries.count)
        let average = avgNorm * Double(currentMax - currentMin) + Double(currentMin)

        // 前月の平均
        let prevMonth = calendar.date(byAdding: .month, value: -1, to: monthInterval.start)!
        guard let prevInterval = calendar.dateInterval(of: .month, for: prevMonth) else { return nil }
        let prevEntries = entries.filter { $0.createdAt >= prevInterval.start && $0.createdAt < prevInterval.end }
        let prevAvg: Double? = prevEntries.isEmpty ? nil : {
            let n = prevEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(prevEntries.count)
            return n * Double(currentMax - currentMin) + Double(currentMin)
        }()

        // ベスト/ワースト
        let best = monthEntries.max(by: { $0.normalizedScore < $1.normalizedScore })
        let bestDay = best.map { (date: $0.createdAt, score: Int($0.scaledScore(to: currentMax, targetMin: currentMin).rounded()), memo: $0.memo) }
        let worst = monthEntries.min(by: { $0.normalizedScore < $1.normalizedScore })
        let worstDay = worst.map { (date: $0.createdAt, score: Int($0.scaledScore(to: currentMax, targetMin: currentMin).rounded()), memo: $0.memo) }

        // Top タグ
        var tagCounts: [String: Int] = [:]
        for e in monthEntries {
            for t in e.tags {
                tagCounts[t, default: 0] += 1
            }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        // ポジティブ/ネガティブ率（上位50%/下位50%のタグ付きエントリの比率）
        let midNorm = 0.5
        let posEntries = monthEntries.filter { $0.normalizedScore >= midNorm && !$0.tags.isEmpty }
        let negEntries = monthEntries.filter { $0.normalizedScore < midNorm && !$0.tags.isEmpty }
        let taggedCount = monthEntries.filter { !$0.tags.isEmpty }.count
        let posRate = taggedCount > 0 ? Double(posEntries.count) / Double(taggedCount) : 0
        let negRate = taggedCount > 0 ? Double(negEntries.count) / Double(taggedCount) : 0

        // アクティブ日数
        var daySet = Set<Date>()
        for e in monthEntries {
            daySet.insert(calendar.startOfDay(for: e.createdAt))
        }

        // 最も好調な曜日
        var weekdayScores: [Int: [Double]] = [:]
        for e in monthEntries {
            let wd = calendar.component(.weekday, from: e.createdAt)
            weekdayScores[wd, default: []].append(e.normalizedScore)
        }
        let cal = Calendar.current
        let weekdayNames = [""] + cal.shortWeekdaySymbols
        let bestWD = weekdayScores.max { a, b in
            let aAvg = a.value.reduce(0, +) / Double(a.value.count)
            let bAvg = b.value.reduce(0, +) / Double(b.value.count)
            return aAvg < bAvg
        }
        let weekdayBest = bestWD.map { weekdayNames[$0.key] } ?? "-"

        // ボラティリティ
        let scores = monthEntries.map(\.normalizedScore)
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(scores.count)
        let vol = sqrt(variance) * Double(currentMax - 1)

        return MonthlySummary(
            month: monthInterval.start,
            entryCount: monthEntries.count,
            average: average,
            previousMonthAverage: prevAvg,
            bestDay: bestDay,
            worstDay: worstDay,
            topTags: topTags,
            positiveTagRate: posRate,
            negativeTagRate: negRate,
            activeDays: daySet.count,
            weekdayBest: weekdayBest,
            volatility: vol
        )
    }

    // MARK: - プレミアム分析 C: タグ連鎖パターン

    /// 日N→日N+1のタグ遷移パターンを集計（3回以上発生のみ）
    func tagChainPatterns(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [TagChain] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        var dayData: [(date: Date, tags: Set<String>, normScore: Double)] = []
        var currentDay: Date?
        var currentTags = Set<String>()
        var currentScores: [Double] = []

        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            if day != currentDay {
                if let cd = currentDay, !currentTags.isEmpty {
                    let avg = currentScores.reduce(0, +) / Double(currentScores.count)
                    dayData.append((cd, currentTags, avg))
                }
                currentDay = day
                currentTags = Set(entry.tags)
                currentScores = [entry.normalizedScore]
            } else {
                currentTags.formUnion(entry.tags)
                currentScores.append(entry.normalizedScore)
            }
        }
        if let cd = currentDay, !currentTags.isEmpty {
            let avg = currentScores.reduce(0, +) / Double(currentScores.count)
            dayData.append((cd, currentTags, avg))
        }

        // ペア集計
        var pairData: [String: (count: Int, scoreChanges: [Double])] = [:]
        for i in 0 ..< (dayData.count - 1) {
            let today = dayData[i]
            let tomorrow = dayData[i + 1]
            let diff = calendar.dateComponents([.day], from: today.date, to: tomorrow.date).day ?? 0
            guard diff == 1 else { continue }

            let scoreChange = (tomorrow.normScore - today.normScore) * Double(currentMax - 1)
            for fromTag in today.tags {
                for toTag in tomorrow.tags {
                    let key = "\(fromTag)|\(toTag)"
                    var existing = pairData[key] ?? (0, [])
                    existing.count += 1
                    existing.scoreChanges.append(scoreChange)
                    pairData[key] = existing
                }
            }
        }

        return pairData.compactMap { key, data in
            guard data.count >= 3 else { return nil }
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 2 else { return nil }
            let avg = data.scoreChanges.reduce(0, +) / Double(data.scoreChanges.count)
            return TagChain(
                fromTag: parts[0],
                toTag: parts[1],
                occurrences: data.count,
                avgScoreChange: avg,
                isNegativeLoop: avg < -0.5
            )
        }.sorted { $0.occurrences > $1.occurrences }
    }

    // MARK: - プレミアム分析 D: タグ残響効果

    /// タグ使用後+0〜+3日のスコア変動を追跡（サンプル5件以上のタグのみ）
    func tagEchoEffect(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [TagEcho] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        // 日別データ構築
        var dayScores: [Date: Double] = [:]
        var dayTags: [Date: Set<String>] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayScores[day] = (dayScores[day] ?? 0) + entry.normalizedScore
            dayTags[day, default: []].formUnion(entry.tags)
        }
        // 日別の平均正規化スコアに変換
        var dayEntryCounts: [Date: Int] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayEntryCounts[day, default: 0] += 1
        }
        for (day, total) in dayScores {
            dayScores[day] = total / Double(dayEntryCounts[day] ?? 1)
        }

        // 全体平均
        let allNorms = Array(dayScores.values)
        guard !allNorms.isEmpty else { return [] }
        let overallAvg = allNorms.reduce(0, +) / Double(allNorms.count)

        // タグごとに+0〜+3日のスコアを集計
        var tagDayEffects: [String: [[Double]]] = [:] // tag -> [[day0 diffs], [day1 diffs], ...]
        let allDays = dayScores.keys.sorted()

        for day in allDays {
            guard let tags = dayTags[day] else { continue }
            for tag in tags {
                if tagDayEffects[tag] == nil {
                    tagDayEffects[tag] = [[], [], [], []]
                }
                for offset in 0 ... 3 {
                    guard let targetDay = calendar.date(byAdding: .day, value: offset, to: day),
                          let score = dayScores[targetDay] else { continue }
                    tagDayEffects[tag]?[offset].append(score - overallAvg)
                }
            }
        }

        return tagDayEffects.compactMap { tag, effects in
            let sampleSize = effects[0].count
            guard sampleSize >= 5 else { return nil }

            let dayAvgs = effects.map { diffs -> Double in
                guard !diffs.isEmpty else { return 0 }
                return diffs.reduce(0, +) / Double(diffs.count)
            }
            let scaledAvgs = dayAvgs.map { $0 * Double(currentMax - 1) }

            // 回復日数: 差分が±0.3（正規化）以内に収まった最初の日
            var recoveryDay = 4.0
            for i in 1 ... 3 {
                if abs(dayAvgs[i]) <= 0.3 / Double(currentMax - 1) {
                    recoveryDay = Double(i)
                    break
                }
            }

            return TagEcho(
                tag: tag,
                recoveryDays: recoveryDay,
                dayEffects: scaledAvgs,
                sampleSize: sampleSize
            )
        }
        .filter { $0.dayEffects.first.map { abs($0) > 0.3 } ?? false }
        .sorted { abs($0.dayEffects[0]) > abs($1.dayEffects[0]) }
    }

    // MARK: - プレミアム分析 E: 行動とスコアのズレ検出

    /// 全期間 vs 直近2週間のタグ使用時スコアを比較してズレを検出
    func actionScoreDivergence(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [TagDivergence] {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: .now)!

        var historicalScores: [String: [Double]] = [:]
        var recentScores: [String: [Double]] = [:]

        for entry in entries {
            for tag in entry.tags {
                let scaled = entry.normalizedScore * Double(currentMax - currentMin) + Double(currentMin)
                historicalScores[tag, default: []].append(scaled)
                if entry.createdAt >= twoWeeksAgo {
                    recentScores[tag, default: []].append(scaled)
                }
            }
        }

        return historicalScores.compactMap { tag, allScores in
            guard allScores.count >= 5 else { return nil }
            guard let recent = recentScores[tag], recent.count >= 2 else { return nil }

            let histAvg = allScores.reduce(0, +) / Double(allScores.count)
            let recAvg = recent.reduce(0, +) / Double(recent.count)
            let div = recAvg - histAvg

            guard abs(div) >= 1.0 else { return nil }

            return TagDivergence(
                tag: tag,
                historicalAvg: histAvg,
                recentAvg: recAvg,
                divergence: div,
                recentCount: recent.count
            )
        }.sorted { abs($0.divergence) > abs($1.divergence) }
    }

    // MARK: - プレミアム分析 F: 回復トリガー特定

    /// 不調期→回復日のパターンからトリガーとなるタグを特定
    func recoveryTriggers(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [RecoveryTrigger] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        // 日別データ
        var dayData: [(date: Date, normAvg: Double, tags: Set<String>)] = []
        var currentDay: Date?
        var currentNorms: [Double] = []
        var currentTags = Set<String>()

        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            if day != currentDay {
                if let cd = currentDay {
                    let avg = currentNorms.reduce(0, +) / Double(currentNorms.count)
                    dayData.append((cd, avg, currentTags))
                }
                currentDay = day
                currentNorms = [entry.normalizedScore]
                currentTags = Set(entry.tags)
            } else {
                currentNorms.append(entry.normalizedScore)
                currentTags.formUnion(entry.tags)
            }
        }
        if let cd = currentDay {
            let avg = currentNorms.reduce(0, +) / Double(currentNorms.count)
            dayData.append((cd, avg, currentTags))
        }

        guard dayData.count >= 10 else { return [] }

        // 全体平均
        let overallAvg = dayData.reduce(0.0) { $0 + $1.normAvg } / Double(dayData.count)
        // 下位30%閾値
        let sortedByScore = dayData.sorted { $0.normAvg < $1.normAvg }
        let lowThresholdIndex = max(1, sortedByScore.count * 30 / 100)
        let lowThreshold = sortedByScore[lowThresholdIndex - 1].normAvg

        // 不調期(2日以上連続)→回復日(平均以上に戻る)を検出
        var recoveryEvents: [(recoveryDate: Date, tags: Set<String>, boost: Double)] = []
        var lowStreakCount = 0

        for i in 0 ..< dayData.count {
            if dayData[i].normAvg <= lowThreshold {
                lowStreakCount += 1
            } else {
                if lowStreakCount >= 2, dayData[i].normAvg >= overallAvg {
                    let boost = (dayData[i].normAvg - overallAvg) * Double(currentMax - 1)
                    recoveryEvents.append((dayData[i].date, dayData[i].tags, boost))
                }
                lowStreakCount = 0
            }
        }

        guard recoveryEvents.count >= 3 else { return [] }

        // 回復日でのタグ出現率
        var tagCounts: [String: Int] = [:]
        var tagBoosts: [String: [Double]] = [:]
        for event in recoveryEvents {
            for tag in event.tags {
                tagCounts[tag, default: 0] += 1
                tagBoosts[tag, default: []].append(event.boost)
            }
        }

        return tagCounts.map { tag, count in
            let rate = Int(Double(count) / Double(recoveryEvents.count) * 100)
            let boosts = tagBoosts[tag] ?? []
            let avgBoost = boosts.isEmpty ? 0 : boosts.reduce(0, +) / Double(boosts.count)
            return RecoveryTrigger(
                tag: tag,
                appearanceRate: rate,
                avgRecoveryBoost: avgBoost,
                sampleSize: count
            )
        }
        .filter { $0.appearanceRate >= 30 }
        .sorted { $0.appearanceRate > $1.appearanceRate }
    }

    // MARK: - プレミアム分析 G: タグシナジー分析

    /// 2つのタグの単体使用時 vs 同時使用時の平均スコアを比較
    func tagSynergyAnalysis(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [TagSynergy] {
        let taggedEntries = entries.filter { !$0.tags.isEmpty }
        guard taggedEntries.count >= 20 else { return [] }

        // タグごとの出現エントリのスコア
        var tagScores: [String: [Double]] = [:]
        for entry in taggedEntries {
            let scaled = entry.normalizedScore * Double(currentMax - currentMin) + Double(currentMin)
            for tag in entry.tags {
                tagScores[tag, default: []].append(scaled)
            }
        }

        // 共起ペアのスコア
        var pairScores: [String: [Double]] = [:]
        for entry in taggedEntries {
            guard entry.tags.count >= 2 else { continue }
            let scaled = entry.normalizedScore * Double(currentMax - currentMin) + Double(currentMin)
            let sortedTags = entry.tags.sorted()
            for i in 0 ..< sortedTags.count {
                for j in (i + 1) ..< sortedTags.count {
                    let key = "\(sortedTags[i])|\(sortedTags[j])"
                    pairScores[key, default: []].append(scaled)
                }
            }
        }

        return pairScores.compactMap { key, comboScores in
            guard comboScores.count >= 3 else { return nil }
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 2 else { return nil }

            let tag1 = parts[0], tag2 = parts[1]
            guard let scores1 = tagScores[tag1], scores1.count >= 3,
                  let scores2 = tagScores[tag2], scores2.count >= 3 else { return nil }

            // 単体時 = そのタグがある時で、もう一方のタグがない時
            let solo1Entries = taggedEntries.filter { $0.tags.contains(tag1) && !$0.tags.contains(tag2) }
            let solo2Entries = taggedEntries.filter { $0.tags.contains(tag2) && !$0.tags.contains(tag1) }
            guard solo1Entries.count >= 2, solo2Entries.count >= 2 else { return nil }

            let soloAvg1 = solo1Entries.reduce(0.0) { $0 + $1.normalizedScore * Double(currentMax - currentMin) + Double(currentMin) } / Double(solo1Entries.count)
            let soloAvg2 = solo2Entries.reduce(0.0) { $0 + $1.normalizedScore * Double(currentMax - currentMin) + Double(currentMin) } / Double(solo2Entries.count)
            let comboAvg = comboScores.reduce(0, +) / Double(comboScores.count)
            let delta = comboAvg - max(soloAvg1, soloAvg2)

            guard abs(delta) > 0.8 else { return nil }

            return TagSynergy(
                tag1: tag1,
                tag2: tag2,
                soloAvg1: soloAvg1,
                soloAvg2: soloAvg2,
                comboAvg: comboAvg,
                synergyDelta: delta,
                comboCount: comboScores.count,
                isRedZone: delta < -1.5
            )
        }.sorted { abs($0.synergyDelta) > abs($1.synergyDelta) }
    }

    // MARK: - 過去の自分との比較

    /// 1年前の同じ週の平均スコア
    func sameWeekLastYearAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let lastYearWeekStart = calendar.date(byAdding: .year, value: -1, to: thisWeekStart),
              let lastYearWeekEnd = calendar.date(byAdding: .day, value: 7, to: lastYearWeekStart)
        else { return nil }
        let weekEntries = entries.filter { $0.createdAt >= lastYearWeekStart && $0.createdAt < lastYearWeekEnd }
        return normalizedAverage(of: weekEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    /// 1年前の同じ月の平均スコア
    func sameMonthLastYearAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        let now = Date.now
        let year = calendar.component(.year, from: now) - 1
        let month = calendar.component(.month, from: now)
        guard let lastYearMonthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let lastYearMonthEnd = calendar.date(byAdding: .month, value: 1, to: lastYearMonthStart)
        else { return nil }
        let monthEntries = entries.filter { $0.createdAt >= lastYearMonthStart && $0.createdAt < lastYearMonthEnd }
        return normalizedAverage(of: monthEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    /// 去年全体の平均スコア
    func lastYearAverage(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> Double? {
        let calendar = Calendar.current
        let now = Date.now
        let lastYear = calendar.component(.year, from: now) - 1
        guard let lastYearStart = calendar.date(from: DateComponents(year: lastYear, month: 1, day: 1)),
              let lastYearEnd = calendar.date(from: DateComponents(year: lastYear + 1, month: 1, day: 1))
        else { return nil }
        let yearEntries = entries.filter { $0.createdAt >= lastYearStart && $0.createdAt < lastYearEnd }
        return normalizedAverage(of: yearEntries, scaleTo: currentMax, targetMin: currentMin)
    }

    /// 1年前比較データ
    struct PastComparison {
        let currentWeekAvg: Double?
        let lastYearSameWeekAvg: Double?
        let currentMonthAvg: Double?
        let lastYearSameMonthAvg: Double?
        let currentYearAvg: Double?
        let lastYearAvg: Double?
        let hasLastYearData: Bool
        let growthMessage: String?
    }

    /// 過去の自分との比較データを生成
    func pastComparison(entries: [MoodEntry], currentMax: Int = 10, currentMin: Int = 1) -> PastComparison {
        let lyWeek = sameWeekLastYearAverage(entries: entries, currentMax: currentMax, currentMin: currentMin)
        let lyMonth = sameMonthLastYearAverage(entries: entries, currentMax: currentMax, currentMin: currentMin)
        let lyYear = lastYearAverage(entries: entries, currentMax: currentMax, currentMin: currentMin)
        let hasData = lyWeek != nil || lyMonth != nil || lyYear != nil

        let curYear = yearlyAverage(entries: entries, currentMax: currentMax, currentMin: currentMin)
        var message: String? = nil
        if let cy = curYear, let ly = lyYear {
            let diff = cy - ly
            if diff > 0.3 {
                message = String(localized: "去年の今頃よりスコアが上がっています。あなたは成長しています")
            } else if diff >= -0.3 {
                message = String(localized: "去年と同じくらいの安定したペースです")
            } else {
                message = String(localized: "少し下がっていますが、波があるのは自然なことです")
            }
        }

        return PastComparison(
            currentWeekAvg: weeklyAverage(entries: entries, currentMax: currentMax, currentMin: currentMin),
            lastYearSameWeekAvg: lyWeek,
            currentMonthAvg: monthlyAverage(entries: entries, currentMax: currentMax, currentMin: currentMin),
            lastYearSameMonthAvg: lyMonth,
            currentYearAvg: curYear,
            lastYearAvg: lyYear,
            hasLastYearData: hasData,
            growthMessage: message
        )
    }

    // MARK: - メモキーワード分析

    /// メモ内のキーワードを抽出し、スコアとの相関を分析する
    func memoKeywordAnalysis(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [(keyword: String, avgScore: Double, count: Int)] {
        let stopWords: Set<String> = [
            "は", "が", "の", "を", "に", "で", "と", "も", "か", "な", "だ", "し", "て", "た",
            "する", "ある", "いる", "れる", "ない", "です", "ます", "こと", "もの", "ため", "よう",
        ]

        // Collect keywords per entry
        var keywordScores: [String: [Double]] = [:]
        let tokenizer = NLTokenizer(unit: .word)

        for entry in entries {
            guard let memo = entry.memo, !memo.isEmpty else { continue }
            tokenizer.string = memo
            var entryKeywords = Set<String>()
            tokenizer.enumerateTokens(in: memo.startIndex ..< memo.endIndex) { range, _ in
                let word = String(memo[range]).lowercased()
                if word.count >= 2, !stopWords.contains(word) {
                    entryKeywords.insert(word)
                }
                return true
            }
            let scaled = entry.scaledScore(to: currentMax, targetMin: currentMin)
            for keyword in entryKeywords {
                keywordScores[keyword, default: []].append(scaled)
            }
        }

        // Filter to 3+ occurrences, compute average
        var results: [(keyword: String, avgScore: Double, count: Int)] = []
        for (keyword, scores) in keywordScores where scores.count >= 3 {
            let avg = scores.reduce(0.0, +) / Double(scores.count)
            results.append((keyword: keyword, avgScore: avg, count: scores.count))
        }
        return results.sorted { $0.count > $1.count }
    }

    // MARK: - 記録元分析

    /// 記録元（app/widget/watch）ごとの平均スコアと件数を返す
    func sourceAnalysis(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [(source: String, avgScore: Double, count: Int)] {
        var grouped: [String: [MoodEntry]] = [:]
        for entry in entries {
            grouped[entry.source, default: []].append(entry)
        }
        return grouped.map { source, group in
            let avg = normalizedAverage(of: group, scaleTo: currentMax, targetMin: currentMin) ?? 0
            return (source: source, avgScore: avg, count: group.count)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - 記録タイミング分析

    /// 時間帯別の記録件数と正規化平均スコアを返す
    func recordingTimingAnalysis(entries: [MoodEntry]) -> [(hour: Int, count: Int, avgNormalized: Double)] {
        let calendar = Calendar.current
        var grouped: [Int: [MoodEntry]] = [:]
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            grouped[hour, default: []].append(entry)
        }
        return grouped
            .map { hour, group in
                let avgNorm = group.reduce(0.0) { $0 + $1.normalizedScore } / Double(group.count)
                return (hour: hour, count: group.count, avgNormalized: avgNorm)
            }
            .sorted { $0.hour < $1.hour }
    }

    // MARK: - 安定度スコア

    /// 直近N日間の安定度（0-100、100=完全に安定）を返す
    func stabilityScore(entries: [MoodEntry], days: Int = 7) -> Double? {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: .now) else { return nil }
        let recent = entries.filter { $0.createdAt >= cutoff }
        guard recent.count >= 3 else { return nil }

        let scores = recent.map { $0.normalizedScore }
        let mean = scores.reduce(0.0, +) / Double(scores.count)
        guard mean > 0 else { return 100.0 } // All zeros = stable at bottom

        let variance = scores.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(scores.count)
        let stdDev = variance.squareRoot()
        let cv = stdDev / mean

        return max(0, 100 - cv * 100)
    }

    // MARK: - 閾値ブレーク分析

    /// 個人平均を上回る/下回る連続日数のブレークを検出する
    func thresholdBreaks(entries: [MoodEntry], currentMax _: Int, currentMin _: Int = 1) -> [(type: String, days: Int, startDate: Date)] {
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        let overallAvg = entries.reduce(0.0) { $0 + $1.normalizedScore } / Double(entries.count)

        // Build daily averages sorted by date
        var dailyScores: [(date: Date, avgNormalized: Double)] = []
        var grouped: [Date: [Double]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            grouped[day, default: []].append(entry.normalizedScore)
        }
        for (day, scores) in grouped {
            let avg = scores.reduce(0.0, +) / Double(scores.count)
            dailyScores.append((date: day, avgNormalized: avg))
        }
        dailyScores.sort { $0.date < $1.date }

        // Detect consecutive streaks
        var results: [(type: String, days: Int, startDate: Date)] = []
        var currentType: String? = nil
        var streakStart: Date? = nil
        var streakCount = 0

        for daily in dailyScores {
            let type = daily.avgNormalized >= overallAvg ? "above" : "below"
            if type == currentType {
                streakCount += 1
            } else {
                // Save previous streak if 3+ days
                if let ct = currentType, streakCount >= 3, let start = streakStart {
                    results.append((type: ct, days: streakCount, startDate: start))
                }
                currentType = type
                streakStart = daily.date
                streakCount = 1
            }
        }
        // Final streak
        if let ct = currentType, streakCount >= 3, let start = streakStart {
            results.append((type: ct, days: streakCount, startDate: start))
        }

        return results.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - 天気×気分相関

    /// 天気ごとの平均スコアと件数を返す
    func weatherMoodCorrelation(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [(condition: String, avgScore: Double, count: Int)] {
        var grouped: [String: [MoodEntry]] = [:]
        for entry in entries {
            guard let condition = entry.weatherCondition else { continue }
            grouped[condition, default: []].append(entry)
        }
        return grouped.map { condition, group in
            let avg = normalizedAverage(of: group, scaleTo: currentMax, targetMin: currentMin) ?? 0
            return (condition: condition, avgScore: avg, count: group.count)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - エネルギー×気分の乖離

    /// スコアとエネルギーレベルの一致/乖離を分析する
    func energyMoodDivergence(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> (aligned: Int, divergent: Int, divergentEntries: [(date: Date, score: Int, energy: Int)]) {
        var aligned = 0
        var divergent = 0
        var divergentList: [(date: Date, score: Int, energy: Int)] = []

        for entry in entries {
            guard let energy = entry.energyLevel else { continue }
            let normalized = entry.normalizedScore
            let highScore = normalized >= 0.5
            let highEnergy = energy == 3
            let lowEnergy = energy == 1

            if energy == 2 {
                // Neutral energy is always considered aligned
                aligned += 1
            } else if (highScore && highEnergy) || (!highScore && lowEnergy) {
                aligned += 1
            } else {
                divergent += 1
                let scaled = Int(entry.scaledScore(to: currentMax, targetMin: currentMin).rounded())
                divergentList.append((date: entry.createdAt, score: scaled, energy: energy))
            }
        }

        // Return up to 5 most recent divergent entries
        let recentDivergent = divergentList.sorted { $0.date > $1.date }.prefix(5)
        return (aligned: aligned, divergent: divergent, divergentEntries: Array(recentDivergent))
    }

    // MARK: - 場所×気分分析

    /// 場所タグごとの平均スコアと件数を返す
    func locationMoodAnalysis(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [(location: String, avgScore: Double, count: Int)] {
        let locationTags: Set<String> = [
            "自宅", "職場/学校", "外出先", "移動中",
            "Home", "Work/School", "Outside", "Commuting",
        ]

        var grouped: [String: [MoodEntry]] = [:]
        for entry in entries {
            for tag in entry.tags {
                if locationTags.contains(tag) {
                    grouped[tag, default: []].append(entry)
                }
            }
        }

        return grouped.map { location, group in
            let avg = normalizedAverage(of: group, scaleTo: currentMax, targetMin: currentMin) ?? 0
            return (location: location, avgScore: avg, count: group.count)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - 回復パターン分析

    /// 低調期からの回復パターンを検出する
    func recoveryPatterns(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [RecoveryEvent] {
        guard entries.count >= 3 else { return [] }

        let calendar = Calendar.current
        let overallAvg = entries.reduce(0.0) { $0 + $1.normalizedScore } / Double(entries.count)
        let lowThreshold = overallAvg - 0.15

        // Build daily data sorted by date
        var dailyData: [(date: Date, avgNormalized: Double, tags: [String])] = []
        var grouped: [Date: [MoodEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            grouped[day, default: []].append(entry)
        }
        for (day, dayEntries) in grouped {
            let avg = dayEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(dayEntries.count)
            let allTags = dayEntries.flatMap { $0.tags }
            dailyData.append((date: day, avgNormalized: avg, tags: allTags))
        }
        dailyData.sort { $0.date < $1.date }

        guard dailyData.count >= 3 else { return [] }

        // Detect low periods and recovery
        var results: [RecoveryEvent] = []
        var lowStart: Int? = nil
        var lowDays = 0

        for i in 0 ..< dailyData.count {
            let isLow = dailyData[i].avgNormalized < lowThreshold

            if isLow {
                if lowStart == nil {
                    lowStart = i
                    lowDays = 1
                } else {
                    lowDays += 1
                }
            } else {
                // Check if we had a valid low period (2+ days)
                if let start = lowStart, lowDays >= 2 {
                    let isRecovery = dailyData[i].avgNormalized >= overallAvg
                    if isRecovery {
                        let lowScores = (start ..< i).map { dailyData[$0].avgNormalized }
                        let avgLow = lowScores.reduce(0.0, +) / Double(lowScores.count)
                        let event = RecoveryEvent(
                            lowPeriodStart: dailyData[start].date,
                            recoveryDate: dailyData[i].date,
                            daysToRecover: lowDays,
                            recoveryTags: dailyData[i].tags,
                            lowScore: avgLow * Double(currentMax - currentMin) + Double(currentMin),
                            recoveryScore: dailyData[i].avgNormalized * Double(currentMax - currentMin) + Double(currentMin)
                        )
                        results.append(event)
                    }
                }
                lowStart = nil
                lowDays = 0
            }
        }

        return results.sorted { $0.recoveryDate > $1.recoveryDate }
    }

    // MARK: - ワークアウト種類×気分分析

    struct WorkoutMoodResult {
        let workoutType: String
        let averageScore: Double
        let nextDayAverageScore: Double?
        let count: Int
    }

    /// Analyze mood by workout type (same day + next day effect)
    func workoutMoodAnalysis(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [WorkoutMoodResult] {
        let calendar = Calendar.current
        let metricsByDate = Dictionary(uniqueKeysWithValues: metrics.map { (calendar.startOfDay(for: $0.date), $0) })
        let entriesByDate = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }

        var workoutScores: [String: [(sameDay: Double, nextDay: Double?)]] = [:]

        for (date, metric) in metricsByDate {
            guard let type = metric.workoutType, metric.workoutMinutes ?? 0 > 10 else { continue }
            guard let dayEntries = entriesByDate[date], !dayEntries.isEmpty else { continue }

            let sameDayAvg = dayEntries.map(\.normalizedScore).reduce(0, +) / Double(dayEntries.count)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
            let nextDayEntries = entriesByDate[nextDay]
            let nextDayAvg = nextDayEntries.map { es in
                es.map(\.normalizedScore).reduce(0, +) / Double(es.count)
            }

            workoutScores[type, default: []].append((sameDayAvg, nextDayAvg))
        }

        return workoutScores.compactMap { type, scores in
            guard scores.count >= 3 else { return nil }
            let avgSame = scores.map(\.sameDay).reduce(0, +) / Double(scores.count) * Double(currentMax - currentMin) + Double(currentMin)
            let nextDayScores = scores.compactMap(\.nextDay)
            let avgNext = nextDayScores.count >= 3 ? nextDayScores.reduce(0, +) / Double(nextDayScores.count) * Double(currentMax - currentMin) + Double(currentMin) : nil
            return WorkoutMoodResult(workoutType: type, averageScore: avgSame, nextDayAverageScore: avgNext, count: scores.count)
        }.sorted { $0.averageScore > $1.averageScore }
    }

    // MARK: - イヤホン使用時間×気分分析

    struct HeadphoneMoodResult {
        let bucket: String // "0-1h", "1-3h", "3-5h", "5h+"
        let averageScore: Double
        let count: Int
    }

    /// Analyze mood by headphone usage duration buckets
    func headphoneMoodAnalysis(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [HeadphoneMoodResult] {
        let calendar = Calendar.current
        let entriesByDate = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }

        var buckets: [String: [Double]] = [
            "0-1h": [], "1-3h": [], "3-5h": [], "5h+": [],
        ]

        for metric in metrics {
            guard let minutes = metric.headphoneMinutes else { continue }
            let date = calendar.startOfDay(for: metric.date)
            guard let dayEntries = entriesByDate[date], !dayEntries.isEmpty else { continue }
            let avg = dayEntries.map(\.normalizedScore).reduce(0, +) / Double(dayEntries.count)

            let hours = minutes / 60.0
            let bucket: String
            switch hours {
            case ..<1: bucket = "0-1h"
            case ..<3: bucket = "1-3h"
            case ..<5: bucket = "3-5h"
            default: bucket = "5h+"
            }
            buckets[bucket, default: []].append(avg)
        }

        let order = ["0-1h", "1-3h", "3-5h", "5h+"]
        return order.compactMap { key in
            guard let scores = buckets[key], scores.count >= 2 else { return nil }
            let avg = scores.reduce(0, +) / Double(scores.count) * Double(currentMax - currentMin) + Double(currentMin)
            return HeadphoneMoodResult(bucket: key, averageScore: avg, count: scores.count)
        }
    }

    // MARK: - 運動時間×気分分析（閾値発見）

    struct ExerciseThresholdResult {
        let thresholdMinutes: Int
        let aboveAverage: Double
        let belowAverage: Double
        let aboveCount: Int
        let belowCount: Int
        let delta: Double // above - below
    }

    /// Find the exercise threshold where mood significantly improves
    func exerciseThresholdAnalysis(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> ExerciseThresholdResult? {
        let calendar = Calendar.current
        let entriesByDate = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }

        var paired: [(minutes: Double, score: Double)] = []
        for metric in metrics {
            guard let minutes = metric.exerciseMinutes else { continue }
            let date = calendar.startOfDay(for: metric.date)
            guard let dayEntries = entriesByDate[date], !dayEntries.isEmpty else { continue }
            let avg = dayEntries.map(\.normalizedScore).reduce(0, +) / Double(dayEntries.count)
            paired.append((minutes, avg))
        }

        guard paired.count >= 10 else { return nil }

        // Try thresholds at 15, 30, 45, 60 minutes - find best split
        var bestResult: ExerciseThresholdResult?
        var bestDelta = 0.0

        for threshold in [15, 30, 45, 60] {
            let above = paired.filter { $0.minutes >= Double(threshold) }
            let below = paired.filter { $0.minutes < Double(threshold) }
            guard above.count >= 3, below.count >= 3 else { continue }

            let aboveAvg = above.map(\.score).reduce(0, +) / Double(above.count)
            let belowAvg = below.map(\.score).reduce(0, +) / Double(below.count)
            let delta = (aboveAvg - belowAvg) * Double(currentMax - currentMin)

            if delta > bestDelta {
                bestDelta = delta
                bestResult = ExerciseThresholdResult(
                    thresholdMinutes: threshold,
                    aboveAverage: aboveAvg * Double(currentMax - currentMin) + Double(currentMin),
                    belowAverage: belowAvg * Double(currentMax - currentMin) + Double(currentMin),
                    aboveCount: above.count,
                    belowCount: below.count,
                    delta: delta
                )
            }
        }

        return bestResult
    }

    // MARK: - HRV×気分分析（ストレス乖離検出）

    struct HRVMoodResult {
        let averageHRV: Double
        let lowHRVScore: Double // HRV below median → mood
        let highHRVScore: Double // HRV above median → mood
        let divergenceDetected: Bool // HRV says stressed but mood says fine
        let divergenceCount: Int
        let totalCount: Int
    }

    /// Analyze HRV vs mood, detect divergence (objective stress vs subjective mood)
    func hrvMoodAnalysis(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> HRVMoodResult? {
        let calendar = Calendar.current
        let entriesByDate = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }

        var paired: [(hrv: Double, score: Double)] = []
        for metric in metrics {
            guard let hrv = metric.hrvSDNN else { continue }
            let date = calendar.startOfDay(for: metric.date)
            guard let dayEntries = entriesByDate[date], !dayEntries.isEmpty else { continue }
            let avg = dayEntries.map(\.normalizedScore).reduce(0, +) / Double(dayEntries.count)
            paired.append((hrv, avg))
        }

        guard paired.count >= 7 else { return nil }

        let avgHRV = paired.map(\.hrv).reduce(0, +) / Double(paired.count)
        let medianHRV = paired.map(\.hrv).sorted()[paired.count / 2]

        let lowHRV = paired.filter { $0.hrv < medianHRV }
        let highHRV = paired.filter { $0.hrv >= medianHRV }

        guard lowHRV.count >= 3, highHRV.count >= 3 else { return nil }

        let lowAvg = lowHRV.map(\.score).reduce(0, +) / Double(lowHRV.count)
        let highAvg = highHRV.map(\.score).reduce(0, +) / Double(highHRV.count)

        // Divergence: HRV is low (stressed) but mood is high (top 40%)
        let overallScoreMedian = paired.map(\.score).sorted()[paired.count / 2]
        let divergent = paired.filter { $0.hrv < medianHRV * 0.8 && $0.score > overallScoreMedian * 1.1 }

        return HRVMoodResult(
            averageHRV: avgHRV,
            lowHRVScore: lowAvg * Double(currentMax - currentMin) + Double(currentMin),
            highHRVScore: highAvg * Double(currentMax - currentMin) + Double(currentMin),
            divergenceDetected: divergent.count >= 2,
            divergenceCount: divergent.count,
            totalCount: paired.count
        )
    }

    // MARK: - ヘルパー

    /// 正規化ベースの平均を算出し、指定レンジにスケールする
    private func normalizedAverage(of entries: [MoodEntry], scaleTo targetMax: Int, targetMin: Int = 1) -> Double? {
        guard !entries.isEmpty else { return nil }
        let avgNormalized = entries.reduce(0.0) { $0 + $1.normalizedScore } / Double(entries.count)
        return avgNormalized * Double(targetMax - targetMin) + Double(targetMin)
    }
}
