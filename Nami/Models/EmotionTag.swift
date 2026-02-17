//
//  EmotionTag.swift
//  Nami
//
//  感情タグのデータモデル
//

import Foundation
import SwiftData

/// 感情タグのカテゴリ
enum EmotionTagCategory: String, CaseIterable, Identifiable, Codable {
    case positive = "positive"   // ポジティブ感情
    case negative = "negative"   // ネガティブ感情
    case factor = "factor"       // 要因・活動
    case custom = "custom"       // ユーザー作成

    var id: String { rawValue }

    /// 表示名
    var displayName: String {
        switch self {
        case .positive: return String(localized: "ポジティブ")
        case .negative: return String(localized: "ネガティブ")
        case .factor: return String(localized: "要因")
        case .custom: return String(localized: "カスタム")
        }
    }

    /// カテゴリのアイコン
    var icon: String {
        switch self {
        case .positive: return "sun.max.fill"
        case .negative: return "cloud.rain.fill"
        case .factor: return "leaf.fill"
        case .custom: return "star.fill"
        }
    }

    /// ソート順
    var sortIndex: Int {
        switch self {
        case .positive: return 0
        case .negative: return 1
        case .factor: return 2
        case .custom: return 3
        }
    }
}

/// 感情タグモデル
/// ユーザーが気分記録に付けるタグ（デフォルト + カスタム）
@Model
class EmotionTag {
    var id: UUID = UUID()
    var name: String = ""           // タグ名（例: 嬉しい、疲れた）
    var categoryRaw: String = "custom"  // カテゴリ（EmotionTagCategory.rawValue）
    var icon: String = "tag.fill"   // SF Symbols アイコン名
    var isDefault: Bool = false     // デフォルトタグかどうか
    var sortOrder: Int = 0          // 表示順
    var createdAt: Date = Date.now

    /// カテゴリのアクセサ
    var category: EmotionTagCategory {
        get { EmotionTagCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    init(name: String, category: EmotionTagCategory, icon: String = "tag.fill", isDefault: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.icon = icon
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = .now
    }
}
