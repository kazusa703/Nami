//
//  DefaultTags.swift
//  Nami
//
//  デフォルト感情タグの初期データ
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

        // Set flag immediately to prevent re-entry from concurrent calls
        UserDefaults.standard.set(true, forKey: seededKey)

        // CloudKit経由でタグが既に同期されている場合はスキップ
        let descriptor = FetchDescriptor<EmotionTag>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount > 0 {
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
    }

    /// Remove duplicate tags (caused by CloudKit sync), keeping one per name
    @MainActor
    static func deduplicateIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<EmotionTag>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let allTags = try? context.fetch(descriptor), allTags.count > 1 else { return }

        // Sort: default tags first, then by sortOrder (keeps defaults when deduplicating)
        let sorted = allTags.sorted {
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            return $0.sortOrder < $1.sortOrder
        }

        var seen = Set<String>()
        for tag in sorted {
            if seen.contains(tag.name) {
                context.delete(tag)
            } else {
                seen.insert(tag.name)
            }
        }
    }
}
