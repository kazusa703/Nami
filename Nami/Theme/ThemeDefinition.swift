//
//  ThemeDefinition.swift
//  Nami
//
//  4種類のテーマカラー定義
//

import SwiftUI

/// アプリテーマの列挙型
enum AppTheme: String, CaseIterable, Identifiable {
    case ocean = "Ocean"
    case lavender = "Lavender"
    case monoGold = "Mono Gold"
    case forest = "Forest"

    var id: String {
        rawValue
    }

    /// テーマの表示名
    var displayName: String {
        switch self {
        case .ocean: return String(localized: "Ocean")
        case .lavender: return String(localized: "Lavender")
        case .monoGold: return String(localized: "Mono Gold")
        case .forest: return String(localized: "Forest")
        }
    }

    /// テーマの説明
    var themeDescription: String {
        switch self {
        case .ocean: return String(localized: "海・波のイメージ、爽やか")
        case .lavender: return String(localized: "穏やか・癒し")
        case .monoGold: return String(localized: "ミニマル・高級感")
        case .forest: return String(localized: "自然・ウェルネス")
        }
    }

    /// テーマのカラーセット
    var colors: ThemeColors {
        switch self {
        case .ocean: return .ocean
        case .lavender: return .lavender
        case .monoGold: return .monoGold
        case .forest: return .forest
        }
    }
}

/// テーマごとのカラー定義
struct ThemeColors {
    /// 背景のグラデーション開始色（ライトモード）
    let backgroundStartLight: Color
    /// 背景のグラデーション終了色（ライトモード）
    let backgroundEndLight: Color
    /// 背景のグラデーション開始色（ダークモード）
    let backgroundStartDark: Color
    /// 背景のグラデーション終了色（ダークモード）
    let backgroundEndDark: Color
    /// アクセントカラー
    let accent: Color
    /// アクセントカラー（ライト版、ボタン背景等）
    let accentLight: Color
    /// グラフの線色
    let graphLine: Color
    /// グラフの塗りつぶし色
    let graphFill: Color
    /// 高スコア時の色（グラデーション用）
    let highScoreColor: Color
    /// 低スコア時の色（グラデーション用）
    let lowScoreColor: Color

    /// 背景グラデーション（カラースキームに応じて切り替え）
    func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let start = colorScheme == .dark ? backgroundStartDark : backgroundStartLight
        let end = colorScheme == .dark ? backgroundEndDark : backgroundEndLight
        return LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// スコアに応じた色を返す（minScore=低スコア色、maxScore=高スコア色のグラデーション）
    func color(for score: Int, maxScore: Int = 10, minScore: Int = 1) -> Color {
        let divisor = Double(max(maxScore - minScore, 1))
        let ratio = min(max(Double(score - minScore) / divisor, 0), 1)
        // 低→高のグラデーション補間
        return Color(
            red: lowScoreColor.components.red * (1 - ratio) + highScoreColor.components.red * ratio,
            green: lowScoreColor.components.green * (1 - ratio) + highScoreColor.components.green * ratio,
            blue: lowScoreColor.components.blue * (1 - ratio) + highScoreColor.components.blue * ratio
        )
    }
}

// MARK: - テーマカラープリセット

extension ThemeColors {
    /// Ocean（デフォルト）: 淡いブルー系グラデーション、ディープブルーアクセント
    static let ocean = ThemeColors(
        backgroundStartLight: Color(red: 0.90, green: 0.95, blue: 1.0),
        backgroundEndLight: Color(red: 0.80, green: 0.90, blue: 0.98),
        backgroundStartDark: Color(red: 0.08, green: 0.12, blue: 0.20),
        backgroundEndDark: Color(red: 0.05, green: 0.08, blue: 0.15),
        accent: Color(red: 0.10, green: 0.30, blue: 0.65),
        accentLight: Color(red: 0.75, green: 0.85, blue: 0.95),
        graphLine: Color(red: 0.15, green: 0.40, blue: 0.75),
        graphFill: Color(red: 0.15, green: 0.40, blue: 0.75).opacity(0.15),
        highScoreColor: Color(red: 0.10, green: 0.60, blue: 0.90),
        lowScoreColor: Color(red: 0.35, green: 0.50, blue: 0.70)
    )

    /// Lavender: ラベンダー・薄紫系、パープルアクセント
    static let lavender = ThemeColors(
        backgroundStartLight: Color(red: 0.94, green: 0.90, blue: 1.0),
        backgroundEndLight: Color(red: 0.88, green: 0.85, blue: 0.98),
        backgroundStartDark: Color(red: 0.12, green: 0.08, blue: 0.20),
        backgroundEndDark: Color(red: 0.08, green: 0.05, blue: 0.15),
        accent: Color(red: 0.50, green: 0.25, blue: 0.70),
        accentLight: Color(red: 0.88, green: 0.82, blue: 0.95),
        graphLine: Color(red: 0.55, green: 0.30, blue: 0.75),
        graphFill: Color(red: 0.55, green: 0.30, blue: 0.75).opacity(0.15),
        highScoreColor: Color(red: 0.65, green: 0.40, blue: 0.90),
        lowScoreColor: Color(red: 0.50, green: 0.40, blue: 0.65)
    )

    /// Mono Gold: 白黒ベース、ゴールドアクセント
    static let monoGold = ThemeColors(
        backgroundStartLight: Color(red: 0.97, green: 0.97, blue: 0.96),
        backgroundEndLight: Color(red: 0.93, green: 0.93, blue: 0.91),
        backgroundStartDark: Color(red: 0.10, green: 0.10, blue: 0.10),
        backgroundEndDark: Color(red: 0.06, green: 0.06, blue: 0.06),
        accent: Color(red: 0.75, green: 0.60, blue: 0.20),
        accentLight: Color(red: 0.95, green: 0.90, blue: 0.75),
        graphLine: Color(red: 0.80, green: 0.65, blue: 0.25),
        graphFill: Color(red: 0.80, green: 0.65, blue: 0.25).opacity(0.15),
        highScoreColor: Color(red: 0.85, green: 0.70, blue: 0.15),
        lowScoreColor: Color(red: 0.55, green: 0.50, blue: 0.40)
    )

    /// Forest: ソフトグリーン系、ダークグリーンアクセント
    static let forest = ThemeColors(
        backgroundStartLight: Color(red: 0.90, green: 0.97, blue: 0.92),
        backgroundEndLight: Color(red: 0.85, green: 0.94, blue: 0.88),
        backgroundStartDark: Color(red: 0.06, green: 0.14, blue: 0.10),
        backgroundEndDark: Color(red: 0.04, green: 0.10, blue: 0.07),
        accent: Color(red: 0.15, green: 0.50, blue: 0.30),
        accentLight: Color(red: 0.80, green: 0.92, blue: 0.85),
        graphLine: Color(red: 0.20, green: 0.55, blue: 0.35),
        graphFill: Color(red: 0.20, green: 0.55, blue: 0.35).opacity(0.15),
        highScoreColor: Color(red: 0.20, green: 0.70, blue: 0.40),
        lowScoreColor: Color(red: 0.40, green: 0.55, blue: 0.45)
    )
}

// MARK: - Color ヘルパー

extension Color {
    /// RGBコンポーネントを取得するヘルパー
    var components: (red: Double, green: Double, blue: Double, opacity: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
