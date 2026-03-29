//
//  GreetingService.swift
//  Nami
//
//  Personalized greeting with 4-level fallback:
//  1. Nemuri sleep data  2. Weather  3. Yesterday's mood  4. Generic
//

import Foundation

/// Generates personalized greeting messages based on available data
enum GreetingService {
    /// Generate a greeting with 4-priority fallback
    /// - Parameters:
    ///   - entries: Recent mood entries (newest first)
    ///   - weatherCondition: Current weather condition string (nil if unavailable)
    ///   - weatherTemperature: Current temperature in Celsius (nil if unavailable)
    static func generateGreeting(
        entries: [MoodEntry],
        weatherCondition: String?,
        weatherTemperature _: Double?
    ) -> String {
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

    // MARK: - Priority 1: Sleep Data

    private static func sleepBasedGreeting() -> String? {
        guard let sleep = NemuriDataReader.readLatestSleep() else { return nil }

        let calendar = Calendar.current
        // Only use if wakeTime was today
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

        // Find yesterday's latest entry
        let yesterdayEntry = entries.first { entry in
            let day = calendar.startOfDay(for: entry.createdAt)
            return day >= yesterday && day < todayStart
        }

        guard let entry = yesterdayEntry else { return nil }

        // Check if any notable tags were used (system tag IDs)
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

        // Fall back to score-based message
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
