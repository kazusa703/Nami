//
//  GreetingService.swift
//  Nami
//
//  Personalized greeting with 5-level fallback:
//  0. Predictive insight  1. Nemuri sleep  2. Weather  3. Yesterday's mood  4. Generic
//

import Foundation

/// Generates personalized greeting messages based on available data
enum GreetingService {
    /// Generate a greeting with 5-priority fallback
    static func generateGreeting(
        entries: [MoodEntry],
        weatherCondition: String?,
        weatherTemperature _: Double?
    ) -> String {
        // Priority 0: Predictive insight from accumulated data
        if let insight = predictiveInsight(entries: entries) {
            return insight
        }

        // Priority 1: Nemuri sleep data
        if let sleepGreeting = sleepBasedGreeting() {
            return sleepGreeting
        }

        // Priority 2: Weather data
        if let condition = weatherCondition, let greeting = weatherBasedGreeting(condition: condition) {
            return greeting
        }

        // Priority 3: Yesterday's mood data
        if let moodGreeting = yesterdayMoodGreeting(entries: entries) {
            return moodGreeting
        }

        // Priority 4: Time-based generic greeting
        return timeBasedGreeting()
    }

    // MARK: - Priority 0: Predictive Insight

    private static func predictiveInsight(entries: [MoodEntry]) -> String? {
        let calendar = Calendar.current
        let now = Date.now

        // Need at least 7 entries for meaningful analysis
        guard entries.count >= 7 else {
            return fallbackInsight(entryCount: entries.count)
        }

        // Use last 30 days of data
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let recentEntries = entries.filter { $0.createdAt >= thirtyDaysAgo }
        guard recentEntries.count >= 5 else {
            return fallbackInsight(entryCount: entries.count)
        }

        // Randomly pick one insight pattern per session (seeded by day)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let patternIndex = dayOfYear % 3

        switch patternIndex {
        case 0:
            return weekdayTrendInsight(entries: recentEntries, calendar: calendar)
        case 1:
            return tagCorrelationInsight(entries: recentEntries, calendar: calendar)
        default:
            return weekdayTrendInsight(entries: recentEntries, calendar: calendar)
                ?? tagCorrelationInsight(entries: recentEntries, calendar: calendar)
        }
    }

    /// Pattern A: Weekday trend
    private static func weekdayTrendInsight(entries: [MoodEntry], calendar: Calendar) -> String? {
        // Group scores by weekday
        var weekdayScores: [Int: [Double]] = [:]
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.createdAt)
            weekdayScores[weekday, default: []].append(entry.normalizedScore)
        }

        // Need data for at least 3 weekdays
        guard weekdayScores.count >= 3 else { return nil }

        let weekdayAverages = weekdayScores.mapValues { scores in
            scores.reduce(0, +) / Double(scores.count)
        }

        let overallAvg = entries.map(\.normalizedScore).reduce(0, +) / Double(entries.count)

        // Today's weekday
        let todayWeekday = calendar.component(.weekday, from: .now)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        let weekdayName = formatter.weekdaySymbols[todayWeekday - 1]

        if let todayAvg = weekdayAverages[todayWeekday] {
            if todayAvg < overallAvg - 0.1 {
                return String(localized: "\(weekdayName)は少し気分が下がりやすい傾向があります。今日は無理せず過ごしましょう。")
            } else if todayAvg > overallAvg + 0.1 {
                return String(localized: "\(weekdayName)は気分が高い傾向があります。今日も良い日になりそうですね。")
            }
        }

        // Find worst/best weekday as fallback
        if let worst = weekdayAverages.min(by: { $0.value < $1.value }),
           worst.value < overallAvg - 0.08
        {
            let name = formatter.weekdaySymbols[worst.key - 1]
            return String(localized: "過去のデータでは、\(name)に気分が下がりやすい傾向があります。パターンを知ることが第一歩です。")
        }

        return nil
    }

    /// Pattern B: Tag correlation (positive)
    private static func tagCorrelationInsight(entries: [MoodEntry], calendar: Calendar) -> String? {
        // Collect tags and their associated scores
        var tagScores: [String: [Double]] = [:]
        var tagNextDayScores: [String: [Double]] = [:]

        let sortedEntries = entries.sorted { $0.createdAt < $1.createdAt }

        for (i, entry) in sortedEntries.enumerated() {
            for tag in entry.tags {
                tagScores[tag, default: []].append(entry.normalizedScore)

                // Check next day's score
                if i + 1 < sortedEntries.count {
                    let nextEntry = sortedEntries[i + 1]
                    let dayDiff = calendar.dateComponents([.day], from: entry.createdAt, to: nextEntry.createdAt).day ?? 0
                    if dayDiff == 1 {
                        tagNextDayScores[tag, default: []].append(nextEntry.normalizedScore)
                    }
                }
            }
        }

        let overallAvg = entries.map(\.normalizedScore).reduce(0, +) / Double(entries.count)

        // Find tag with best next-day effect (at least 3 occurrences)
        let bestNextDay = tagNextDayScores
            .filter { $0.value.count >= 3 }
            .mapValues { scores in scores.reduce(0, +) / Double(scores.count) }
            .max { $0.value < $1.value }

        if let best = bestNextDay, best.value > overallAvg + 0.05 {
            let displayName = TagDisplayHelper.displayName(for: best.key)
            return String(localized: "「\(displayName)」の翌日は気分スコアが高い傾向があります。今日も取り入れてみては？")
        }

        // Find tag that correlates with high same-day scores
        let bestSameDay = tagScores
            .filter { $0.value.count >= 3 }
            .mapValues { scores in scores.reduce(0, +) / Double(scores.count) }
            .max { $0.value < $1.value }

        if let best = bestSameDay, best.value > overallAvg + 0.08 {
            let displayName = TagDisplayHelper.displayName(for: best.key)
            return String(localized: "「\(displayName)」がある日は気分が良い傾向です。あなたの元気の源かもしれません。")
        }

        return nil
    }

    /// Pattern D: Fallback for insufficient data
    private static func fallbackInsight(entryCount: Int) -> String? {
        if entryCount == 0 {
            return nil // Let other priorities handle it
        } else if entryCount < 3 {
            return String(localized: "記録を続けると、あなただけの気分パターンが見えてきます。今日の気分は？")
        } else if entryCount < 7 {
            return String(localized: "あと少しで傾向分析ができるようになります。今日も記録してみましょう。")
        }
        return nil
    }

    // MARK: - Priority 1: Sleep Data

    private static func sleepBasedGreeting() -> String? {
        guard let sleep = NemuriDataReader.readLatestSleep() else { return nil }

        let calendar = Calendar.current
        guard calendar.isDateInToday(sleep.wakeTime) || calendar.isDateInYesterday(sleep.wakeTime) else {
            return nil
        }

        let hours = sleep.durationHours
        let score = sleep.qualityScore

        if score >= 80 {
            return String(localized: "昨夜はぐっすり眠れたようですね。今日の気分は？")
        } else if score < 50 {
            return String(localized: "昨夜は少し睡眠が浅かったようです。今日の調子はいかがですか？")
        } else if hours < 6 {
            return String(localized: "睡眠時間が短めでした。今の気分を記録してみましょう。")
        } else {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            return String(localized: "昨夜は\(h)時間\(m)分の睡眠でした。今の気分は？")
        }
    }

    // MARK: - Priority 2: Weather

    private static func weatherBasedGreeting(condition: String) -> String? {
        switch condition {
        case "sunny", "clear":
            return [
                String(localized: "今日は気持ちよく晴れていますね。今の気分は？"),
                String(localized: "いい天気ですね！今の気分を記録しましょう。"),
            ].randomElement()
        case "cloudy":
            return String(localized: "曇り空ですが、心は穏やかですか？")
        case "rainy":
            return [
                String(localized: "雨の日ですが、今の気持ちはどうですか？"),
                String(localized: "雨音を聞きながら、今の気分を記録してみましょう。"),
            ].randomElement()
        case "snowy":
            return String(localized: "雪の日ですね。暖かくしていますか？今の気分は？")
        case "stormy", "thunderstorm":
            return String(localized: "荒れた天気ですが、心の状態はいかがですか？")
        case "windy":
            return String(localized: "風の強い日ですね。今の気分を記録しましょう。")
        default:
            return nil
        }
    }

    // MARK: - Priority 3: Yesterday's Mood

    private static func yesterdayMoodGreeting(entries: [MoodEntry]) -> String? {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        let todayStart = calendar.startOfDay(for: .now)

        let yesterdayEntry = entries.first { entry in
            let day = calendar.startOfDay(for: entry.createdAt)
            return day >= yesterday && day < todayStart
        }

        guard let entry = yesterdayEntry else { return nil }

        let notableTags = ["tag_body_tired", "tag_mind_tired", "tag_stressed", "tag_anxious", "tag_irritated", "tag_feeling_sick"]
        if let matchedTag = entry.tags.first(where: { notableTags.contains($0) }) {
            let displayTag = TagDisplayHelper.displayName(for: matchedTag)
            return String(localized: "昨日は「\(displayTag)」が記録されていました。今朝の調子はどうですか？")
        }

        let positiveTags = ["tag_happy", "tag_fun", "tag_calm", "tag_grateful", "tag_energetic", "tag_refreshed"]
        if let matchedTag = entry.tags.first(where: { positiveTags.contains($0) }) {
            let displayTag = TagDisplayHelper.displayName(for: matchedTag)
            return String(localized: "昨日は「\(displayTag)」な一日でしたね。今日の気分は？")
        }

        let norm = entry.normalizedScore
        if norm >= 0.7 {
            return String(localized: "昨日は好調でしたね。今日の気分も記録しましょう。")
        } else if norm <= 0.3 {
            return String(localized: "昨日は少し大変だったかもしれません。今日はどうですか？")
        }

        return nil
    }

    // MARK: - Priority 4: Generic

    private static func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5 ..< 10:
            return String(localized: "おはようございます。今の気分を記録してみましょう。")
        case 10 ..< 12:
            return String(localized: "お疲れ様です。今の気持ちを記録してみませんか？")
        case 12 ..< 14:
            return String(localized: "お昼ですね。午前中の気分はいかがでしたか？")
        case 14 ..< 18:
            return String(localized: "午後の調子はどうですか？気分を記録しましょう。")
        case 18 ..< 22:
            return String(localized: "お疲れ様です。今日一日の気分はいかがでしたか？")
        default:
            return String(localized: "今の気持ちを記録してみませんか？")
        }
    }
}
