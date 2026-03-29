//
//  EmotionTag.swift
//  Nami
//
//  タグのデータモデル
//

import Foundation
import SwiftData

/// タグのカテゴリ
enum EmotionTagCategory: String, CaseIterable, Identifiable, Codable {
    case positive // ポジティブ感情
    case negative // ネガティブ感情
    case factor // 要因
    case diet // 食事・嗜好品
    case exercise // 運動
    case location // 場所
    case activity // 活動
    case social // 人
    case communication // コミュニケーション
    case mind // 頭のコンディション
    case morning // 朝の体感
    case custom // ユーザー作成

    var id: String {
        rawValue
    }

    /// 表示名
    var displayName: String {
        switch self {
        case .positive: return String(localized: "ポジティブ")
        case .negative: return String(localized: "ネガティブ")
        case .factor: return String(localized: "要因")
        case .diet: return String(localized: "食事・嗜好品")
        case .exercise: return String(localized: "運動")
        case .location: return String(localized: "場所")
        case .activity: return String(localized: "活動")
        case .social: return String(localized: "人")
        case .communication: return String(localized: "コミュニケーション")
        case .mind: return String(localized: "頭のコンディション")
        case .morning: return String(localized: "朝の体感")
        case .custom: return String(localized: "カスタム")
        }
    }

    /// カテゴリのアイコン
    var icon: String {
        switch self {
        case .positive: return "sun.max.fill"
        case .negative: return "cloud.rain.fill"
        case .factor: return "leaf.fill"
        case .diet: return "fork.knife"
        case .exercise: return "figure.run"
        case .location: return "mappin.and.ellipse"
        case .activity: return "figure.walk"
        case .social: return "person.2.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .mind: return "brain.head.profile"
        case .morning: return "sunrise.fill"
        case .custom: return "star.fill"
        }
    }

    /// ソート順
    var sortIndex: Int {
        switch self {
        case .positive: return 0
        case .negative: return 1
        case .morning: return 2
        case .mind: return 3
        case .factor: return 4
        case .diet: return 5
        case .exercise: return 6
        case .activity: return 7
        case .location: return 8
        case .social: return 9
        case .communication: return 10
        case .custom: return 11
        }
    }
}

/// タグモデル
/// ユーザーが気分記録に付けるタグ（デフォルト + カスタム）
@Model
class EmotionTag {
    var id: UUID = UUID()
    var name: String = "" // タグ名（例: 嬉しい、疲れた）
    var categoryRaw: String = "custom" // カテゴリ（EmotionTagCategory.rawValue）
    var icon: String = "tag.fill" // SF Symbols アイコン名
    var isDefault: Bool = false // デフォルトタグかどうか
    var sortOrder: Int = 0 // 表示順
    var createdAt: Date = Date.now

    /// カテゴリのアクセサ
    var category: EmotionTagCategory {
        get { EmotionTagCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    /// Display name: system tags are translated via String(localized:), custom tags show raw name
    var displayName: String {
        isDefault ? String(localized: String.LocalizationValue(name)) : name
    }

    init(name: String, category: EmotionTagCategory, icon: String = "tag.fill", isDefault: Bool = false, sortOrder: Int = 0) {
        id = UUID()
        self.name = name
        categoryRaw = category.rawValue
        self.icon = icon
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        createdAt = .now
    }
}

// MARK: - System Tag ID ↔ Display Name Helper

/// Resolves a tag string (which may be a system tag ID or custom text) to its display name
enum TagDisplayHelper {
    /// Convert a tag name stored in MoodEntry.tags to a display string
    static func displayName(for tagName: String) -> String {
        // If it starts with "tag_" prefix, it's a system tag ID → translate
        if tagName.hasPrefix("tag_") {
            return String(localized: String.LocalizationValue(tagName))
        }
        // Otherwise it's a user-created custom tag or legacy name
        return tagName
    }
}
