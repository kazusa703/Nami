//
//  ScreenshotDataGenerator.swift
//  Nami
//
//  Generates beautiful dummy data for App Store screenshots.
//  Only runs when SCREENSHOT_MODE launch argument is set.
//

import Foundation
import SwiftData

#if DEBUG

    /// Generates 100 days of realistic mood data with a positive story arc
    enum ScreenshotDataGenerator {
        /// Check if screenshot mode is active (launch argument)
        static var isEnabled: Bool {
            ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE")
        }

        /// Key to prevent re-generation
        private static let generatedKey = "screenshotDataGenerated"

        /// Generate all screenshot data
        @MainActor
        static func generateIfNeeded(context: ModelContext) {
            guard isEnabled else { return }
            guard !UserDefaults.standard.bool(forKey: generatedKey) else { return }

            // Clear existing data first
            try? context.delete(model: MoodEntry.self)

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)

            // Generate 100 days of entries
            for dayOffset in (0 ..< 100).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

                // Story arc: low start → gradual improvement → stable high
                let progress = Double(100 - dayOffset) / 100.0 // 0.0 → 1.0
                let baseScore = storyScore(progress: progress)

                // Add some natural variance
                let variance = Int.random(in: -1 ... 1)
                let score = max(1, min(10, baseScore + variance))

                // Pick recording time (morning or evening)
                let hour = [7, 8, 9, 20, 21, 22].randomElement()!
                let minute = Int.random(in: 0 ... 59)
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute
                let recordDate = calendar.date(from: components) ?? date

                let entry = MoodEntry(
                    score: score,
                    maxScore: 10,
                    scoreRangeMin: 1,
                    source: dayOffset % 7 == 0 ? "widget" : "app",
                    createdAt: recordDate
                )

                // Assign realistic tags
                entry.tags = generateTags(score: score, progress: progress, dayOffset: dayOffset)

                // Add memo for some entries
                if dayOffset % 5 == 0 || score >= 8 {
                    entry.memo = generateMemo(score: score, progress: progress)
                }

                // Energy level
                if score >= 7 {
                    entry.energyLevel = 3
                } else if score >= 4 {
                    entry.energyLevel = 2
                } else {
                    entry.energyLevel = 1
                }

                // Weather (correlates with mood)
                if score >= 7 {
                    entry.weatherCondition = ["sunny", "clear"].randomElement()
                    entry.weatherTemperature = Double.random(in: 18 ... 26)
                } else if score >= 5 {
                    entry.weatherCondition = ["cloudy", "sunny"].randomElement()
                    entry.weatherTemperature = Double.random(in: 14 ... 22)
                } else {
                    entry.weatherCondition = ["rainy", "cloudy"].randomElement()
                    entry.weatherTemperature = Double.random(in: 8 ... 16)
                }

                context.insert(entry)
            }

            // Add a few extra entries on recent days for richer graphs
            for dayOffset in 0 ..< 7 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = 12
                components.minute = 30
                let lunchDate = calendar.date(from: components) ?? date

                let score = Int.random(in: 7 ... 9)
                let entry = MoodEntry(score: score, maxScore: 10, scoreRangeMin: 1, createdAt: lunchDate)
                entry.tags = ["tag_work", "tag_focused", "tag_caffeine"]
                context.insert(entry)
            }

            try? context.save()
            UserDefaults.standard.set(true, forKey: generatedKey)
        }

        // MARK: - Story Arc

        /// Score progression: low → recovery → stable high
        private static func storyScore(progress: Double) -> Int {
            switch progress {
            case 0.0 ..< 0.15: return Int.random(in: 3 ... 5) // Low period
            case 0.15 ..< 0.30: return Int.random(in: 4 ... 6) // Starting to recover
            case 0.30 ..< 0.50: return Int.random(in: 5 ... 7) // Building momentum
            case 0.50 ..< 0.70: return Int.random(in: 6 ... 8) // Getting better
            case 0.70 ..< 0.85: return Int.random(in: 7 ... 9) // Strong
            default: return Int.random(in: 7 ... 9) // Stable high
            }
        }

        // MARK: - Tag Generation

        private static func generateTags(score: Int, progress: Double, dayOffset: Int) -> [String] {
            var tags: [String] = []

            // Emotion tag based on score
            if score >= 8 { tags.append(["tag_happy", "tag_grateful", "tag_energetic"].randomElement()!) }
            else if score >= 6 { tags.append(["tag_calm", "tag_refreshed"].randomElement()!) }
            else if score >= 4 { tags.append(["tag_anxious", "tag_stressed"].randomElement()!) }
            else { tags.append(["tag_sad", "tag_body_tired", "tag_mind_tired"].randomElement()!) }

            // Activity/lifestyle tags (more positive activities as progress increases)
            if progress > 0.4, dayOffset % 2 == 0 {
                tags.append("tag_yoga_stretch")
            }
            if progress > 0.3, dayOffset % 3 == 0 {
                tags.append("tag_running")
            }

            // Morning tag
            if score >= 7 {
                tags.append("tag_fresh_wakeup")
            } else if score <= 4 {
                tags.append("tag_not_enough_sleep")
            }

            // Diet
            if dayOffset % 2 == 0 { tags.append("tag_caffeine") }
            if progress > 0.5, dayOffset % 3 == 0 { tags.append("tag_home_cooking") }

            // Location
            if dayOffset % 7 < 5 { tags.append("tag_workplace") }
            else { tags.append("tag_home") }

            // Social
            if dayOffset % 4 == 0 { tags.append("tag_friends") }
            if dayOffset % 7 == 6 { tags.append("tag_family") }

            return Array(tags.prefix(5))
        }

        // MARK: - Memo Generation

        private static func generateMemo(score: Int, progress _: Double) -> String {
            if score >= 8 {
                return [
                    "今日はヨガの後にとてもリフレッシュした気分",
                    "友人との食事で楽しい時間を過ごせた",
                    "プロジェクトが順調。達成感がある",
                    "朝から気分が良い。散歩が効いている",
                    "新しいことに挑戦してワクワクした",
                ].randomElement()!
            } else if score >= 6 {
                return [
                    "まあまあの一日。穏やかに過ごせた",
                    "仕事は忙しかったけど充実感はある",
                    "少し疲れたけど悪くない",
                ].randomElement()!
            } else {
                return [
                    "ちょっと疲れ気味。早めに休もう",
                    "雨の日は気分が上がらない",
                    "仕事のプレッシャーが大きい",
                ].randomElement()!
            }
        }

        /// Reset screenshot data (call when done)
        static func cleanup() {
            UserDefaults.standard.removeObject(forKey: generatedKey)
        }
    }

#endif
