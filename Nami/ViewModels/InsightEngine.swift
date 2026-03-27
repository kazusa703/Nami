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
    case positive // ポジティブな発見（緑系）
    case caution // 注意喚起（オレンジ系）
    case neutral // ニュートラルな観察（青系）
    case discovery // 新しい発見（紫系）

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
    let id: String // 同一インサイトの重複防止 + ローテーション用
    let icon: String // SF Symbols
    let tone: InsightTone
    let title: String // 短いタイトル（例: "水曜日の傾向"）
    let body: String // 本文（問いかけ形式、断定しすぎない）
    let priority: Double // 0.0〜1.0（高いほど優先表示）
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

    // MARK: - Insight View Count Tracking

    /// Tracks how many times each insight has been shown
    private static var insightViewCounts: [String: Int] {
        get {
            (UserDefaults.standard.dictionary(forKey: "insightViewCounts") as? [String: Int]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "insightViewCounts")
        }
    }

    /// Increment view count for displayed insights.
    /// NOTE: Call this from StatsView when insights are displayed to the user.
    static func markInsightsAsViewed(_ insights: [InsightCard]) {
        var counts = insightViewCounts
        for insight in insights {
            counts[insight.id, default: 0] += 1
        }
        insightViewCounts = counts
    }

    // MARK: - Question/Discovery Alternating Styles

    enum InsightStyle { case statement, question, comparison }

    private static func styleForDay(_ cardId: String, daysSinceEpoch: Int) -> InsightStyle {
        let hash = (cardId.hashValue &+ daysSinceEpoch) & 0x7FFF_FFFF
        switch hash % 3 {
        case 0: return .statement
        case 1: return .question
        default: return .comparison
        }
    }

    // MARK: - メイン生成メソッド

    /// エントリデータからインサイトカードを生成する
    /// - Parameters:
    ///   - entries: 全エントリ
    ///   - currentMax: 現在のスコア範囲上限
    /// - Returns: 優先度順のインサイトカード（最大5枚）
    static func generate(from entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [InsightCard] {
        guard entries.count >= minimumTotalEntries else { return [] }

        var candidates: [InsightCard] = []

        // 各インサイトタイプの生成を試行
        candidates.append(contentsOf: weekdayInsights(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: tagNextDayInsights(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: volatilityInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: timeOfDayInsights(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: streakInsight(entries: entries))
        candidates.append(contentsOf: weeklyTrendInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: tagCoOccurrenceInsight(entries: entries))
        candidates.append(contentsOf: tagCountInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: weekendComparisonInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: recordFrequencyInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: weatherMoodInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: energyMoodInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: lateNightRecordingInsight(entries: entries))
        candidates.append(contentsOf: stabilityChangeInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: thresholdBreakInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))
        candidates.append(contentsOf: predictionDeviationInsight(entries: entries, currentMax: currentMax, currentMin: currentMin))

        // Monthly gold card (rare, always shown first if present)
        if let gold = monthlyGoldInsight(from: entries, currentMax: currentMax, currentMin: currentMin) {
            candidates.append(gold)
        }

        // 日付ベースのローテーションを適用して上位N枚を返す
        return applyRotation(candidates: candidates)
    }

    // MARK: - 1. 曜日別インサイト（落ち込み / ピーク）

    private static func weekdayInsights(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
        let calendar = Calendar.current
        let daysSinceEpoch = Int(Date.now.timeIntervalSince1970 / 86400)
        var grouped: [Int: [Double]] = [:]

        for entry in entries {
            let wd = calendar.component(.weekday, from: entry.createdAt)
            grouped[wd, default: []].append(entry.normalizedScore)
        }

        let validDays = grouped.filter { $0.value.count >= minimumWeekdaySamples }
        guard validDays.count >= 5 else { return [] }

        let overallAvg = avg(entries.map(\.normalizedScore))
        let weekdayNames = [""] + calendar.shortWeekdaySymbols
        var results: [InsightCard] = []

        // Lowest weekday - with evolving text based on view count
        if let (lowDay, lowScores) = validDays.min(by: { avg($0.value) < avg($1.value) }) {
            let deviation = overallAvg - avg(lowScores)
            if deviation > 0.08 {
                let scaledDiff = deviation * Double(currentMax - 1)
                let name = weekdayNames[lowDay]
                let cardId = "weekday_low_\(lowDay)"
                let viewCount = insightViewCounts[cardId] ?? 0
                let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

                let body: String
                switch viewCount {
                case 0:
                    // First time: standard statement
                    body = String(localized: "\(name)曜日は気分が下がりやすい傾向があります（平均 \(fmt(scaledDiff))pt 低い）。")
                case 1:
                    body = String(localized: "また\(name)曜日ですね。先週の\(name)曜も低めでした。何か共通点はありますか？")
                case 2:
                    body = String(localized: "\(name)曜日の低下パターンが続いています。\(name)曜に小さなご褒美を入れてみては？")
                default:
                    body = String(localized: "\(name)曜日の傾向は変わらず（平均 \(fmt(scaledDiff))pt 低い）。曜日を意識するだけでも変化のきっかけになります。")
                }

                // Apply style variation for non-first views
                let styledBody: String
                if viewCount == 0 {
                    styledBody = body
                } else {
                    switch style {
                    case .statement:
                        styledBody = body
                    case .question:
                        styledBody = String(localized: "\(name)曜日が低めなのはなぜだと思いますか？（平均 \(fmt(scaledDiff))pt 低い）")
                    case .comparison:
                        styledBody = String(localized: "\(name)曜日 vs 他の曜日：\(fmt(scaledDiff))ptの差があります。")
                    }
                }

                results.append(InsightCard(
                    id: cardId,
                    icon: "calendar.badge.minus",
                    tone: .caution,
                    title: String(localized: "\(name)曜日の傾向"),
                    body: styledBody,
                    priority: min(deviation * 5, 0.9)
                ))
            }
        }

        // Highest weekday - with style variations
        if let (highDay, highScores) = validDays.max(by: { avg($0.value) < avg($1.value) }) {
            let deviation = avg(highScores) - overallAvg
            if deviation > 0.08 {
                let scaledDiff = deviation * Double(currentMax - 1)
                let name = weekdayNames[highDay]
                let cardId = "weekday_high_\(highDay)"
                let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

                let body: String
                switch style {
                case .statement:
                    body = String(localized: "\(name)曜日はスコアが平均 +\(fmt(scaledDiff))。この日に何か良い習慣がありますか？")
                case .question:
                    body = String(localized: "\(name)曜日が好調なのはなぜでしょう？（平均 +\(fmt(scaledDiff))）")
                case .comparison:
                    body = String(localized: "\(name)曜日は他の曜日より+\(fmt(scaledDiff))高いです。")
                }

                results.append(InsightCard(
                    id: cardId,
                    icon: "calendar.badge.plus",
                    tone: .positive,
                    title: String(localized: "\(name)曜日が好調"),
                    body: body,
                    priority: min(deviation * 4, 0.85)
                ))
            }
        }

        return results
    }

    // MARK: - 2. タグ翌日効果インサイト

    private static func tagNextDayInsights(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
        let calendar = Calendar.current
        let daysSinceEpoch = Int(Date.now.timeIntervalSince1970 / 86400)
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        let overallNorm = avg(sorted.map(\.normalizedScore))

        // Group by day
        var dayEntries: [Date: [MoodEntry]] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayEntries[day, default: []].append(entry)
        }

        // Collect next-day scores per tag
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
                let cardId = "tag_nextday_pos_\(tag)"
                let viewCount = insightViewCounts[cardId] ?? 0
                let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

                let body: String
                if viewCount == 0 {
                    body = String(localized: "「\(tag)」の翌日、スコアが平均 +\(fmt(deltaScaled))。あなたの気分に良い影響を与えているようです。")
                } else {
                    switch style {
                    case .statement:
                        body = String(localized: "「\(tag)」の翌日、スコアが平均 +\(fmt(deltaScaled))。")
                    case .question:
                        body = String(localized: "「\(tag)」の後に気分が上がるのはなぜだと思いますか？（平均 +\(fmt(deltaScaled))）")
                    case .comparison:
                        body = String(localized: "「\(tag)」ありの翌日 vs なしの翌日：+\(fmt(deltaScaled))の差があります")
                    }
                }

                results.append(InsightCard(
                    id: cardId,
                    icon: "arrow.up.heart.fill",
                    tone: .positive,
                    title: String(localized: "「\(tag)」の翌日効果"),
                    body: body,
                    priority: min(deltaNorm * 6, 0.95)
                ))
            } else if deltaNorm < -0.06 {
                let cardId = "tag_nextday_neg_\(tag)"
                let viewCount = insightViewCounts[cardId] ?? 0
                let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

                let body: String
                if viewCount == 0 {
                    body = String(localized: "「\(tag)」の翌日はスコアが平均 \(fmt(deltaScaled))。回復のための工夫を試してみては？")
                } else {
                    switch style {
                    case .statement:
                        body = String(localized: "「\(tag)」の翌日はスコアが平均 \(fmt(deltaScaled))。")
                    case .question:
                        body = String(localized: "「\(tag)」の後に気分が下がるのはなぜでしょう？（平均 \(fmt(deltaScaled))）")
                    case .comparison:
                        body = String(localized: "「\(tag)」ありの翌日 vs なしの翌日：\(fmt(deltaScaled))の差があります")
                    }
                }

                results.append(InsightCard(
                    id: cardId,
                    icon: "arrow.down.heart.fill",
                    tone: .caution,
                    title: String(localized: "「\(tag)」の翌日"),
                    body: body,
                    priority: min(abs(deltaNorm) * 5, 0.9)
                ))
            }
        }

        // Top 2 by priority
        return Array(results.sorted { $0.priority > $1.priority }.prefix(2))
    }

    // MARK: - 3. ボラティリティ変化インサイト

    private static func volatilityInsight(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
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
                title: String(localized: "気分が安定化"),
                body: String(localized: "最近の気分の波が穏やかになっています（変動幅 \(fmt(previousStd)) → \(fmt(recentStd))）。良いリズムが掴めているのかもしれません。"),
                priority: min(abs(change) / 3.0, 0.85)
            )]
        } else {
            return [InsightCard(
                id: "volatility_unstable",
                icon: "waveform.path.ecg",
                tone: .caution,
                title: String(localized: "気分の波が大きめ"),
                body: String(localized: "最近の気分の変動が大きくなっています（変動幅 \(fmt(previousStd)) → \(fmt(recentStd))）。生活に変化はありましたか？"),
                priority: min(abs(change) / 3.0, 0.8)
            )]
        }
    }

    // MARK: - 4. 時間帯インサイト

    private static func timeOfDayInsights(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
        let calendar = Calendar.current
        let daysSinceEpoch = Int(Date.now.timeIntervalSince1970 / 86400)
        var grouped: [TimeOfDay: [Double]] = [:]

        for entry in entries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            let tod = TimeOfDay.from(hour: hour)
            grouped[tod, default: []].append(entry.normalizedScore)
        }

        let validGroups = grouped.filter { $0.value.count >= minimumTimeOfDaySamples }
        guard validGroups.count >= 2 else { return [] }

        let overallAvg = avg(entries.map(\.normalizedScore))

        // Lowest time of day - with style variations
        if let (lowTod, lowScores) = validGroups.min(by: { avg($0.value) < avg($1.value) }) {
            let deviation = overallAvg - avg(lowScores)
            if deviation > 0.08 {
                let scaledDiff = deviation * Double(currentMax - 1)
                let cardId = "tod_low_\(lowTod.rawValue)"
                let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

                let body: String
                switch style {
                case .statement:
                    let advice = lowTod == .night
                        ? String(localized: "疲れが出る時間帯かもしれません。")
                        : String(localized: "この時間帯にリフレッシュを取り入れてみては？")
                    body = String(localized: "\(lowTod.timeRange)のスコアが平均より \(fmt(scaledDiff))pt 低め。\(advice)")
                case .question:
                    body = String(localized: "\(lowTod.label)に気分が下がるのはなぜでしょう？（平均 \(fmt(scaledDiff))pt 低い）")
                case .comparison:
                    body = String(localized: "\(lowTod.label) vs 他の時間帯：\(fmt(scaledDiff))ptの差があります。")
                }

                return [InsightCard(
                    id: cardId,
                    icon: lowTod.icon,
                    tone: .caution,
                    title: String(localized: "\(lowTod.label)の傾向"),
                    body: body,
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

        // Show for 3 days after milestone - with evolving text
        let milestones = [7, 14, 21, 30, 50, 100, 200, 365]
        for milestone in milestones {
            if streak >= milestone, streak < milestone + 3 {
                let cardId = "streak_\(milestone)"
                let viewCount = insightViewCounts[cardId] ?? 0

                let body: String
                switch viewCount {
                case 0:
                    body = String(localized: "\(streak)日連続で記録を続けています。小さな習慣の積み重ねが、自己理解を深めています。")
                case 1:
                    body = String(localized: "\(streak)日目！前回の\(milestone)日達成時と比べて、気持ちの変化はありますか？")
                default:
                    body = String(localized: "\(streak)日連続。この習慣はもうあなたの一部ですね。")
                }

                return [InsightCard(
                    id: cardId,
                    icon: "flame.fill",
                    tone: .positive,
                    title: String(localized: "\(milestone)日達成！"),
                    body: body,
                    priority: 0.95
                )]
            }
        }

        return []
    }

    // MARK: - 6. 週間トレンドインサイト

    private static func weeklyTrendInsight(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
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
            let cardId = "weekly_up"
            let viewCount = insightViewCounts[cardId] ?? 0

            let body: String
            switch viewCount {
            case 0:
                var text = String(localized: "今週は先週より平均 +\(fmt(delta))。")
                if twoWeeksAgo.count >= 3 {
                    let twoWeeksAvgNorm = avg(twoWeeksAgo.map(\.normalizedScore))
                    text += lastAvgNorm > twoWeeksAvgNorm
                        ? String(localized: "2週連続で上向いています。良い流れですね！")
                        : String(localized: "先週からの回復が見られます。")
                } else {
                    text += String(localized: "良い調子が続いているようです。")
                }
                body = text
            case 1:
                body = String(localized: "先週に続き好調です（+\(fmt(delta))）。何が効いているか振り返ってみませんか？")
            default:
                body = String(localized: "今週も好調（+\(fmt(delta))）。この良い流れを言葉にしてみると、再現しやすくなります。")
            }

            return [InsightCard(
                id: cardId,
                icon: "chart.line.uptrend.xyaxis",
                tone: .positive,
                title: String(localized: "今週は好調"),
                body: body,
                priority: min(delta / 5.0, 0.85)
            )]
        } else if delta < -1.0 {
            let cardId = "weekly_down"
            let viewCount = insightViewCounts[cardId] ?? 0

            let body: String
            switch viewCount {
            case 0:
                body = String(localized: "今週は先週より平均 \(fmt(delta))。無理せず、自分をいたわる時間を作ってみてください。")
            case 1:
                body = String(localized: "先週から少し低調が続いています（\(fmt(delta))）。小さな楽しみを予定に入れてみては？")
            default:
                body = String(localized: "今週は\(fmt(delta))。調子の波は自然なこと。焦らずいきましょう。")
            }

            return [InsightCard(
                id: cardId,
                icon: "chart.line.downtrend.xyaxis",
                tone: .neutral,
                title: String(localized: "少しお疲れの週"),
                body: body,
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
            for i in 0 ..< sorted.count {
                for j in (i + 1) ..< sorted.count {
                    pairs["\(sorted[i])|\(sorted[j])", default: 0] += 1
                }
            }
        }

        // 共起率が高いペアを探す
        guard let topPair = pairs.max(by: { $0.value < $1.value }),
              topPair.value >= minimumCoOccurrence else { return [] }

        let parts = topPair.key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count >= 2 else { return [] }
        let tag1 = parts[0], tag2 = parts[1]
        let minCount = min(tagCounts[tag1] ?? 0, tagCounts[tag2] ?? 0)
        guard minCount > 0 else { return [] }
        let coRate = Int(Double(topPair.value) / Double(minCount) * 100)

        guard coRate >= 40 else { return [] }

        return [InsightCard(
            id: "cooccur_\(tag1)_\(tag2)",
            icon: "link",
            tone: .discovery,
            title: String(localized: "つながりの発見"),
            body: String(localized: "「\(tag1)」と「\(tag2)」は一緒に記録されることが多い（共起率\(coRate)%）。この2つはあなたの中でつながっているのかもしれません。"),
            priority: min(Double(coRate) / 150.0, 0.75)
        )]
    }

    // MARK: - 8. タグ数vsスコア インサイト

    private static func tagCountInsight(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [InsightCard] {
        guard entries.count >= minimumTagCountEntries else { return [] }

        let overallNormAvg = avg(entries.map(\.normalizedScore))
        let highEntries = entries.filter { $0.normalizedScore >= overallNormAvg }
        let lowEntries = entries.filter { $0.normalizedScore < overallNormAvg }

        guard !highEntries.isEmpty, !lowEntries.isEmpty else { return [] }

        let highTagAvg = Double(highEntries.reduce(0) { $0 + $1.tags.count }) / Double(highEntries.count)
        let lowTagAvg = Double(lowEntries.reduce(0) { $0 + $1.tags.count }) / Double(lowEntries.count)
        let midScaled = overallNormAvg * Double(currentMax - currentMin) + Double(currentMin)

        guard highTagAvg - lowTagAvg > 0.5 else { return [] }

        return [InsightCard(
            id: "tagcount_effect",
            icon: "tag.fill",
            tone: .discovery,
            title: String(localized: "タグ数と気分"),
            body: String(localized: "スコア\(String(format: "%.0f", midScaled))以上の日は平均\(fmt(highTagAvg))個のタグ、それ以下は\(fmt(lowTagAvg))個。気持ちを言語化できている日ほど調子が良いのかもしれません。"),
            priority: min((highTagAvg - lowTagAvg) / 3.0, 0.7)
        )]
    }

    // MARK: - 9. 週末vs平日 インサイト

    private static func weekendComparisonInsight(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
        let calendar = Calendar.current
        let daysSinceEpoch = Int(Date.now.timeIntervalSince1970 / 86400)

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
            let cardId = "weekend_higher"
            let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

            let body: String
            switch style {
            case .statement:
                body = String(localized: "週末のスコアは平日より平均 +\(fmt(deltaScaled))。お休みの日がしっかりエネルギー回復になっているようです。")
            case .question:
                body = String(localized: "週末に気分が上がるのはなぜでしょう？（平日より +\(fmt(deltaScaled))）")
            case .comparison:
                body = String(localized: "週末 vs 平日：+\(fmt(deltaScaled))の差があります。")
            }

            return [InsightCard(
                id: cardId,
                icon: "sun.and.horizon.fill",
                tone: .neutral,
                title: String(localized: "週末がリフレッシュに"),
                body: body,
                priority: min(abs(deltaNorm) * 3, 0.7)
            )]
        } else {
            let cardId = "weekday_higher"
            let style = styleForDay(cardId, daysSinceEpoch: daysSinceEpoch)

            let body: String
            switch style {
            case .statement:
                body = String(localized: "意外にも平日のスコアが週末より +\(fmt(abs(deltaScaled)))。仕事や日常の活動がエネルギーになっているのかも？")
            case .question:
                body = String(localized: "平日の方が好調なのはなぜでしょう？（週末より +\(fmt(abs(deltaScaled)))）")
            case .comparison:
                body = String(localized: "平日 vs 週末：+\(fmt(abs(deltaScaled)))の差があります。")
            }

            return [InsightCard(
                id: cardId,
                icon: "briefcase.fill",
                tone: .discovery,
                title: String(localized: "平日が充実"),
                body: body,
                priority: min(abs(deltaNorm) * 3, 0.7)
            )]
        }
    }

    // MARK: - 10. 記録頻度インサイト

    private static func recordFrequencyInsight(entries: [MoodEntry], currentMax: Int, currentMin _: Int = 1) -> [InsightCard] {
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
            title: String(localized: "記録回数の効果"),
            body: String(localized: "1日に複数回記録した日はスコアが平均 +\(fmt(deltaScaled))。こまめな記録自体が気分に良い影響を与えているのかもしれません。"),
            priority: min((multiAvg - singleAvg) * 3, 0.7)
        )]
    }

    // MARK: - プレミアムインサイト生成

    /// プレミアム限定のインサイトカードを生成する
    /// - Parameters:
    ///   - entries: 全エントリ
    ///   - currentMax: 現在のスコア範囲上限
    /// - Returns: プレミアムインサイトカード（最大3枚）
    static func generatePremium(from entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [InsightCard] {
        guard entries.count >= minimumTotalEntries else { return [] }
        let statsVM = StatsViewModel()
        var candidates: [InsightCard] = []

        // 1. 逆インサイト
        let reverse = statsVM.reverseInsights(entries: entries, currentMax: currentMax, currentMin: currentMin)
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
        let divergences = statsVM.actionScoreDivergence(entries: entries, currentMax: currentMax, currentMin: currentMin)
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
        let triggers = statsVM.recoveryTriggers(entries: entries, currentMax: currentMax, currentMin: currentMin)
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
            let hash = (card.id.hashValue &+ daysSinceEpoch) & 0x7FFF_FFFF
            let noise = Double(hash % 100) / 1000.0 // 0.0〜0.099
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

    // MARK: - 11. 天気×気分インサイト

    private static func weatherMoodInsight(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [InsightCard] {
        var grouped: [String: [Double]] = [:]
        for entry in entries {
            guard let condition = entry.weatherCondition else { continue }
            grouped[condition, default: []].append(entry.normalizedScore)
        }

        // Need 5+ entries per weather type and at least 2 types
        let valid = grouped.filter { $0.value.count >= 5 }
        guard valid.count >= 2 else { return [] }

        let overallAvg = avg(entries.map(\.normalizedScore))

        guard let best = valid.max(by: { avg($0.value) < avg($1.value) }),
              let worst = valid.min(by: { avg($0.value) < avg($1.value) }),
              best.key != worst.key else { return [] }

        let bestDelta = (avg(best.value) - overallAvg) * Double(currentMax - currentMin)
        let worstDelta = (overallAvg - avg(worst.value)) * Double(currentMax - currentMin)

        let weatherLabels: [String: String] = [
            "sunny": String(localized: "晴れ"),
            "cloudy": String(localized: "曇り"),
            "rainy": String(localized: "雨"),
            "snowy": String(localized: "雪"),
            "stormy": String(localized: "嵐"),
            "foggy": String(localized: "霧"),
        ]

        var results: [InsightCard] = []

        if bestDelta > 0.5 {
            let label = weatherLabels[best.key] ?? best.key
            results.append(InsightCard(
                id: "weather_best_\(best.key)",
                icon: "sun.max.fill",
                tone: .positive,
                title: String(localized: "\(label)の日が好調"),
                body: String(localized: "\(label)の日はスコアが平均+\(fmt(bestDelta))高い傾向があります。天気が気分に影響しているようです。"),
                priority: min(bestDelta / 5.0, 0.8)
            ))
        }

        if worstDelta > 0.5 {
            let label = weatherLabels[worst.key] ?? worst.key
            results.append(InsightCard(
                id: "weather_worst_\(worst.key)",
                icon: "cloud.rain.fill",
                tone: .caution,
                title: String(localized: "\(label)の日の傾向"),
                body: String(localized: "\(label)の日はスコアが平均\(fmt(-worstDelta))低い傾向があります。室内で楽しめることを用意しておくのも良いかもしれません。"),
                priority: min(worstDelta / 5.0, 0.75)
            ))
        }

        return results
    }

    // MARK: - 12. エネルギー×気分インサイト

    private static func energyMoodInsight(entries: [MoodEntry], currentMax _: Int, currentMin _: Int = 1) -> [InsightCard] {
        let energyEntries = entries.filter { $0.energyLevel != nil }
        guard energyEntries.count >= 5 else { return [] }

        // Detect divergence: high mood + low energy, or low mood + high energy
        let overallAvg = avg(entries.map(\.normalizedScore))
        var highMoodLowEnergy = 0
        var lowMoodHighEnergy = 0
        var totalChecked = 0

        for entry in energyEntries {
            guard let energy = entry.energyLevel else { continue }
            totalChecked += 1
            let highMood = entry.normalizedScore >= overallAvg + 0.1
            let lowMood = entry.normalizedScore < overallAvg - 0.1

            if highMood, energy == 1 {
                highMoodLowEnergy += 1
            } else if lowMood, energy == 3 {
                lowMoodHighEnergy += 1
            }
        }

        guard totalChecked >= 5 else { return [] }

        var results: [InsightCard] = []

        let hmleRate = Double(highMoodLowEnergy) / Double(totalChecked) * 100
        let lmheRate = Double(lowMoodHighEnergy) / Double(totalChecked) * 100

        if hmleRate >= 15 {
            results.append(InsightCard(
                id: "energy_high_mood_low_energy",
                icon: "battery.25percent",
                tone: .caution,
                title: String(localized: "気分とエネルギーのズレ"),
                body: String(localized: "気分は良いのにエネルギーが低い日が\(Int(hmleRate))%あります。無理していませんか？休息も大切です。"),
                priority: min(hmleRate / 100, 0.8)
            ))
        }

        if lmheRate >= 15 {
            results.append(InsightCard(
                id: "energy_low_mood_high_energy",
                icon: "battery.100percent",
                tone: .discovery,
                title: String(localized: "エネルギーはあるのに"),
                body: String(localized: "エネルギーは十分なのに気分が低い日が\(Int(lmheRate))%あります。心の面でのケアを意識してみては？"),
                priority: min(lmheRate / 100, 0.75)
            ))
        }

        return results
    }

    // MARK: - 13. 深夜記録インサイト

    private static func lateNightRecordingInsight(entries: [MoodEntry]) -> [InsightCard] {
        let calendar = Calendar.current
        let now = Date.now
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now),
              let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now) else { return [] }

        func isLateNight(_ date: Date) -> Bool {
            let hour = calendar.component(.hour, from: date)
            return hour >= 22 || hour < 4
        }

        let recentLate = entries.filter { $0.createdAt >= twoWeeksAgo && isLateNight($0.createdAt) }.count
        let previousLate = entries.filter { $0.createdAt >= fourWeeksAgo && $0.createdAt < twoWeeksAgo && isLateNight($0.createdAt) }.count

        // Only show if recent 2 weeks have more late night recordings than previous 2 weeks
        guard recentLate > previousLate, recentLate >= 3 else { return [] }

        let increase = recentLate - previousLate

        return [InsightCard(
            id: "late_night_increase",
            icon: "moon.fill",
            tone: .caution,
            title: String(localized: "深夜の記録が増加"),
            body: String(localized: "最近2週間で深夜（22時〜4時）の記録が\(recentLate)件あり、以前より\(increase)件増えています。睡眠リズムに変化はありますか？"),
            priority: min(Double(increase) / 5.0, 0.8)
        )]
    }

    // MARK: - 14. 安定度変化インサイト

    private static func stabilityChangeInsight(entries: [MoodEntry], currentMax _: Int, currentMin _: Int = 1) -> [InsightCard] {
        let calendar = Calendar.current
        let now = Date.now
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) else { return [] }

        let thisWeek = entries.filter { $0.createdAt >= thisWeekStart }.map(\.normalizedScore)
        let lastWeek = entries.filter { $0.createdAt >= lastWeekStart && $0.createdAt < thisWeekStart }.map(\.normalizedScore)

        guard thisWeek.count >= 3, lastWeek.count >= 3 else { return [] }

        /// Calculate CV-based stability (0-100 scale)
        func stability(_ scores: [Double]) -> Double {
            let mean = avg(scores)
            guard mean > 0 else { return 100.0 }
            let sd = stdDev(scores)
            let cv = sd / mean
            return max(0, 100 - cv * 100)
        }

        let thisStability = stability(thisWeek)
        let lastStability = stability(lastWeek)
        let change = thisStability - lastStability

        guard abs(change) > 15 else { return [] }

        if change > 0 {
            return [InsightCard(
                id: "stability_improved",
                icon: "waveform.path",
                tone: .positive,
                title: String(localized: "安定度が向上"),
                body: String(localized: "今週は先週より気分が安定しています（安定度\(Int(lastStability))→\(Int(thisStability))）。良いリズムですね。"),
                priority: min(change / 50, 0.8)
            )]
        } else {
            return [InsightCard(
                id: "stability_decreased",
                icon: "waveform.path.ecg",
                tone: .caution,
                title: String(localized: "安定度の変化"),
                body: String(localized: "今週は気分の波が先週より大きくなっています（安定度\(Int(lastStability))→\(Int(thisStability))）。何か心当たりはありますか？"),
                priority: min(abs(change) / 50, 0.75)
            )]
        }
    }

    // MARK: - 15. 閾値ブレークインサイト

    private static func thresholdBreakInsight(entries: [MoodEntry], currentMax _: Int, currentMin _: Int = 1) -> [InsightCard] {
        let calendar = Calendar.current
        let overallAvg = avg(entries.map(\.normalizedScore))

        // Build daily averages sorted by date
        var grouped: [Date: [Double]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            grouped[day, default: []].append(entry.normalizedScore)
        }

        let dailyScores = grouped.map { (date: $0.key, avg: avg($0.value)) }
            .sorted { $0.date > $1.date } // most recent first

        guard dailyScores.count >= 3 else { return [] }

        // Check most recent consecutive streak above or below average
        var aboveStreak = 0
        var belowStreak = 0

        for daily in dailyScores {
            if daily.avg >= overallAvg {
                if belowStreak > 0 { break }
                aboveStreak += 1
            } else {
                if aboveStreak > 0 { break }
                belowStreak += 1
            }
        }

        if aboveStreak >= 3 {
            return [InsightCard(
                id: "threshold_above_\(aboveStreak)",
                icon: "chart.line.uptrend.xyaxis",
                tone: .positive,
                title: String(localized: "\(aboveStreak)日連続で好調"),
                body: String(localized: "\(aboveStreak)日連続で自分の平均を超えています。好調が続いていますね！この調子を維持しましょう。"),
                priority: min(Double(aboveStreak) / 10.0, 0.85)
            )]
        } else if belowStreak >= 3 {
            return [InsightCard(
                id: "threshold_below_\(belowStreak)",
                icon: "chart.line.downtrend.xyaxis",
                tone: .caution,
                title: String(localized: "\(belowStreak)日間の低調期"),
                body: String(localized: "\(belowStreak)日連続で平均を下回っています。自分を責めず、小さなご褒美で気分転換してみては？"),
                priority: min(Double(belowStreak) / 10.0, 0.8)
            )]
        }

        return []
    }

    // MARK: - 16. 予測ズレインサイト

    private static func predictionDeviationInsight(entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> [InsightCard] {
        guard let deviation = PredictionEngine.checkPredictionDeviation(
            entries: entries,
            currentMax: currentMax,
            currentMin: currentMin
        ) else { return [] }

        if deviation.delta > 0 {
            return [InsightCard(
                id: "prediction_above",
                icon: "sparkles",
                tone: .discovery,
                title: String(localized: "予測を上回りました"),
                body: String(localized: "昨日の予測(\(fmt(deviation.predicted)))より実際のスコア(\(fmt(deviation.actual)))が高かったです。予想外の良いことがありましたか？"),
                priority: min(abs(deviation.delta) / 5.0, 0.8)
            )]
        } else {
            return [InsightCard(
                id: "prediction_below",
                icon: "questionmark.circle",
                tone: .discovery,
                title: String(localized: "予測とのズレ"),
                body: String(localized: "昨日の予測(\(fmt(deviation.predicted)))より実際のスコア(\(fmt(deviation.actual)))が低めでした。予想外の出来事がありましたか？"),
                priority: min(abs(deviation.delta) / 5.0, 0.75)
            )]
        }
    }

    // MARK: - 11. HealthKit Insights (Legacy wrapper for correlation-based API)

    /// Legacy: Generate insights from HealthKit correlation data
    static func healthKitInsights(
        stepsCorrelation: Double?,
        sleepCorrelation: Double?,
        heartRateCorrelation: Double?
    ) -> [InsightCard] {
        var results: [InsightCard] = []

        // Steps insight
        if let r = stepsCorrelation, abs(r) >= 0.3 {
            if r > 0 {
                results.append(InsightCard(
                    id: "hk_steps_positive",
                    icon: "figure.walk",
                    tone: .positive,
                    title: String(localized: "歩数と気分"),
                    body: String(localized: "よく歩いた日ほど気分が良い傾向があります。散歩を日課にしてみては？"),
                    priority: min(abs(r), 0.85)
                ))
            } else {
                results.append(InsightCard(
                    id: "hk_steps_negative",
                    icon: "figure.walk",
                    tone: .discovery,
                    title: String(localized: "歩数と気分"),
                    body: String(localized: "歩数が多い日に気分が下がる傾向があります。疲れが溜まっているのかもしれません。"),
                    priority: min(abs(r), 0.8)
                ))
            }
        }

        // Sleep insight
        if let r = sleepCorrelation, abs(r) >= 0.3 {
            if r > 0 {
                results.append(InsightCard(
                    id: "hk_sleep_positive",
                    icon: "bed.double.fill",
                    tone: .positive,
                    title: String(localized: "睡眠と気分"),
                    body: String(localized: "しっかり眠れた日は気分が良い傾向があります。睡眠は心の基盤ですね。"),
                    priority: min(abs(r), 0.9)
                ))
            } else {
                results.append(InsightCard(
                    id: "hk_sleep_negative",
                    icon: "bed.double.fill",
                    tone: .caution,
                    title: String(localized: "睡眠と気分"),
                    body: String(localized: "睡眠時間が長い日に気分が低い傾向があります。睡眠の質を見直してみては？"),
                    priority: min(abs(r), 0.85)
                ))
            }
        }

        // Heart rate insight
        if let r = heartRateCorrelation, abs(r) >= 0.3 {
            results.append(InsightCard(
                id: "hk_hr_\(r > 0 ? "pos" : "neg")",
                icon: "heart.fill",
                tone: r < 0 ? .positive : .caution,
                title: String(localized: "心拍数と気分"),
                body: r < 0
                    ? String(localized: "安静時心拍数が低い（リラックス状態）の日ほど気分が良い傾向があります。")
                    : String(localized: "安静時心拍数が高い日ほど気分が高い傾向があります。活動的な日が好調なのかもしれません。"),
                priority: min(abs(r), 0.8)
            ))
        }

        return results
    }

    // MARK: - 11b. HealthKit Insights with Personal Thresholds

    /// Generate personalized HealthKit insights with specific numbers
    static func healthKitInsights(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [InsightCard] {
        let calendar = Calendar.current
        let minimumMatchedDays = 7

        // Match entries to metrics by date (startOfDay)
        var entryByDay: [Date: [MoodEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            entryByDay[day, default: []].append(entry)
        }

        var metricByDay: [Date: DailyHealthMetric] = [:]
        for metric in metrics {
            let day = calendar.startOfDay(for: metric.date)
            metricByDay[day] = metric
        }

        // Build matched pairs
        struct DayPair {
            let avgNorm: Double
            let steps: Double?
            let sleepHours: Double?
            let restingHR: Double?
        }

        var matched: [DayPair] = []
        for (day, dayEntries) in entryByDay {
            guard let metric = metricByDay[day] else { continue }
            let avgNorm = avg(dayEntries.map(\.normalizedScore))
            matched.append(DayPair(
                avgNorm: avgNorm,
                steps: metric.steps,
                sleepHours: metric.sleepHours,
                restingHR: metric.restingHeartRate
            ))
        }

        guard matched.count >= minimumMatchedDays else { return [] }

        let overallAvg = avg(matched.map(\.avgNorm))
        var results: [InsightCard] = []

        // --- STEPS: Find best threshold ---
        let stepsThresholds: [Double] = [5000, 8000, 10000]
        let stepPairs = matched.filter { $0.steps != nil }
        if stepPairs.count >= minimumMatchedDays {
            var bestThreshold: Double = 0
            var bestDelta: Double = 0

            for threshold in stepsThresholds {
                let above = stepPairs.filter { ($0.steps ?? 0) > threshold }
                let atOrBelow = stepPairs.filter { ($0.steps ?? 0) <= threshold }
                guard above.count >= 3, atOrBelow.count >= 3 else { continue }

                let delta = avg(above.map(\.avgNorm)) - avg(atOrBelow.map(\.avgNorm))
                if abs(delta) > abs(bestDelta) {
                    bestDelta = delta
                    bestThreshold = threshold
                }
            }

            if abs(bestDelta) > 0.05 {
                let scaledDelta = bestDelta * Double(currentMax - currentMin)
                let stepsInt = Int(bestThreshold)
                if bestDelta > 0 {
                    results.append(InsightCard(
                        id: "hk_steps_threshold",
                        icon: "figure.walk",
                        tone: .positive,
                        title: String(localized: "歩数と気分"),
                        body: String(localized: "あなたは\(stepsInt)歩以上歩いた日にスコアが平均+\(fmt(scaledDelta))高いです"),
                        priority: min(abs(bestDelta) * 5, 0.85)
                    ))
                } else {
                    results.append(InsightCard(
                        id: "hk_steps_threshold",
                        icon: "figure.walk",
                        tone: .caution,
                        title: String(localized: "歩数と気分"),
                        body: String(localized: "\(stepsInt)歩以上の日はスコアが平均\(fmt(scaledDelta))です。疲れが溜まっているのかもしれません。"),
                        priority: min(abs(bestDelta) * 5, 0.8)
                    ))
                }
            }
        }

        // --- SLEEP: Find best threshold ---
        let sleepThresholds: [Double] = [6.0, 6.5, 7.0, 7.5]
        let sleepPairs = matched.filter { $0.sleepHours != nil }
        if sleepPairs.count >= minimumMatchedDays {
            var bestThreshold: Double = 0
            var bestDelta: Double = 0

            for threshold in sleepThresholds {
                let above = sleepPairs.filter { ($0.sleepHours ?? 0) >= threshold }
                let below = sleepPairs.filter { ($0.sleepHours ?? 0) < threshold }
                guard above.count >= 3, below.count >= 3 else { continue }

                let delta = avg(above.map(\.avgNorm)) - avg(below.map(\.avgNorm))
                if abs(delta) > abs(bestDelta) {
                    bestDelta = delta
                    bestThreshold = threshold
                }
            }

            if abs(bestDelta) > 0.05 {
                let scaledDelta = bestDelta * Double(currentMax - currentMin)
                if bestDelta > 0 {
                    results.append(InsightCard(
                        id: "hk_sleep_threshold",
                        icon: "bed.double.fill",
                        tone: .positive,
                        title: String(localized: "睡眠と気分"),
                        body: String(localized: "\(fmt(bestThreshold))時間以上眠った日は気分が平均+\(fmt(scaledDelta))高いです"),
                        priority: min(abs(bestDelta) * 5, 0.9)
                    ))
                } else {
                    results.append(InsightCard(
                        id: "hk_sleep_threshold",
                        icon: "bed.double.fill",
                        tone: .caution,
                        title: String(localized: "睡眠と気分"),
                        body: String(localized: "\(fmt(bestThreshold))時間未満の翌日はスコアが平均\(fmt(scaledDelta))です"),
                        priority: min(abs(bestDelta) * 5, 0.85)
                    ))
                }
            }
        }

        // --- HEART RATE: Compare this week vs last week ---
        let hrPairs = matched.filter { $0.restingHR != nil }
        if hrPairs.count >= minimumMatchedDays {
            // Use metrics directly for weekly HR comparison
            let now = Date.now
            guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
                return results
            }
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!

            let thisWeekHR = metrics.filter { $0.date >= thisWeekStart && $0.restingHeartRate != nil }
                .compactMap(\.restingHeartRate)
            let lastWeekHR = metrics.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart && $0.restingHeartRate != nil }
                .compactMap(\.restingHeartRate)

            if thisWeekHR.count >= 2, lastWeekHR.count >= 2 {
                let thisAvgHR = avg(thisWeekHR)
                let lastAvgHR = avg(lastWeekHR)
                let hrDelta = thisAvgHR - lastAvgHR

                if abs(hrDelta) >= 2.0 {
                    let sign = hrDelta > 0 ? "+" : ""
                    results.append(InsightCard(
                        id: "hk_hr_weekly",
                        icon: "heart.fill",
                        tone: hrDelta > 3.0 ? .caution : .neutral,
                        title: String(localized: "心拍数の変化"),
                        body: String(localized: "今週の安静時心拍数が先週より\(sign)\(fmt(hrDelta))bpm高いです"),
                        priority: min(abs(hrDelta) / 10.0, 0.8)
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Monthly Gold Card (rare insight)

    /// Generate a special monthly insight that appears once per month.
    /// Requires 100+ entries for deep analysis.
    static func monthlyGoldInsight(from entries: [MoodEntry], currentMax: Int, currentMin: Int = 1) -> InsightCard? {
        guard entries.count >= 100 else { return nil }

        let calendar = Calendar.current
        let monthKey = "\(calendar.component(.year, from: .now))-\(calendar.component(.month, from: .now))"
        let lastShownMonth = UserDefaults.standard.string(forKey: "goldInsightLastMonth")
        guard lastShownMonth != monthKey else { return nil }

        let monthIndex = calendar.component(.month, from: .now)
        let overallAvg = avg(entries.map(\.normalizedScore))

        let card: InsightCard?

        switch monthIndex % 4 {
        case 0:
            // Top influence factor: find most impactful tag
            card = goldTopInfluenceFactor(entries: entries, currentMax: currentMax, currentMin: currentMin, overallAvg: overallAvg)

        case 1:
            // Mood personality type
            card = goldMoodPersonality(entries: entries, currentMax: currentMax, currentMin: currentMin)

        case 2:
            // Growth over time
            card = goldGrowthOverTime(entries: entries, currentMax: currentMax, currentMin: currentMin)

        case 3:
            // Hidden pattern: surprising tag co-occurrence with high mood
            card = goldHiddenPattern(entries: entries, currentMax: currentMax, currentMin: currentMin, overallAvg: overallAvg)

        default:
            card = nil
        }

        if card != nil {
            UserDefaults.standard.set(monthKey, forKey: "goldInsightLastMonth")
        }
        return card
    }

    // MARK: - Gold Card Sub-methods

    private static func goldTopInfluenceFactor(entries: [MoodEntry], currentMax _: Int, currentMin _: Int, overallAvg: Double) -> InsightCard? {
        // Find the tag with the highest absolute impact on mood
        var tagScores: [String: [Double]] = [:]
        for entry in entries {
            for tag in entry.tags {
                tagScores[tag, default: []].append(entry.normalizedScore)
            }
        }

        var bestTag = ""
        var bestImpact: Double = 0

        for (tag, scores) in tagScores where scores.count >= 5 {
            let tagAvg = avg(scores)
            let impact = abs(tagAvg - overallAvg)
            if impact > bestImpact {
                bestImpact = impact
                bestTag = tag
            }
        }

        guard !bestTag.isEmpty, bestImpact > 0.05 else { return nil }

        return InsightCard(
            id: "gold_top_influence_\(Calendar.current.component(.month, from: .now))",
            icon: "crown.fill",
            tone: .discovery,
            title: String(localized: "✦ \(entries.count)日分のデータ分析"),
            body: String(localized: "\(entries.count)日分のデータ分析：あなたの気分に最も影響するのは「\(bestTag)」です"),
            priority: 1.0
        )
    }

    private static func goldMoodPersonality(entries: [MoodEntry], currentMax _: Int, currentMin _: Int) -> InsightCard? {
        let calendar = Calendar.current

        // Classify personality type
        let weekendEntries = entries.filter {
            let wd = calendar.component(.weekday, from: $0.createdAt)
            return wd == 1 || wd == 7
        }
        let weekdayEntries = entries.filter {
            let wd = calendar.component(.weekday, from: $0.createdAt)
            return wd >= 2 && wd <= 6
        }

        let morningEntries = entries.filter {
            let hour = calendar.component(.hour, from: $0.createdAt)
            return hour >= 5 && hour < 11
        }

        let taggedEntries = entries.filter { !$0.tags.isEmpty }
        let overallStd = stdDev(entries.map(\.normalizedScore))

        let weekendAvg = weekendEntries.isEmpty ? 0 : avg(weekendEntries.map(\.normalizedScore))
        let weekdayAvg = weekdayEntries.isEmpty ? 0 : avg(weekdayEntries.map(\.normalizedScore))
        let morningAvg = morningEntries.isEmpty ? 0 : avg(morningEntries.map(\.normalizedScore))
        let overallAvg = avg(entries.map(\.normalizedScore))

        let personality: String
        let description: String

        if weekendAvg - weekdayAvg > 0.1 {
            personality = String(localized: "週末回復型")
            description = String(localized: "平日の疲れを週末でリセットするタイプ。平日にも小さな楽しみを取り入れると安定感が増します。")
        } else if morningEntries.count > entries.count / 3, morningAvg > overallAvg + 0.05 {
            personality = String(localized: "朝型ポジティブ")
            description = String(localized: "午前中に調子が良い傾向があります。大事な決断や挑戦は午前中がおすすめです。")
        } else if Double(taggedEntries.count) / Double(entries.count) > 0.7 {
            personality = String(localized: "タグ活用型")
            description = String(localized: "感情を言語化する力が高いタイプ。自己理解が深く、気分の管理が上手です。")
        } else if overallStd < 0.15 {
            personality = String(localized: "安定型")
            description = String(localized: "気分の波が小さく安定しています。穏やかな日常を大切にするタイプです。")
        } else {
            return nil
        }

        return InsightCard(
            id: "gold_personality_\(Calendar.current.component(.month, from: .now))",
            icon: "crown.fill",
            tone: .discovery,
            title: String(localized: "✦ あなたの気分パターン"),
            body: String(localized: "あなたの気分パターンは「\(personality)」です。\(description)"),
            priority: 1.0
        )
    }

    private static func goldGrowthOverTime(entries: [MoodEntry], currentMax: Int, currentMin: Int) -> InsightCard? {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard sorted.count >= 60 else { return nil }

        // First 30 entries vs last 30 entries
        let firstMonth = Array(sorted.prefix(30))
        let recentMonth = Array(sorted.suffix(30))

        let firstAvg = avg(firstMonth.map(\.normalizedScore))
        let recentAvg = avg(recentMonth.map(\.normalizedScore))
        let firstStd = stdDev(firstMonth.map(\.normalizedScore))
        let recentStd = stdDev(recentMonth.map(\.normalizedScore))

        let scoreDelta = (recentAvg - firstAvg) * Double(currentMax - currentMin)
        let volChange = firstStd > 0 ? ((firstStd - recentStd) / firstStd * 100) : 0

        guard abs(scoreDelta) > 0.3 || abs(volChange) > 10 else { return nil }

        var bodyParts: [String] = []
        if abs(scoreDelta) > 0.3 {
            let sign = scoreDelta > 0 ? String(localized: "上がり") : String(localized: "下がり")
            bodyParts.append(String(localized: "平均スコアが\(fmt(abs(scoreDelta)))\(sign)"))
        }
        if abs(volChange) > 10 {
            let direction = volChange > 0 ? String(localized: "下がり") : String(localized: "上がり")
            bodyParts.append(String(localized: "ボラティリティが\(fmt(abs(volChange)))%\(direction)ました"))
        }

        let bodyText = String(localized: "最初の1ヶ月と比べて、\(bodyParts.joined(separator: "、"))")

        return InsightCard(
            id: "gold_growth_\(Calendar.current.component(.month, from: .now))",
            icon: "crown.fill",
            tone: .discovery,
            title: String(localized: "✦ あなたの成長"),
            body: bodyText,
            priority: 1.0
        )
    }

    private static func goldHiddenPattern(entries: [MoodEntry], currentMax: Int, currentMin: Int, overallAvg: Double) -> InsightCard? {
        // Find the most surprising two-tag combination with high mood
        let taggedEntries = entries.filter { $0.tags.count >= 2 }
        guard taggedEntries.count >= 10 else { return nil }

        var pairScores: [String: [Double]] = [:]

        for entry in taggedEntries {
            let sortedTags = entry.tags.sorted()
            for i in 0 ..< sortedTags.count {
                for j in (i + 1) ..< sortedTags.count {
                    let key = "\(sortedTags[i])|\(sortedTags[j])"
                    pairScores[key, default: []].append(entry.normalizedScore)
                }
            }
        }

        var bestPair = ""
        var bestDelta: Double = 0

        for (pair, scores) in pairScores where scores.count >= 3 {
            let delta = avg(scores) - overallAvg
            if delta > bestDelta {
                bestDelta = delta
                bestPair = pair
            }
        }

        guard !bestPair.isEmpty, bestDelta > 0.08 else { return nil }

        let parts = bestPair.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        let scaledDelta = bestDelta * Double(currentMax - currentMin)

        return InsightCard(
            id: "gold_hidden_\(Calendar.current.component(.month, from: .now))",
            icon: "crown.fill",
            tone: .discovery,
            title: String(localized: "✦ 意外な発見"),
            body: String(localized: "意外な発見：「\(parts[0])」と「\(parts[1])」が同時に記録された日は、他の日より平均\(fmt(scaledDelta))高いです"),
            priority: 1.0
        )
    }

    // MARK: - 13. Tag × HealthKit Cross Analysis

    /// Cross-analyze tags with HealthKit data for deep insights
    /// e.g. "仕事 × 睡眠6h未満 → 2.1" vs "仕事 × 睡眠7h以上 → 3.8"
    static func tagHealthKitCrossInsights(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [InsightCard] {
        let calendar = Calendar.current
        guard entries.count >= 20 else { return [] }

        // Build metric lookup by date
        var metricByDay: [Date: DailyHealthMetric] = [:]
        for m in metrics {
            metricByDay[calendar.startOfDay(for: m.date)] = m
        }

        // Match entries with metrics
        struct TaggedEntry {
            let normalizedScore: Double
            let tags: [String]
            let sleepHours: Double?
            let steps: Double?
        }

        var matched: [TaggedEntry] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            let metric = metricByDay[day]
            matched.append(TaggedEntry(
                normalizedScore: entry.normalizedScore,
                tags: entry.tags,
                sleepHours: metric?.sleepHours,
                steps: metric?.steps
            ))
        }

        // Find top 5 most-used tags
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(5).map(\.key)

        var results: [InsightCard] = []

        // Tag × Sleep cross analysis
        for tag in topTags {
            let tagEntries = matched.filter { $0.tags.contains(tag) && $0.sleepHours != nil }
            guard tagEntries.count >= 5 else { continue }

            let lowSleep = tagEntries.filter { ($0.sleepHours ?? 0) < 6.5 }
            let highSleep = tagEntries.filter { ($0.sleepHours ?? 0) >= 7.0 }

            guard lowSleep.count >= 3, highSleep.count >= 3 else { continue }

            let lowAvg = avg(lowSleep.map(\.normalizedScore))
            let highAvg = avg(highSleep.map(\.normalizedScore))
            let delta = (highAvg - lowAvg) * Double(currentMax - currentMin)

            if abs(delta) >= 1.0 {
                let lowScaled = lowAvg * Double(currentMax - currentMin) + Double(currentMin)
                let highScaled = highAvg * Double(currentMax - currentMin) + Double(currentMin)

                results.append(InsightCard(
                    id: "tag_sleep_cross_\(tag)",
                    icon: "bed.double.fill",
                    tone: delta > 0 ? .discovery : .caution,
                    title: String(localized: "「\(tag)」× 睡眠"),
                    body: delta > 0
                        ? String(localized: "「\(tag)」の日、睡眠7h以上だとスコア\(fmt(highScaled))ですが、6.5h未満だと\(fmt(lowScaled))に下がります。睡眠が特に影響しています。")
                        : String(localized: "「\(tag)」の日は睡眠時間に関わらずスコアが低め。睡眠以外の要因を探ってみましょう。"),
                    priority: min(abs(delta) / 3.0, 0.95)
                ))
            }
        }

        // Tag × Steps cross analysis
        for tag in topTags {
            let tagEntries = matched.filter { $0.tags.contains(tag) && $0.steps != nil }
            guard tagEntries.count >= 5 else { continue }

            let lowSteps = tagEntries.filter { ($0.steps ?? 0) < 5000 }
            let highSteps = tagEntries.filter { ($0.steps ?? 0) >= 8000 }

            guard lowSteps.count >= 3, highSteps.count >= 3 else { continue }

            let lowAvg = avg(lowSteps.map(\.normalizedScore))
            let highAvg = avg(highSteps.map(\.normalizedScore))
            let delta = (highAvg - lowAvg) * Double(currentMax - currentMin)

            if abs(delta) >= 1.0 {
                let lowScaled = lowAvg * Double(currentMax - currentMin) + Double(currentMin)
                let highScaled = highAvg * Double(currentMax - currentMin) + Double(currentMin)

                results.append(InsightCard(
                    id: "tag_steps_cross_\(tag)",
                    icon: "figure.walk",
                    tone: delta > 0 ? .positive : .discovery,
                    title: String(localized: "「\(tag)」× 歩数"),
                    body: delta > 0
                        ? String(localized: "「\(tag)」の日にたくさん歩くとスコア\(fmt(highScaled))。あまり歩かないと\(fmt(lowScaled))。運動が「\(tag)」のストレスを緩和しているかもしれません。")
                        : String(localized: "「\(tag)」の日は歩数が多くてもスコアに変化なし。歩数以外のケアが効果的かも。"),
                    priority: min(abs(delta) / 3.0, 0.9)
                ))
            }
        }

        // Return top 2 most significant
        return Array(results.sorted { $0.priority > $1.priority }.prefix(2))
    }

    // MARK: - 14. Headphone × Mood Cross Analysis

    /// Analyze headphone listening time correlation with mood
    /// Unique feature: no competing mood tracker does this
    static func headphoneMoodInsights(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [InsightCard] {
        let calendar = Calendar.current
        guard entries.count >= 14 else { return [] }

        var metricByDay: [Date: DailyHealthMetric] = [:]
        for m in metrics {
            metricByDay[calendar.startOfDay(for: m.date)] = m
        }

        struct Pair { let score: Double; let minutes: Double }
        var pairs: [Pair] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            if let m = metricByDay[day], let mins = m.headphoneMinutes {
                pairs.append(Pair(score: entry.normalizedScore, minutes: mins))
            }
        }
        guard pairs.count >= 7 else { return [] }

        var results: [InsightCard] = []
        let range = Double(currentMax - currentMin)

        // High vs low headphone usage comparison
        let highUsage = pairs.filter { $0.minutes > 180 } // 3h+
        let lowUsage = pairs.filter { $0.minutes < 60 } // <1h

        if highUsage.count >= 3, lowUsage.count >= 3 {
            let highAvg = avg(highUsage.map(\.score))
            let lowAvg = avg(lowUsage.map(\.score))
            let delta = (lowAvg - highAvg) * range

            if abs(delta) >= 0.8 {
                let highScaled = highAvg * range + Double(currentMin)
                let lowScaled = lowAvg * range + Double(currentMin)

                if delta > 0 {
                    results.append(InsightCard(
                        id: "headphone_high_impact",
                        icon: "headphones",
                        tone: .discovery,
                        title: String(localized: "イヤホンと気分"),
                        body: String(localized: "イヤホン3時間以上の日はスコア\(fmt(highScaled))。1時間未満の日は\(fmt(lowScaled))。耳を休める時間を意識してみては？"),
                        priority: min(abs(delta) / 3.0, 0.92)
                    ))
                } else {
                    results.append(InsightCard(
                        id: "headphone_positive",
                        icon: "headphones",
                        tone: .positive,
                        title: String(localized: "イヤホンと気分"),
                        body: String(localized: "イヤホンを使う日の方がスコアが高い傾向（\(fmt(highScaled)) vs \(fmt(lowScaled))）。音楽がリラックスに役立っているのかも。"),
                        priority: min(abs(delta) / 3.0, 0.85)
                    ))
                }
            }
        }

        // Tag × Headphone cross analysis
        var tagCounts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(3).map(\.key)

        for tag in topTags {
            let tagPairs = entries
                .filter { $0.tags.contains(tag) }
                .compactMap { entry -> Pair? in
                    let day = calendar.startOfDay(for: entry.createdAt)
                    guard let m = metricByDay[day], let mins = m.headphoneMinutes else { return nil }
                    return Pair(score: entry.normalizedScore, minutes: mins)
                }
            guard tagPairs.count >= 5 else { continue }

            let tagHigh = tagPairs.filter { $0.minutes > 180 }
            let tagLow = tagPairs.filter { $0.minutes < 60 }
            guard tagHigh.count >= 2, tagLow.count >= 2 else { continue }

            let hAvg = avg(tagHigh.map(\.score))
            let lAvg = avg(tagLow.map(\.score))
            let d = (lAvg - hAvg) * range

            if abs(d) >= 1.0 {
                let hScaled = hAvg * range + Double(currentMin)
                let lScaled = lAvg * range + Double(currentMin)
                results.append(InsightCard(
                    id: "tag_headphone_\(tag)",
                    icon: "headphones",
                    tone: d > 0 ? .caution : .discovery,
                    title: String(localized: "「\(tag)」× イヤホン"),
                    body: d > 0
                        ? String(localized: "「\(tag)」の日にイヤホン3時間以上だとスコア\(fmt(hScaled))。1時間未満なら\(fmt(lScaled))。耳を休めると気分が改善するかも。")
                        : String(localized: "「\(tag)」の日はイヤホンで音楽を聴くとスコアが\(fmt(hScaled))→\(fmt(lScaled))に改善。"),
                    priority: min(abs(d) / 3.0, 0.9)
                ))
            }
        }

        return Array(results.sorted { $0.priority > $1.priority }.prefix(2))
    }

    // MARK: - 15. HRV × Mood Analysis

    /// Correlate Heart Rate Variability with mood
    /// HRV is an objective stress biomarker — low HRV = high stress
    static func hrvMoodInsights(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [InsightCard] {
        let calendar = Calendar.current
        guard entries.count >= 14 else { return [] }

        var metricByDay: [Date: DailyHealthMetric] = [:]
        for m in metrics {
            metricByDay[calendar.startOfDay(for: m.date)] = m
        }

        struct Pair { let score: Double; let hrv: Double }
        var pairs: [Pair] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            if let m = metricByDay[day], let hrv = m.hrvSDNN {
                pairs.append(Pair(score: entry.normalizedScore, hrv: hrv))
            }
        }
        guard pairs.count >= 7 else { return [] }

        let range = Double(currentMax - currentMin)
        var results: [InsightCard] = []

        // Split by median HRV
        let medianHRV = pairs.map(\.hrv).sorted()[pairs.count / 2]
        let highHRV = pairs.filter { $0.hrv > medianHRV + 5 }
        let lowHRV = pairs.filter { $0.hrv < medianHRV - 5 }

        if highHRV.count >= 3, lowHRV.count >= 3 {
            let highAvg = avg(highHRV.map(\.score))
            let lowAvg = avg(lowHRV.map(\.score))
            let delta = (highAvg - lowAvg) * range

            if abs(delta) >= 0.8 {
                let highScaled = highAvg * range + Double(currentMin)
                let lowScaled = lowAvg * range + Double(currentMin)
                let medianText = String(format: "%.0f", medianHRV)

                if delta > 0 {
                    results.append(InsightCard(
                        id: "hrv_mood_positive",
                        icon: "waveform.path.ecg",
                        tone: .discovery,
                        title: String(localized: "自律神経と気分"),
                        body: String(localized: "心拍変動（HRV）が高い日（リラックス状態）はスコア\(fmt(highScaled))。低い日（ストレス状態）は\(fmt(lowScaled))。あなたの基準値は約\(medianText)msです。"),
                        priority: min(abs(delta) / 3.0, 0.93)
                    ))
                } else {
                    results.append(InsightCard(
                        id: "hrv_mood_inverted",
                        icon: "waveform.path.ecg",
                        tone: .neutral,
                        title: String(localized: "自律神経と気分"),
                        body: String(localized: "興味深い傾向：HRVが低い（緊張状態の）日でも気分スコアは高め。集中や興奮がポジティブに働いているのかもしれません。"),
                        priority: 0.8
                    ))
                }
            }
        }

        return results
    }

    // MARK: - 16. Exercise & Workout × Mood Analysis

    /// Correlate exercise time and workout types with mood
    static func exerciseMoodInsights(
        entries: [MoodEntry],
        metrics: [DailyHealthMetric],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [InsightCard] {
        let calendar = Calendar.current
        guard entries.count >= 14 else { return [] }

        var metricByDay: [Date: DailyHealthMetric] = [:]
        for m in metrics {
            metricByDay[calendar.startOfDay(for: m.date)] = m
        }

        let range = Double(currentMax - currentMin)
        var results: [InsightCard] = []

        // Exercise minutes analysis
        struct ExPair { let score: Double; let minutes: Double }
        var exPairs: [ExPair] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            if let m = metricByDay[day], let mins = m.exerciseMinutes {
                exPairs.append(ExPair(score: entry.normalizedScore, minutes: mins))
            }
        }

        if exPairs.count >= 7 {
            let active = exPairs.filter { $0.minutes >= 30 }
            let sedentary = exPairs.filter { $0.minutes < 10 }

            if active.count >= 3, sedentary.count >= 3 {
                let activeAvg = avg(active.map(\.score))
                let sedentaryAvg = avg(sedentary.map(\.score))
                let delta = (activeAvg - sedentaryAvg) * range

                if delta >= 0.8 {
                    let activeScaled = activeAvg * range + Double(currentMin)
                    let sedentaryScaled = sedentaryAvg * range + Double(currentMin)
                    results.append(InsightCard(
                        id: "exercise_mood",
                        icon: "figure.run",
                        tone: .positive,
                        title: String(localized: "運動と気分"),
                        body: String(localized: "30分以上運動した日はスコア\(fmt(activeScaled))。10分未満の日は\(fmt(sedentaryScaled))。体を動かすことが気分を支えています。"),
                        priority: min(delta / 3.0, 0.9)
                    ))
                }
            }
        }

        // Workout type analysis — compare different workout types
        var workoutScores: [String: [Double]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            if let m = metricByDay[day], let wType = m.workoutType {
                workoutScores[wType, default: []].append(entry.normalizedScore)
            }
        }

        // Find types with enough data
        let validTypes = workoutScores.filter { $0.value.count >= 3 }
        if validTypes.count >= 2 {
            let bestType = validTypes.max { avg($0.value) < avg($1.value) }
            let worstType = validTypes.min { avg($0.value) < avg($1.value) }

            if let best = bestType, let worst = worstType, best.key != worst.key {
                let bestAvg = avg(best.value) * range + Double(currentMin)
                let worstAvg = avg(worst.value) * range + Double(currentMin)
                let delta = bestAvg - worstAvg

                if delta >= 1.0 {
                    results.append(InsightCard(
                        id: "workout_type_compare",
                        icon: "figure.mixed.cardio",
                        tone: .discovery,
                        title: String(localized: "運動の種類と気分"),
                        body: String(localized: "\(best.key)の日はスコア\(fmt(bestAvg))で最も気分が良く、\(worst.key)の日は\(fmt(worstAvg))。あなたに合った運動が見えてきました。"),
                        priority: min(delta / 3.0, 0.92)
                    ))
                }
            }
        }

        return Array(results.sorted { $0.priority > $1.priority }.prefix(2))
    }

    // MARK: - Nemuri Sleep Insights

    /// Generate insights from Nemuri app sleep data (richer than HealthKit)
    static func nemuriSleepInsights(
        entries: [MoodEntry],
        currentMax: Int,
        currentMin: Int = 1
    ) -> [InsightCard] {
        let sleepRecords = NemuriDataReader.readAllRecords()
        guard sleepRecords.count >= 7 else { return [] }

        let matched = NemuriDataReader.matchSleepToMood(sleepRecords: sleepRecords, moodEntries: entries)
        guard matched.count >= 5 else { return [] }

        var results: [InsightCard] = []
        let overallAvg = avg(matched.map(\.mood.normalizedScore))

        // ① Sleep latency insight (time to fall asleep)
        let slowSleep = matched.filter { $0.sleep.sleepLatencyMinutes > 20 }
        let fastSleep = matched.filter { $0.sleep.sleepLatencyMinutes <= 10 }
        if slowSleep.count >= 3, fastSleep.count >= 3 {
            let slowAvg = avg(slowSleep.map(\.mood.normalizedScore))
            let fastAvg = avg(fastSleep.map(\.mood.normalizedScore))
            let delta = (fastAvg - slowAvg) * Double(currentMax - currentMin)
            if abs(delta) > 0.5 {
                results.append(InsightCard(
                    id: "nemuri_latency",
                    icon: "bed.double.fill",
                    tone: .discovery,
                    title: String(localized: "入眠時間と気分"),
                    body: String(localized: "すぐ眠れた日（10分以内）は翌日の気分が平均+\(fmt(delta))高い傾向です。寝つきの良さが気分に影響しているかもしれません。"),
                    priority: 0.88
                ))
            }
        }

        // ② Awakenings insight (middle-of-night waking)
        let manyWakes = matched.filter { $0.sleep.awakenings >= 3 }
        let fewWakes = matched.filter { $0.sleep.awakenings <= 1 }
        if manyWakes.count >= 3, fewWakes.count >= 3 {
            let manyAvg = avg(manyWakes.map(\.mood.normalizedScore))
            let fewAvg = avg(fewWakes.map(\.mood.normalizedScore))
            let delta = (fewAvg - manyAvg) * Double(currentMax - currentMin)
            if delta > 0.5 {
                results.append(InsightCard(
                    id: "nemuri_awakenings",
                    icon: "moon.zzz.fill",
                    tone: .caution,
                    title: String(localized: "中途覚醒と気分"),
                    body: String(localized: "夜中に3回以上起きた翌日は気分が平均\(fmt(-delta))低い傾向です。睡眠の質が気分に直結しています。"),
                    priority: 0.86
                ))
            }
        }

        // ③ Sleep efficiency insight
        let highEff = matched.filter { $0.sleep.efficiency >= 0.90 }
        let lowEff = matched.filter { $0.sleep.efficiency < 0.80 }
        if highEff.count >= 3, lowEff.count >= 3 {
            let highAvg = avg(highEff.map(\.mood.normalizedScore))
            let lowAvg = avg(lowEff.map(\.mood.normalizedScore))
            let delta = (highAvg - lowAvg) * Double(currentMax - currentMin)
            if delta > 0.5 {
                results.append(InsightCard(
                    id: "nemuri_efficiency",
                    icon: "gauge.with.dots.needle.33percent",
                    tone: .positive,
                    title: String(localized: "睡眠効率と気分"),
                    body: String(localized: "睡眠効率90%以上の翌日は気分が平均+\(fmt(delta))高いです。ベッドにいる時間と実際の睡眠時間の比率が大切です。"),
                    priority: 0.87
                ))
            }
        }

        return results
    }

    // MARK: - Workout × Mood Insights

    /// Generate insights from workout type analysis
    static func workoutMoodInsights(
        results: [StatsViewModel.WorkoutMoodResult],
        currentMax _: Int,
        currentMin _: Int = 1
    ) -> [InsightCard] {
        guard results.count >= 2 else { return [] }
        var cards: [InsightCard] = []

        // Best workout for mood
        if let best = results.first {
            let scoreText = String(format: "%.1f", best.averageScore)
            var body = String(localized: "\(best.workoutType)をした日の気分スコアは平均\(scoreText)。")
            if let nextDay = best.nextDayAverageScore {
                let nextText = String(format: "%.1f", nextDay)
                body += String(localized: "翌日も\(nextText)と好調が続きます。")
            }
            cards.append(InsightCard(
                id: "workout_best_\(best.workoutType)",
                icon: "figure.run",
                tone: .positive,
                title: String(localized: "\(best.workoutType)が気分に効く"),
                body: body,
                priority: 0.87
            ))
        }

        // Worst workout (or least effective)
        if let worst = results.last, results.count >= 3 {
            if let best = results.first, best.averageScore - worst.averageScore > 0.5 {
                let delta = String(format: "%.1f", best.averageScore - worst.averageScore)
                cards.append(InsightCard(
                    id: "workout_compare",
                    icon: "figure.mixed.cardio",
                    tone: .discovery,
                    title: String(localized: "運動の種類で差が出る"),
                    body: String(localized: "\(best.workoutType)は\(worst.workoutType)より気分スコアが\(delta)高い傾向。あなたに合った運動があるようです。"),
                    priority: 0.85
                ))
            }
        }

        return cards
    }

    // MARK: - Headphone × Mood Insights

    static func headphoneDurationInsights(
        results: [StatsViewModel.HeadphoneMoodResult]
    ) -> [InsightCard] {
        guard results.count >= 2 else { return [] }

        // Find the bucket with best and worst scores
        let sorted = results.sorted { $0.averageScore > $1.averageScore }
        guard let best = sorted.first, let worst = sorted.last else { return [] }
        let delta = best.averageScore - worst.averageScore
        guard delta > 0.5 else { return [] }

        let deltaText = String(format: "%.1f", delta)
        return [InsightCard(
            id: "headphone_duration",
            icon: "headphones",
            tone: worst.bucket == "5h+" ? .caution : .discovery,
            title: String(localized: "イヤホンと気分の関係"),
            body: String(localized: "イヤホン\(best.bucket)の日が最も気分が良く、\(worst.bucket)の日は\(deltaText)低い傾向。耳を休める時間が気分に影響しているかもしれません。"),
            priority: 0.83
        )]
    }

    // MARK: - Exercise Threshold Insight

    static func exerciseThresholdInsight(
        result: StatsViewModel.ExerciseThresholdResult?
    ) -> [InsightCard] {
        guard let r = result, r.delta > 0.5 else { return [] }

        let aboveText = String(format: "%.1f", r.aboveAverage)
        let belowText = String(format: "%.1f", r.belowAverage)
        return [InsightCard(
            id: "exercise_threshold_\(r.thresholdMinutes)",
            icon: "figure.run",
            tone: .positive,
            title: String(localized: "\(r.thresholdMinutes)分が運動の分岐点"),
            body: String(localized: "運動\(r.thresholdMinutes)分以上の日は平均\(aboveText)、未満の日は\(belowText)。あなたにとっての「効く運動量」は\(r.thresholdMinutes)分以上のようです。"),
            priority: 0.86
        )]
    }

    // MARK: - HRV × Mood Insight

    static func hrvMoodInsight(
        result: StatsViewModel.HRVMoodResult?
    ) -> [InsightCard] {
        guard let r = result else { return [] }
        var cards: [InsightCard] = []

        // Basic HRV correlation
        let delta = r.highHRVScore - r.lowHRVScore
        if abs(delta) > 0.5 {
            let highText = String(format: "%.1f", r.highHRVScore)
            let lowText = String(format: "%.1f", r.lowHRVScore)
            cards.append(InsightCard(
                id: "hrv_correlation",
                icon: "waveform.path.ecg",
                tone: delta > 0 ? .positive : .caution,
                title: String(localized: "自律神経と気分"),
                body: String(localized: "HRVが高い（リラックス状態）の日はスコア\(highText)、低い日は\(lowText)。自律神経の状態が気分に反映されています。"),
                priority: 0.84
            ))
        }

        // Divergence detection (most valuable insight)
        if r.divergenceDetected {
            cards.append(InsightCard(
                id: "hrv_divergence",
                icon: "exclamationmark.triangle.fill",
                tone: .caution,
                title: String(localized: "無理してるサイン"),
                body: String(localized: "体はストレスを感じている（HRV低い）のに気分は高い日が\(r.divergenceCount)日ありました。無意識に頑張りすぎているかもしれません。"),
                priority: 0.92
            ))
        }

        return cards
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
