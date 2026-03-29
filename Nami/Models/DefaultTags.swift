//
//  DefaultTags.swift
//  Nami
//
//  デフォルトタグの初期データ
//

import Foundation
import SwiftData

/// デフォルトタグの初期化を管理する
enum DefaultTags {
    /// UserDefaultsのキー（シード済みフラグ）
    private static let seededKey = "defaultTagsSeeded"

    /// デフォルトタグがまだシードされていなければ作成する（1回だけ実行）
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        // CloudKit経由でタグが既に同期されている場合はスキップ
        let descriptor = FetchDescriptor<EmotionTag>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount > 0 {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        let defaults: [(String, EmotionTagCategory, String)] = [
            // Positive
            ("tag_happy", .positive, "face.smiling.inverse"),
            ("tag_fun", .positive, "party.popper.fill"),
            ("tag_calm", .positive, "leaf.fill"),
            ("tag_grateful", .positive, "heart.fill"),
            ("tag_energetic", .positive, "bolt.fill"),
            ("tag_refreshed", .positive, "sparkles"),
            // Negative
            ("tag_anxious", .negative, "exclamationmark.triangle.fill"),
            ("tag_body_tired", .negative, "battery.25percent"),
            ("tag_mind_tired", .negative, "brain"),
            ("tag_irritated", .negative, "flame.fill"),
            ("tag_sad", .negative, "cloud.rain.fill"),
            ("tag_stressed", .negative, "tornado"),
            // Morning
            ("tag_fresh_wakeup", .morning, "sunrise.fill"),
            ("tag_overslept", .morning, "bed.double.fill"),
            ("tag_nightmare", .morning, "moon.haze.fill"),
            ("tag_not_enough_sleep", .morning, "zzz"),
            // Mind
            ("tag_focused", .mind, "scope"),
            ("tag_overwhelmed", .mind, "exclamationmark.brain"),
            ("tag_spaced_out", .mind, "cloud.fog.fill"),
            ("tag_inspired", .mind, "lightbulb.fill"),
            ("tag_multitasking", .mind, "square.stack.3d.up.fill"),
            // Factor
            ("tag_work", .factor, "briefcase.fill"),
            ("tag_lack_of_sleep", .factor, "moon.zzz.fill"),
            ("tag_relationships", .factor, "person.2.fill"),
            ("tag_relaxing", .factor, "cup.and.saucer.fill"),
            ("tag_feeling_sick", .factor, "cross.case.fill"),
            ("tag_pms", .factor, "drop.fill"),
            ("tag_weather", .factor, "cloud.sun.fill"),
            // Diet
            ("tag_caffeine", .diet, "cup.and.heat.waves.fill"),
            ("tag_alcohol", .diet, "wineglass.fill"),
            ("tag_sweets", .diet, "birthday.cake.fill"),
            ("tag_overeating", .diet, "fork.knife.circle.fill"),
            ("tag_home_cooking", .diet, "frying.pan.fill"),
            ("tag_hydrated", .diet, "drop.circle.fill"),
            // Exercise
            ("tag_running", .exercise, "figure.run"),
            ("tag_walking", .exercise, "figure.walk"),
            ("tag_weight_training", .exercise, "dumbbell.fill"),
            ("tag_yoga_stretch", .exercise, "figure.mind.and.body"),
        ]

        for (index, (name, category, icon)) in defaults.enumerated() {
            let tag = EmotionTag(
                name: name,
                category: category,
                icon: icon,
                isDefault: true,
                sortOrder: index
            )
            context.insert(tag)
        }

        UserDefaults.standard.set(true, forKey: seededKey)
    }

    // MARK: - V2 Migration (location, activity, social categories)

    /// UserDefaults key for v2 seeded flag
    private static let seededV2Key = "defaultTagsSeededV2"

    /// Seed new category tags if v1 was seeded but v2 was not
    @MainActor
    static func seedV2IfNeeded(context: ModelContext) {
        // Only run if v1 was already seeded and v2 has not been
        guard UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard !UserDefaults.standard.bool(forKey: seededV2Key) else { return }

        // Check if v2 tags already exist (e.g. via CloudKit sync)
        let descriptor = FetchDescriptor<EmotionTag>()
        let allTags = (try? context.fetch(descriptor)) ?? []
        let v2Names = Set(["tag_home", "tag_workplace", "tag_outside", "tag_commuting",
                           "tag_reading", "tag_cooking", "tag_walking_activity", "tag_shopping",
                           "tag_smartphone_sns", "tag_hobby_fandom",
                           "tag_alone", "tag_family", "tag_friends", "tag_colleagues", "tag_partner",
                           "tag_praised", "tag_deep_talk", "tag_argument", "tag_social_fatigue", "tag_listener"])
        let existingNames = Set(allTags.map(\.name))
        if !v2Names.isDisjoint(with: existingNames) {
            // Some v2 tags already exist
            UserDefaults.standard.set(true, forKey: seededV2Key)
            return
        }

        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1

        let v2Defaults: [(String, EmotionTagCategory, String)] = [
            // Location
            ("tag_home", .location, "house.fill"),
            ("tag_workplace", .location, "building.2.fill"),
            ("tag_outside", .location, "mappin.and.ellipse"),
            ("tag_commuting", .location, "car.fill"),
            // Activity
            ("tag_reading", .activity, "book.fill"),
            ("tag_cooking", .activity, "fork.knife"),
            ("tag_walking_activity", .activity, "figure.walk"),
            ("tag_shopping", .activity, "bag.fill"),
            ("tag_smartphone_sns", .activity, "iphone"),
            ("tag_hobby_fandom", .activity, "star.fill"),
            // Social
            ("tag_alone", .social, "person.fill"),
            ("tag_family", .social, "house.and.flag.fill"),
            ("tag_friends", .social, "person.2.fill"),
            ("tag_colleagues", .social, "person.3.fill"),
            ("tag_partner", .social, "heart.text.square.fill"),
            // Communication
            ("tag_praised", .communication, "hand.thumbsup.fill"),
            ("tag_deep_talk", .communication, "bubble.left.and.text.bubble.right.fill"),
            ("tag_argument", .communication, "bolt.horizontal.fill"),
            ("tag_social_fatigue", .communication, "person.wave.2.fill"),
            ("tag_listener", .communication, "ear.fill"),
        ]

        for (index, (name, category, icon)) in v2Defaults.enumerated() {
            let tag = EmotionTag(
                name: name,
                category: category,
                icon: icon,
                isDefault: true,
                sortOrder: nextOrder + index
            )
            context.insert(tag)
        }

        UserDefaults.standard.set(true, forKey: seededV2Key)
    }

    // MARK: - V3 Migration (expanded tags + rename)

    /// UserDefaults key for v3 seeded flag
    private static let seededV3Key = "defaultTagsSeededV3"

    /// Seed v3 tags for existing users: rename "疲れた" → "体の疲れ", add new tags
    @MainActor
    static func seedV3IfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededV3Key) else { return }

        let descriptor = FetchDescriptor<EmotionTag>()
        let allTags = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(allTags.map(\.name))

        // Rename "疲れた" → "体の疲れ" (preserve user's existing data association)
        if let tiredTag = allTags.first(where: { $0.name == "疲れた" }) {
            tiredTag.name = "体の疲れ"
            // Also update existing MoodEntry tags referencing the old name
            let entryDescriptor = FetchDescriptor<MoodEntry>()
            if let entries = try? context.fetch(entryDescriptor) {
                for entry in entries where entry.tags.contains("疲れた") {
                    entry.tags = entry.tags.map { $0 == "疲れた" ? "体の疲れ" : $0 }
                }
            }
        }

        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1

        let v3Defaults: [(String, EmotionTagCategory, String)] = [
            // Positive
            ("スッキリ", .positive, "sparkles"),
            // Negative
            ("心の疲れ", .negative, "brain"),
            // Factor
            ("体調不良", .factor, "cross.case.fill"),
            ("生理/PMS", .factor, "drop.fill"),
            ("天気", .factor, "cloud.sun.fill"),
            // Activity
            ("スマホ/SNS", .activity, "iphone"),
            ("趣味/推し活", .activity, "star.fill"),
            // Social
            ("恋人/パートナー", .social, "heart.text.square.fill"),
        ]

        for (index, (name, category, icon)) in v3Defaults.enumerated() {
            guard !existingNames.contains(name) else { continue }
            let tag = EmotionTag(
                name: name,
                category: category,
                icon: icon,
                isDefault: true,
                sortOrder: nextOrder + index
            )
            context.insert(tag)
        }

        UserDefaults.standard.set(true, forKey: seededV3Key)
    }

    // MARK: - V4 Migration (new categories: diet, exercise, communication, mind, morning)

    private static let seededV4Key = "defaultTagsSeededV4"

    /// Add diet, exercise, communication, mind, morning tags for existing users
    @MainActor
    static func seedV4IfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededV4Key) else { return }

        let descriptor = FetchDescriptor<EmotionTag>()
        let allTags = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(allTags.map(\.name))

        // Move "運動" from .factor to .exercise category
        if let exerciseTag = allTags.first(where: { $0.name == "運動" && $0.categoryRaw == "factor" }) {
            exerciseTag.categoryRaw = "exercise"
        }

        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1

        let v4Defaults: [(String, EmotionTagCategory, String)] = [
            // 朝の体感
            ("スッキリ起床", .morning, "sunrise.fill"),
            ("二度寝", .morning, "bed.double.fill"),
            ("悪夢", .morning, "moon.haze.fill"),
            ("寝足りない", .morning, "zzz"),
            // 頭のコンディション
            ("集中できた", .mind, "scope"),
            ("キャパオーバー", .mind, "exclamationmark.brain"),
            ("ぼーっとした", .mind, "cloud.fog.fill"),
            ("アイデアが湧いた", .mind, "lightbulb.fill"),
            ("マルチタスク", .mind, "square.stack.3d.up.fill"),
            // 食事・嗜好品
            ("カフェイン", .diet, "cup.and.heat.waves.fill"),
            ("アルコール", .diet, "wineglass.fill"),
            ("甘いもの", .diet, "birthday.cake.fill"),
            ("食べ過ぎ", .diet, "fork.knife.circle.fill"),
            ("自炊", .diet, "frying.pan.fill"),
            ("お水たくさん飲んだ", .diet, "drop.circle.fill"),
            // 運動
            ("ランニング", .exercise, "figure.run"),
            ("ウォーキング", .exercise, "figure.walk"),
            ("筋トレ", .exercise, "dumbbell.fill"),
            ("ヨガ/ストレッチ", .exercise, "figure.mind.and.body"),
            // コミュニケーション
            ("褒められた", .communication, "hand.thumbsup.fill"),
            ("深い話をした", .communication, "bubble.left.and.text.bubble.right.fill"),
            ("喧嘩した", .communication, "bolt.horizontal.fill"),
            ("気疲れした", .communication, "person.wave.2.fill"),
            ("聞き役だった", .communication, "ear.fill"),
        ]

        for (index, (name, category, icon)) in v4Defaults.enumerated() {
            guard !existingNames.contains(name) else { continue }
            let tag = EmotionTag(
                name: name,
                category: category,
                icon: icon,
                isDefault: true,
                sortOrder: nextOrder + index
            )
            context.insert(tag)
        }

        UserDefaults.standard.set(true, forKey: seededV4Key)
    }

    // MARK: - V5 Migration (Japanese names → system tag IDs for i18n)

    private static let seededV5Key = "defaultTagsSeededV5"

    /// Japanese display name → system tag ID mapping
    static let legacyNameToID: [String: String] = [
        // Positive
        "嬉しい": "tag_happy", "楽しい": "tag_fun", "穏やか": "tag_calm",
        "感謝": "tag_grateful", "元気": "tag_energetic", "スッキリ": "tag_refreshed",
        // Negative
        "不安": "tag_anxious", "体の疲れ": "tag_body_tired", "心の疲れ": "tag_mind_tired",
        "イライラ": "tag_irritated", "悲しい": "tag_sad", "ストレス": "tag_stressed",
        "疲れた": "tag_body_tired", // Legacy name from before V3
        // Morning
        "スッキリ起床": "tag_fresh_wakeup", "二度寝": "tag_overslept",
        "悪夢": "tag_nightmare", "寝足りない": "tag_not_enough_sleep",
        // Mind
        "集中できた": "tag_focused", "キャパオーバー": "tag_overwhelmed",
        "ぼーっとした": "tag_spaced_out", "アイデアが湧いた": "tag_inspired",
        "マルチタスク": "tag_multitasking",
        // Factor
        "仕事": "tag_work", "運動": "tag_exercise_legacy", "睡眠不足": "tag_lack_of_sleep",
        "人間関係": "tag_relationships", "リラックス": "tag_relaxing",
        "体調不良": "tag_feeling_sick", "生理/PMS": "tag_pms", "天気": "tag_weather",
        // Diet
        "カフェイン": "tag_caffeine", "アルコール": "tag_alcohol", "甘いもの": "tag_sweets",
        "食べ過ぎ": "tag_overeating", "自炊": "tag_home_cooking", "お水たくさん飲んだ": "tag_hydrated",
        // Exercise
        "ランニング": "tag_running", "ウォーキング": "tag_walking",
        "筋トレ": "tag_weight_training", "ヨガ/ストレッチ": "tag_yoga_stretch",
        // Location
        "自宅": "tag_home", "職場/学校": "tag_workplace", "外出先": "tag_outside", "移動中": "tag_commuting",
        // Activity
        "読書": "tag_reading", "料理": "tag_cooking", "散歩": "tag_walking_activity",
        "買い物": "tag_shopping", "スマホ/SNS": "tag_smartphone_sns", "趣味/推し活": "tag_hobby_fandom",
        // Social
        "一人": "tag_alone", "家族": "tag_family", "友人": "tag_friends",
        "同僚": "tag_colleagues", "恋人/パートナー": "tag_partner",
        // Communication
        "褒められた": "tag_praised", "深い話をした": "tag_deep_talk",
        "喧嘩した": "tag_argument", "気疲れした": "tag_social_fatigue", "聞き役だった": "tag_listener",
    ]

    /// Migrate all Japanese tag names to system IDs (EmotionTag.name + MoodEntry.tags)
    @MainActor
    static func seedV5IfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededV5Key) else { return }

        // 1. Rename EmotionTag.name from Japanese to ID
        let tagDescriptor = FetchDescriptor<EmotionTag>()
        let allTags = (try? context.fetch(tagDescriptor)) ?? []
        for tag in allTags where tag.isDefault {
            if let newID = legacyNameToID[tag.name] {
                tag.name = newID
            }
        }

        // 2. Rename tag references in MoodEntry.tags
        let entryDescriptor = FetchDescriptor<MoodEntry>()
        if let entries = try? context.fetch(entryDescriptor) {
            for entry in entries where !entry.tags.isEmpty {
                let updated = entry.tags.map { legacyNameToID[$0] ?? $0 }
                if updated != entry.tags {
                    entry.tags = updated
                }
            }
        }

        UserDefaults.standard.set(true, forKey: seededV5Key)
    }
}
