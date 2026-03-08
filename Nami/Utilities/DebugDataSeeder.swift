//
//  DebugDataSeeder.swift
//  Nami
//
//  デバッグビルド時のみ使用するテストデータ生成
//  App Storeスクリーンショット向けの自然なデータを生成
//

#if DEBUG
    import Foundation
    import SwiftData

    enum DebugDataSeeder {
        private static let seededKey = "debug_data_seeded_v3"

        /// Generate realistic mood data for screenshots
        static func seedIfNeeded(context: ModelContext) {
            guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

            let cal = Calendar.current
            let now = Date()

            // Realistic score patterns: gradual waves with natural variation
            // Base pattern cycles over ~30 days
            for daysAgo in 0 ..< 180 {
                guard let baseDate = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }

                // Skip ~5% of days for realism
                if Int.random(in: 0 ..< 100) < 5 { continue }

                // Generate natural wave pattern (higher scores on weekends, gradual trends)
                let weekday = cal.component(.weekday, from: baseDate)
                let isWeekend = weekday == 1 || weekday == 7

                // Base score follows a slow wave: sin curve over ~40 days
                let wave = sin(Double(daysAgo) * .pi / 20.0)
                let baseScore = 6.0 + wave * 1.5 + (isWeekend ? 0.8 : 0.0)

                // 1-3 entries per day
                let entryCount = isWeekend ? Int.random(in: 1 ... 2) : Int.random(in: 1 ... 3)

                for i in 0 ..< entryCount {
                    let hour: Int
                    switch i {
                    case 0: hour = Int.random(in: 7 ... 10) // morning
                    case 1: hour = Int.random(in: 12 ... 15) // afternoon
                    default: hour = Int.random(in: 18 ... 22) // evening
                    }
                    guard let entryDate = cal.date(bySettingHour: hour, minute: Int.random(in: 0 ... 59), second: 0, of: baseDate) else { continue }

                    // Add natural variance
                    let variance = Double.random(in: -1.5 ... 1.5)
                    let score = max(1, min(10, Int(baseScore + variance + 0.5)))

                    // Memos: ~30% of entries
                    let memos = [
                        "朝から気分がいい", "カフェでゆっくり", "仕事に集中できた", "友達とランチ",
                        "よく眠れた", "散歩が気持ちよかった", "映画を観た", "料理を楽しんだ",
                        "読書の時間", "少し疲れた", "天気がよかった", "新しいことに挑戦",
                        "音楽を聴いてリラックス", "運動した", "家族と過ごした",
                    ]
                    let memo: String? = Int.random(in: 0 ..< 100) < 30 ? memos.randomElement() : nil

                    // Tags: ~40% of entries, weighted toward positive
                    let tags: [String]
                    if Int.random(in: 0 ..< 100) < 40 {
                        if score >= 7 {
                            tags = [["嬉しい", "穏やか", "感謝", "楽しい", "充実"].randomElement()!]
                        } else if score >= 4 {
                            tags = [["穏やか", "集中", "リラックス", "まあまあ"].randomElement()!]
                        } else {
                            tags = [["疲労", "不安", "ストレス"].randomElement()!]
                        }
                    } else {
                        tags = []
                    }

                    let entry = MoodEntry(
                        score: score,
                        maxScore: 10,
                        memo: memo,
                        tags: tags,
                        createdAt: entryDate
                    )
                    context.insert(entry)
                }
            }

            // Add a nice entry for today (will appear as latest record)
            let todayEvening = cal.date(bySettingHour: 19, minute: 30, second: 0, of: now)!
            let todayEntry = MoodEntry(
                score: 8,
                maxScore: 10,
                memo: "今日も充実した一日",
                tags: ["感謝", "穏やか"],
                createdAt: todayEvening
            )
            context.insert(todayEntry)

            UserDefaults.standard.set(true, forKey: seededKey)
            print("[DebugDataSeeder] Screenshot data seeded (180 days)")
        }

        static func resetFlag() {
            UserDefaults.standard.removeObject(forKey: seededKey)
            print("[DebugDataSeeder] Seed flag reset. Data will regenerate on next launch.")
        }

        // MARK: - Range boundary test data

        /// Add entries at specific day offsets for verifying Range Picker boundary logic
        static func seedBoundaryData(context: ModelContext) {
            let cal = Calendar.current
            let now = Date()

            // Boundary offsets: (daysAgo, score, tags, memo)
            let boundaries: [(Int, Int, [String], String)] = [
                (0, 3, ["疲労"], "境界テスト: 今日朝"), // today AM
                (0, 8, ["嬉しい"], "境界テスト: 今日夜"), // today PM
                (6, 5, ["穏やか"], "境界テスト: 6日前"), // 1W included
                (7, 6, ["集中"], "境界テスト: 7日前"), // 1W excluded
                (30, 7, ["感謝"], "境界テスト: 30日前"), // 1M included
                (31, 4, ["ストレス"], "境界テスト: 31日前"), // 1M excluded
                (90, 6, ["リラックス"], "境界テスト: 90日前"), // 3M boundary
                (180, 5, ["まあまあ"], "境界テスト: 180日前"), // 6M boundary
                (365, 8, ["充実"], "境界テスト: 365日前"), // 1Y boundary
                (366, 3, ["不安"], "境界テスト: 366日前"), // 1Y excluded
            ]

            for (daysAgo, score, tags, memo) in boundaries {
                guard let baseDate = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: now)) else { continue }
                let hour = daysAgo == 0 && score == 3 ? 8 : 20
                guard let entryDate = cal.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) else { continue }

                let entry = MoodEntry(
                    score: score,
                    maxScore: 10,
                    memo: memo,
                    tags: tags,
                    createdAt: entryDate
                )
                context.insert(entry)
            }
            print("[DebugDataSeeder] Boundary test data seeded (10 entries)")
        }

        // MARK: - Mass tag scalability test data

        /// Generate entries with many unique tags for scalability testing
        static func seedMassTagData(context: ModelContext, uniqueTagCount: Int = 200) {
            let cal = Calendar.current
            let now = Date()

            // Create pool of unique tags
            let categories = ["運動", "食事", "仕事", "趣味", "勉強", "交流", "休息", "移動", "家事", "創作"]
            var tagPool: [String] = []
            for cat in categories {
                for i in 1 ... (uniqueTagCount / categories.count) {
                    tagPool.append("\(cat)\(i)")
                }
            }
            // Pad to exact count
            while tagPool.count < uniqueTagCount {
                tagPool.append("タグ\(tagPool.count + 1)")
            }

            // Generate 60 entries over last 30 days, each with 3-8 tags from the pool
            for i in 0 ..< 60 {
                let daysAgo = i / 2
                guard let baseDate = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
                let hour = (i % 2 == 0) ? 9 : 20
                guard let entryDate = cal.date(bySettingHour: hour, minute: Int.random(in: 0 ... 59), second: 0, of: baseDate) else { continue }

                let tagCount = Int.random(in: 3 ... 8)
                let entryTags = Array(tagPool.shuffled().prefix(tagCount))
                let score = Int.random(in: 1 ... 10)

                let entry = MoodEntry(
                    score: score,
                    maxScore: 10,
                    memo: "大量タグテスト(\(tagCount)個)",
                    tags: entryTags,
                    createdAt: entryDate
                )
                context.insert(entry)
            }
            print("[DebugDataSeeder] Mass tag data seeded (\(uniqueTagCount) unique tags, 60 entries)")
        }

        static func previewContainer() -> ModelContainer {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: MoodEntry.self, EmotionTag.self, TagCategory.self, configurations: config)
            let context = container.mainContext
            let cal = Calendar.current
            let now = Date()

            for daysAgo in 0 ..< 180 {
                guard let baseDate = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
                let entryCount = daysAgo % 5 == 2 ? 0 : Int.random(in: 1 ... 3)

                for j in 0 ..< entryCount {
                    let hour = 8 + j * 4
                    guard let date = cal.date(bySettingHour: min(hour, 23), minute: Int.random(in: 0 ... 59), second: 0, of: baseDate) else { continue }
                    let wave = sin(Double(daysAgo) * .pi / 20.0)
                    let score = max(1, min(10, Int(6.0 + wave * 1.5 + Double.random(in: -1.0 ... 1.0) + 0.5)))
                    let entry = MoodEntry(score: score, maxScore: 10, createdAt: date)
                    context.insert(entry)
                }
            }

            return container
        }
    }
#endif
