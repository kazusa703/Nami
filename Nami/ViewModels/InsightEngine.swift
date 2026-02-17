//
//  InsightEngine.swift
//  Nami
//
//  パーソナルインサイトの自動生成エンジン
//  既存データ（曜日別平均、タグ翌日効果、時間帯別等）を組み合わせて
//  「気づき」をカード形式で生成する
//

import Foundation
import SwiftUI

// MARK: - インサイトの感情トーン

/// インサイトカードの感情トーン（色分け用）
enum InsightTone {
    case positive    // ポジティブな発見（緑系）
    case caution     // 注意喚起（オレンジ系）
    case neutral     // ニュートラルな観察（青系）
    case discovery   // 新しい発見（紫系）

    var color: Color {
        switch self {
        case .positive: return .green
        case .caution: return .orange
        case .neutral: return .blue
        case .discovery: return .purple
        }
    }
}

// MARK: - インサイトカード

/// 表示用インサイトカード
struct InsightCard: Identifiable {
    let id: String         // 同一インサイトの重複防止 + ローテーション用
    let icon: String       // SF Symbols
    let tone: InsightTone
    let title: String      // 短いタイトル（例: "水曜日の傾向"）
    let body: String       // 本文（問いかけ形式、断定しすぎない）
    let priority: Double   // 0.0〜1.0（高いほど優先表示）
}

// MARK: - インサイトエンジン

/// データからパーソナルインサイトを自動生成するエンジン
/// 各インサイトタイプの条件チェック → 計算 → 優先度スコア算出 → 上位3-5枚を返す
enum InsightEngine {

    // MARK: - しきい値定数（インサイトタイプごとの最低サンプル数）

    /// 全体の最低エントリ数（これ未満ならインサイト非表示）
    static let minimumTotalEntries = 20
    /// 曜日別分析の最低サンプル数（各曜日あたり）
    static let minimumWeekdaySamples = 3
    /// タグ翌日効果の最低サンプル数（対象タグ）
    static let minimumTagNextDaySamples = 5
    /// 時間帯分析の最低サンプル数
    static let minimumTimeOfDaySamples = 5
    /// ボラティリティ比較の最低週数
    static let minimumVolatilityWeeks = 4
    /// タグ共起の最低回数
    static let minimumCoOccurrence = 3
    /// タグ数vsスコアの最低エントリ数
    static let minimumTagCountEntries = 20
    /// 週末vs平日の各側最低サンプル数
    static let minimumWeekendSamples = 5
    /// 表示するインサイトの最大数
    static let maxDisplayCards = 5

    // MARK: - メイン生成メソッド

    /// エントリデータからインサイトカードを生成する
    /// - Parameters:
    ///   - entries: 全エントリ
    ///   - currentMax: 現在のスコア範囲上限
    /// - Returns: 優先度順のインサイトカード（最大5枚）
    static func generate(from entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        guard entries.count >= minimumTotalEntries else { return [] }

        var candidates: [InsightCard] = []

        // 各インサイトタイプの生成を試行
        candidates.append(contentsOf: weekdayInsights(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: tagNextDayInsights(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: volatilityInsight(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: timeOfDayInsights(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: streakInsight(entries: entries))
        candidates.append(contentsOf: weeklyTrendInsight(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: tagCoOccurrenceInsight(entries: entries))
        candidates.append(contentsOf: tagCountInsight(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: weekendComparisonInsight(entries: entries, currentMax: currentMax))
        candidates.append(contentsOf: recordFrequencyInsight(entries: entries, currentMax: currentMax))

        // 日付ベースのローテーションを適用して上位N枚を返す
        return applyRotation(candidates: candidates)
    }

    // MARK: - 1. 曜日別インサイト（落ち込み / ピーク）

    private static func weekdayInsights(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current
        var grouped: [Int: [Double]] = [:]

        for entry in entries {
            let wd = calendar.component(.weekday, from: entry.createdAt)
            grouped[wd, default: []].append(entry.normalizedScore)
        }

        let validDays = grouped.filter { $0.value.count >= minimumWeekdaySamples }
        guard validDays.count >= 5 else { return [] }

        let overallAvg = avg(entries.map(\.normalizedScore))
        let weekdayNames = ["", "日", "月", "火", "水", "木", "金", "土"]
        var results: [InsightCard] = []

        // 最も低い曜日
        if let (lowDay, lowScores) = validDays.min(by: { avg($0.value) < avg($1.value) }) {
            let deviation = overallAvg - avg(lowScores)
            if deviation > 0.08 {
                let scaledDiff = deviation * Double(currentMax - 1)
                results.append(InsightCard(
                    id: "weekday_low_\(lowDay)",
                    icon: "calendar.badge.minus",
                    tone: .caution,
                    title: "\(weekdayNames[lowDay])曜日の傾向",
                    body: "\(weekdayNames[lowDay])曜日は気分が下がりやすい傾向があります（平均 \(fmt(scaledDiff))pt 低い）。この日に小さなご褒美を入れてみては？",
                    priority: min(deviation * 5, 0.9)
                ))
            }
        }

        // 最も高い曜日
        if let (highDay, highScores) = validDays.max(by: { avg($0.value) < avg($1.value) }) {
            let deviation = avg(highScores) - overallAvg
            if deviation > 0.08 {
                let scaledDiff = deviation * Double(currentMax - 1)
                results.append(InsightCard(
                    id: "weekday_high_\(highDay)",
                    icon: "calendar.badge.plus",
                    tone: .positive,
                    title: "\(weekdayNames[highDay])曜日が好調",
                    body: "\(weekdayNames[highDay])曜日はスコアが平均 +\(fmt(scaledDiff))。この日に何か良い習慣がありますか？",
                    priority: min(deviation * 4, 0.85)
                ))
            }
        }

        return results
    }

    // MARK: - 2. タグ翌日効果インサイト

    private static func tagNextDayInsights(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        let overallNorm = avg(sorted.map(\.normalizedScore))

        // 日別にグルーピング
        var dayEntries: [Date: [MoodEntry]] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayEntries[day, default: []].append(entry)
        }

        // タグごとに翌日スコアを集計
        var tagNextDayNorm: [String: [Double]] = [:]
        let allDays = dayEntries.keys.sorted()

        for day in allDays {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  let nextGroup = dayEntries[nextDay] else { continue }
            let nextAvgNorm = avg(nextGroup.map(\.normalizedScore))

            let todayTags = Set(dayEntries[day]?.flatMap(\.tags) ?? [])
            for tag in todayTags {
                tagNextDayNorm[tag, default: []].append(nextAvgNorm)
            }
        }

        var results: [InsightCard] = []

        for (tag, scores) in tagNextDayNorm {
            guard scores.count >= minimumTagNextDaySamples else { continue }
            let deltaNorm = avg(scores) - overallNorm
            let deltaScaled = deltaNorm * Double(currentMax - 1)

            if deltaNorm > 0.06 {
                results.append(InsightCard(
                    id: "tag_nextday_pos_\(tag)",
                    icon: "arrow.up.heart.fill",
                    tone: .positive,
                    title: "「\(tag)」の翌日効果",
                    body: "「\(tag)」の翌日、スコアが平均 +\(fmt(deltaScaled))。あなたの気分に良い影響を与えているようです。",
                    priority: min(deltaNorm * 6, 0.95)
                ))
            } else if deltaNorm < -0.06 {
                results.append(InsightCard(
                    id: "tag_nextday_neg_\(tag)",
                    icon: "arrow.down.heart.fill",
                    tone: .caution,
                    title: "「\(tag)」の翌日",
                    body: "「\(tag)」の翌日はスコアが平均 \(fmt(deltaScaled))。回復のための工夫を試してみては？",
                    priority: min(abs(deltaNorm) * 5, 0.9)
                ))
            }
        }

        // 最も効果の大きいもの上位2件
        return Array(results.sorted { $0.priority > $1.priority }.prefix(2))
    }

    // MARK: - 3. ボラティリティ変化インサイト

    private static func volatilityInsight(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }

        // 週ごとにグルーピング
        var weeklyGroups: [(scores: [Double], start: Date)] = []
        var currentWeekStart: Date?
        var currentWeekScores: [Double] = []

        for entry in sorted {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: entry.createdAt) else { continue }
            let weekStart = weekInterval.start

            if weekStart != currentWeekStart {
                if let start = currentWeekStart, currentWeekScores.count >= 2 {
                    weeklyGroups.append((currentWeekScores, start))
                }
                currentWeekStart = weekStart
                currentWeekScores = []
            }
            currentWeekScores.append(entry.normalizedScore)
        }
        if let start = currentWeekStart, currentWeekScores.count >= 2 {
            weeklyGroups.append((currentWeekScores, start))
        }

        guard weeklyGroups.count >= minimumVolatilityWeeks else { return [] }

        // 直近2週 vs その前2週の標準偏差を比較
        let recentScores = weeklyGroups.suffix(2).flatMap(\.scores)
        let previousScores = Array(weeklyGroups.dropLast(2).suffix(2)).flatMap(\.scores)
        guard previousScores.count >= 4 else { return [] }

        let recentStd = stdDev(recentScores) * Double(currentMax - 1)
        let previousStd = stdDev(previousScores) * Double(currentMax - 1)
        let change = recentStd - previousStd

        guard abs(change) > 0.5 else { return [] }

        if change < 0 {
            return [InsightCard(
                id: "volatility_stable",
                icon: "waveform.path",
                tone: .positive,
                title: "気分が安定化",
                body: "最近の気分の波が穏やかになっています（変動幅 \(fmt(previousStd)) → \(fmt(recentStd))）。良いリズムが掴めているのかもしれません。",
                priority: min(abs(change) / 3.0, 0.85)
            )]
        } else {
            return [InsightCard(
                id: "volatility_unstable",
                icon: "waveform.path.ecg",
                tone: .caution,
                title: "気分の波が大きめ",
                body: "最近の気分の変動が大きくなっています（変動幅 \(fmt(previousStd)) → \(fmt(recentStd))）。生活に変化はありましたか？",
                priority: min(abs(change) / 3.0, 0.8)
            )]
        }
    }

    // MARK: - 4. 時間帯インサイト

    private static func timeOfDayInsights(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current
        var grouped: [TimeOfDay: [Double]] = [:]

        for entry in entries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            let tod = TimeOfDay.from(hour: hour)
            grouped[tod, default: []].append(entry.normalizedScore)
        }

        let validGroups = grouped.filter { $0.value.count >= minimumTimeOfDaySamples }
        guard validGroups.count >= 2 else { return [] }

        let overallAvg = avg(entries.map(\.normalizedScore))

        // 最も低い時間帯
        if let (lowTod, lowScores) = validGroups.min(by: { avg($0.value) < avg($1.value) }) {
            let deviation = overallAvg - avg(lowScores)
            if deviation > 0.08 {
                let scaledDiff = deviation * Double(currentMax - 1)
                let advice = lowTod == .night
                    ? "疲れが出る時間帯かもしれません。"
                    : "この時間帯にリフレッシュを取り入れてみては？"
                return [InsightCard(
                    id: "tod_low_\(lowTod.rawValue)",
                    icon: lowTod.icon,
                    tone: .caution,
                    title: "\(lowTod.label)の傾向",
                    body: "\(lowTod.timeRange)のスコアが平均より \(fmt(scaledDiff))pt 低め。\(advice)",
                    priority: min(deviation * 4, 0.8)
                )]
            }
        }

        return []
    }

    // MARK: - 5. ストリークインサイト（マイルストーン達成時のみ）

    private static func streakInsight(entries: [MoodEntry]) -> [InsightCard] {
        let calendar = Calendar.current
        var recordedDays = Set<Date>()
        for entry in entries {
            recordedDays.insert(calendar.startOfDay(for: entry.createdAt))
        }

        let today = calendar.startOfDay(for: .now)
        var streak = 0
        var checkDate = today

        if !recordedDays.contains(today) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            guard recordedDays.contains(yesterday) else { return [] }
            checkDate = yesterday
        }

        while recordedDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        // マイルストーン到達から3日間表示
        let milestones = [7, 14, 21, 30, 50, 100, 200, 365]
        for milestone in milestones {
            if streak >= milestone && streak < milestone + 3 {
                return [InsightCard(
                    id: "streak_\(milestone)",
                    icon: "flame.fill",
                    tone: .positive,
                    title: "\(milestone)日達成！",
                    body: "\(streak)日連続で記録を続けています。小さな習慣の積み重ねが、自己理解を深めています。",
                    priority: 0.95
                )]
            }
        }

        return []
    }

    // MARK: - 6. 週間トレンドインサイト

    private static func weeklyTrendInsight(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let twoWeeksAgoStart = calendar.date(byAdding: .weekOfYear, value: -2, to: thisWeekStart)!

        let thisWeek = entries.filter { $0.createdAt >= thisWeekStart }
        let lastWeek = entries.filter { $0.createdAt >= lastWeekStart && $0.createdAt < thisWeekStart }
        let twoWeeksAgo = entries.filter { $0.createdAt >= twoWeeksAgoStart && $0.createdAt < lastWeekStart }

        guard thisWeek.count >= 3, lastWeek.count >= 3 else { return [] }

        let thisAvgNorm = avg(thisWeek.map(\.normalizedScore))
        let lastAvgNorm = avg(lastWeek.map(\.normalizedScore))
        let delta = (thisAvgNorm - lastAvgNorm) * Double(currentMax - 1)

        if delta > 1.0 {
            var body = "今週は先週より平均 +\(fmt(delta))。"
            if twoWeeksAgo.count >= 3 {
                let twoWeeksAvgNorm = avg(twoWeeksAgo.map(\.normalizedScore))
                body += lastAvgNorm > twoWeeksAvgNorm
                    ? "2週連続で上向いています。良い流れですね！"
                    : "先週からの回復が見られます。"
            } else {
                body += "良い調子が続いているようです。"
            }
            return [InsightCard(
                id: "weekly_up",
                icon: "chart.line.uptrend.xyaxis",
                tone: .positive,
                title: "今週は好調",
                body: body,
                priority: min(delta / 5.0, 0.85)
            )]
        } else if delta < -1.0 {
            return [InsightCard(
                id: "weekly_down",
                icon: "chart.line.downtrend.xyaxis",
                tone: .neutral,
                title: "少しお疲れの週",
                body: "今週は先週より平均 \(fmt(delta))。無理せず、自分をいたわる時間を作ってみてください。",
                priority: min(abs(delta) / 5.0, 0.8)
            )]
        }

        return []
    }

    // MARK: - 7. タグ共起インサイト

    private static func tagCoOccurrenceInsight(entries: [MoodEntry]) -> [InsightCard] {
        let taggedEntries = entries.filter { $0.tags.count >= 2 }
        guard taggedEntries.count >= 10 else { return [] }

        var pairs: [String: Int] = [:]
        var tagCounts: [String: Int] = [:]

        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
            let sorted = entry.tags.sorted()
            for i in 0..<sorted.count {
                for j in (i + 1)..<sorted.count {
                    pairs["\(sorted[i])|\(sorted[j])", default: 0] += 1
                }
            }
        }

        // 共起率が高いペアを探す
        guard let topPair = pairs.max(by: { $0.value < $1.value }),
              topPair.value >= minimumCoOccurrence else { return [] }

        let parts = topPair.key.split(separator: "|").map(String.init)
        let tag1 = parts[0], tag2 = parts[1]
        let minCount = min(tagCounts[tag1] ?? 0, tagCounts[tag2] ?? 0)
        guard minCount > 0 else { return [] }
        let coRate = Int(Double(topPair.value) / Double(minCount) * 100)

        guard coRate >= 40 else { return [] }

        return [InsightCard(
            id: "cooccur_\(tag1)_\(tag2)",
            icon: "link",
            tone: .discovery,
            title: "つながりの発見",
            body: "「\(tag1)」と「\(tag2)」は一緒に記録されることが多い（共起率\(coRate)%）。この2つはあなたの中でつながっているのかもしれません。",
            priority: min(Double(coRate) / 150.0, 0.75)
        )]
    }

    // MARK: - 8. タグ数vsスコア インサイト

    private static func tagCountInsight(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        guard entries.count >= minimumTagCountEntries else { return [] }

        let overallNormAvg = avg(entries.map(\.normalizedScore))
        let highEntries = entries.filter { $0.normalizedScore >= overallNormAvg }
        let lowEntries = entries.filter { $0.normalizedScore < overallNormAvg }

        guard !highEntries.isEmpty, !lowEntries.isEmpty else { return [] }

        let highTagAvg = Double(highEntries.reduce(0) { $0 + $1.tags.count }) / Double(highEntries.count)
        let lowTagAvg = Double(lowEntries.reduce(0) { $0 + $1.tags.count }) / Double(lowEntries.count)
        let midScaled = overallNormAvg * Double(currentMax - 1) + 1.0

        guard highTagAvg - lowTagAvg > 0.5 else { return [] }

        return [InsightCard(
            id: "tagcount_effect",
            icon: "tag.fill",
            tone: .discovery,
            title: "タグ数と気分",
            body: "スコア\(String(format: "%.0f", midScaled))以上の日は平均\(fmt(highTagAvg))個のタグ、それ以下は\(fmt(lowTagAvg))個。気持ちを言語化できている日ほど調子が良いのかもしれません。",
            priority: min((highTagAvg - lowTagAvg) / 3.0, 0.7)
        )]
    }

    // MARK: - 9. 週末vs平日 インサイト

    private static func weekendComparisonInsight(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current

        let weekdayEntries = entries.filter {
            let wd = calendar.component(.weekday, from: $0.createdAt)
            return wd >= 2 && wd <= 6
        }
        let weekendEntries = entries.filter {
            let wd = calendar.component(.weekday, from: $0.createdAt)
            return wd == 1 || wd == 7
        }

        guard weekdayEntries.count >= minimumWeekendSamples,
              weekendEntries.count >= minimumWeekendSamples else { return [] }

        let weekdayAvg = avg(weekdayEntries.map(\.normalizedScore))
        let weekendAvg = avg(weekendEntries.map(\.normalizedScore))
        let deltaNorm = weekendAvg - weekdayAvg
        let deltaScaled = deltaNorm * Double(currentMax - 1)

        guard abs(deltaScaled) > 0.8 else { return [] }

        if deltaScaled > 0 {
            return [InsightCard(
                id: "weekend_higher",
                icon: "sun.and.horizon.fill",
                tone: .neutral,
                title: "週末がリフレッシュに",
                body: "週末のスコアは平日より平均 +\(fmt(deltaScaled))。お休みの日がしっかりエネルギー回復になっているようです。",
                priority: min(abs(deltaNorm) * 3, 0.7)
            )]
        } else {
            return [InsightCard(
                id: "weekday_higher",
                icon: "briefcase.fill",
                tone: .discovery,
                title: "平日が充実",
                body: "意外にも平日のスコアが週末より +\(fmt(abs(deltaScaled)))。仕事や日常の活動がエネルギーになっているのかも？",
                priority: min(abs(deltaNorm) * 3, 0.7)
            )]
        }
    }

    // MARK: - 10. 記録頻度インサイト

    private static func recordFrequencyInsight(entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        let calendar = Calendar.current
        var dayEntries: [Date: [MoodEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayEntries[day, default: []].append(entry)
        }

        guard dayEntries.count >= 14 else { return [] }

        let multiDays = dayEntries.filter { $0.value.count >= 2 }
        let singleDays = dayEntries.filter { $0.value.count == 1 }

        guard multiDays.count >= 5, singleDays.count >= 5 else { return [] }

        let multiAvg = avg(multiDays.values.map { avg($0.map(\.normalizedScore)) })
        let singleAvg = avg(singleDays.values.map { avg($0.map(\.normalizedScore)) })
        let deltaScaled = (multiAvg - singleAvg) * Double(currentMax - 1)

        guard deltaScaled > 0.5 else { return [] }

        return [InsightCard(
            id: "record_freq",
            icon: "square.and.pencil",
            tone: .discovery,
            title: "記録回数の効果",
            body: "1日に複数回記録した日はスコアが平均 +\(fmt(deltaScaled))。こまめな記録自体が気分に良い影響を与えているのかもしれません。",
            priority: min((multiAvg - singleAvg) * 3, 0.7)
        )]
    }


    // MARK: - プレミアムインサイト生成

    /// プレミアム限定のインサイトカードを生成する
    /// - Parameters:
    ///   - entries: 全エントリ
    ///   - currentMax: 現在のスコア範囲上限
    /// - Returns: プレミアムインサイトカード（最大3枚）
    static func generatePremium(from entries: [MoodEntry], currentMax: Int) -> [InsightCard] {
        guard entries.count >= minimumTotalEntries else { return [] }
        let statsVM = StatsViewModel()
        var candidates: [InsightCard] = []

        // 1. 逆インサイト
        let reverse = statsVM.reverseInsights(entries: entries, currentMax: currentMax)
        if let topAbsent = reverse.highAbsentTags.first, topAbsent.rate >= 70 {
            candidates.append(InsightCard(
                id: "premium_reverse_absent_\(topAbsent.tag)",
                icon: "eye.slash.fill",
                tone: .discovery,
                title: String(localized: "好調の秘密"),
                body: String(localized: "あなたの好調の秘密は「\(topAbsent.tag)」がないことかもしれません（好調時の不在率\(topAbsent.rate)%）"),
                priority: 0.95
            ))
        } else if let topHigh = reverse.highTags.first, topHigh.rate >= 40 {
            candidates.append(InsightCard(
                id: "premium_reverse_high_\(topHigh.tag)",
                icon: "sparkles",
                tone: .positive,
                title: String(localized: "好調のカギ"),
                body: String(localized: "好調な日の\(topHigh.rate)%で「\(topHigh.tag)」が記録されています。あなたの気分を支えるキータグです。"),
                priority: 0.9
            ))
        }

        // 2. ズレ検出
        let divergences = statsVM.actionScoreDivergence(entries: entries, currentMax: currentMax)
        if let worst = divergences.first(where: { $0.divergence < -1.0 }) {
            candidates.append(InsightCard(
                id: "premium_divergence_\(worst.tag)",
                icon: "exclamationmark.triangle.fill",
                tone: .caution,
                title: String(localized: "効果の変化"),
                body: String(localized: "最近、普段ならスコアが上がるはずの「\(worst.tag)」が効いていません（通常\(fmt(worst.historicalAvg)) → 最近\(fmt(worst.recentAvg))）"),
                priority: 0.92
            ))
        }

        // 3. 回復トリガー
        let triggers = statsVM.recoveryTriggers(entries: entries, currentMax: currentMax)
        if let top = triggers.first, top.appearanceRate >= 50 {
            candidates.append(InsightCard(
                id: "premium_recovery_\(top.tag)",
                icon: "arrow.up.heart.fill",
                tone: .positive,
                title: String(localized: "回復のカギ"),
                body: String(localized: "スコアが低い時期からの回復時、\(top.appearanceRate)%で「\(top.tag)」が最初のトリガーです"),
                priority: 0.93
            ))
        }

        return Array(candidates.sorted { $0.priority > $1.priority }.prefix(3))
    }

    // MARK: - ローテーションロジック

    /// 日付ベースのシード値でカードの順序を微調整し、
    /// 毎日少しずつ違うカードが表示されるようにする
    private static func applyRotation(candidates: [InsightCard]) -> [InsightCard] {
        guard !candidates.isEmpty else { return [] }

        let daysSinceEpoch = Int(Date.now.timeIntervalSince1970 / 86400)

        // 各カードの優先度にシードベースのノイズ（±0.1）を加える
        let adjusted = candidates.map { card -> InsightCard in
            let hash = (card.id.hashValue &+ daysSinceEpoch) & 0x7FFFFFFF
            let noise = Double(hash % 100) / 1000.0  // 0.0〜0.099
            return InsightCard(
                id: card.id,
                icon: card.icon,
                tone: card.tone,
                title: card.title,
                body: card.body,
                priority: card.priority + noise
            )
        }

        // 優先度順にソートして上位N枚を返す
        return Array(adjusted.sorted { $0.priority > $1.priority }.prefix(maxDisplayCards))
    }

    // MARK: - ヘルパー

    private static func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0.0, +) / Double(values.count)
    }

    private static func stdDev(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = avg(values)
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance)
    }

    /// 小数点1桁フォーマット
    private static func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
