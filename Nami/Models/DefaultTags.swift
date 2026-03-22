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
            // ポジティブ
            ("嬉しい", .positive, "face.smiling.inverse"),
            ("楽しい", .positive, "party.popper.fill"),
            ("穏やか", .positive, "leaf.fill"),
            ("感謝", .positive, "heart.fill"),
            ("元気", .positive, "bolt.fill"),
            // ネガティブ
            ("不安", .negative, "exclamationmark.triangle.fill"),
            ("疲れた", .negative, "battery.25percent"),
            ("イライラ", .negative, "flame.fill"),
            ("悲しい", .negative, "cloud.rain.fill"),
            ("ストレス", .negative, "tornado"),
            // 要因
            ("仕事", .factor, "briefcase.fill"),
            ("運動", .factor, "figure.run"),
            ("睡眠不足", .factor, "moon.zzz.fill"),
            ("人間関係", .factor, "person.2.fill"),
            ("リラックス", .factor, "cup.and.saucer.fill"),
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
        let v2Names = Set(["自宅", "職場/学校", "外出先", "移動中",
                           "読書", "料理", "散歩", "買い物",
                           "一人", "家族", "友人", "同僚"])
        let existingNames = Set(allTags.map(\.name))
        if !v2Names.isDisjoint(with: existingNames) {
            // Some v2 tags already exist
            UserDefaults.standard.set(true, forKey: seededV2Key)
            return
        }

        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1

        let v2Defaults: [(String, EmotionTagCategory, String)] = [
            // 場所
            ("自宅", .location, "house.fill"),
            ("職場/学校", .location, "building.2.fill"),
            ("外出先", .location, "mappin.and.ellipse"),
            ("移動中", .location, "car.fill"),
            // 活動
            ("読書", .activity, "book.fill"),
            ("料理", .activity, "fork.knife"),
            ("散歩", .activity, "figure.walk"),
            ("買い物", .activity, "bag.fill"),
            // 人
            ("一人", .social, "person.fill"),
            ("家族", .social, "house.and.flag.fill"),
            ("友人", .social, "person.2.fill"),
            ("同僚", .social, "person.3.fill"),
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
}
