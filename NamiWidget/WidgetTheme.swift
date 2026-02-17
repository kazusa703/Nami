//
//  WidgetTheme.swift
//  NamiWidget
//
//  ウィジェット用の軽量テーマ（App Group UserDefaultsから読み取り）
//

import SwiftUI

/// ウィジェット用テーマ定義
enum WidgetTheme: String, CaseIterable {
    case ocean = "Ocean"
    case lavender = "Lavender"
    case monoGold = "Mono Gold"
    case forest = "Forest"

    /// App Group UserDefaultsから現在のテーマを読み取る
    static var current: WidgetTheme {
        let saved = WidgetConstants.sharedUserDefaults.string(forKey: WidgetConstants.themeKey) ?? ""
        return WidgetTheme(rawValue: saved) ?? .ocean
    }

    /// アクセントカラー
    var accent: Color {
        switch self {
        case .ocean: return Color(red: 0.10, green: 0.30, blue: 0.65)
        case .lavender: return Color(red: 0.50, green: 0.25, blue: 0.70)
        case .monoGold: return Color(red: 0.75, green: 0.60, blue: 0.20)
        case .forest: return Color(red: 0.15, green: 0.50, blue: 0.30)
        }
    }

    /// グラフの線色
    var graphLine: Color {
        switch self {
        case .ocean: return Color(red: 0.15, green: 0.40, blue: 0.75)
        case .lavender: return Color(red: 0.55, green: 0.30, blue: 0.75)
        case .monoGold: return Color(red: 0.80, green: 0.65, blue: 0.25)
        case .forest: return Color(red: 0.20, green: 0.55, blue: 0.35)
        }
    }

    /// グラフの塗りつぶし色
    var graphFill: Color {
        graphLine.opacity(0.2)
    }

    /// 背景のグラデーション開始色（ライトモード）
    var backgroundStartLight: Color {
        switch self {
        case .ocean: return Color(red: 0.90, green: 0.95, blue: 1.0)
        case .lavender: return Color(red: 0.94, green: 0.90, blue: 1.0)
        case .monoGold: return Color(red: 0.97, green: 0.97, blue: 0.96)
        case .forest: return Color(red: 0.90, green: 0.97, blue: 0.92)
        }
    }

    /// 背景のグラデーション終了色（ライトモード）
    var backgroundEndLight: Color {
        switch self {
        case .ocean: return Color(red: 0.80, green: 0.90, blue: 0.98)
        case .lavender: return Color(red: 0.88, green: 0.85, blue: 0.98)
        case .monoGold: return Color(red: 0.93, green: 0.93, blue: 0.91)
        case .forest: return Color(red: 0.85, green: 0.94, blue: 0.88)
        }
    }

    /// 背景のグラデーション開始色（ダークモード）
    var backgroundStartDark: Color {
        switch self {
        case .ocean: return Color(red: 0.08, green: 0.12, blue: 0.20)
        case .lavender: return Color(red: 0.12, green: 0.08, blue: 0.20)
        case .monoGold: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .forest: return Color(red: 0.06, green: 0.14, blue: 0.10)
        }
    }

    /// 背景のグラデーション終了色（ダークモード）
    var backgroundEndDark: Color {
        switch self {
        case .ocean: return Color(red: 0.05, green: 0.08, blue: 0.15)
        case .lavender: return Color(red: 0.08, green: 0.05, blue: 0.15)
        case .monoGold: return Color(red: 0.06, green: 0.06, blue: 0.06)
        case .forest: return Color(red: 0.04, green: 0.10, blue: 0.07)
        }
    }

    /// 低スコア色
    var lowColor: Color {
        switch self {
        case .ocean: return Color(red: 0.60, green: 0.75, blue: 0.90)
        case .lavender: return Color(red: 0.75, green: 0.65, blue: 0.85)
        case .monoGold: return Color(red: 0.80, green: 0.78, blue: 0.70)
        case .forest: return Color(red: 0.65, green: 0.80, blue: 0.68)
        }
    }

    /// 高スコア色
    var highColor: Color {
        switch self {
        case .ocean: return Color(red: 0.05, green: 0.25, blue: 0.60)
        case .lavender: return Color(red: 0.40, green: 0.15, blue: 0.65)
        case .monoGold: return Color(red: 0.70, green: 0.55, blue: 0.10)
        case .forest: return Color(red: 0.08, green: 0.45, blue: 0.20)
        }
    }

    /// スコアに基づいた色を返す（低→高で色が濃くなる）
    /// RGB成分を直接補間して正確なブレンドを実現
    func colorForScore(_ score: Int, maxScore: Int) -> Color {
        let fraction = Double(score - 1) / Double(max(maxScore - 1, 1))
        let clamped = min(max(fraction, 0), 1)

        let (fromRGB, toRGB): (RGB, RGB)
        let t: Double

        if clamped < 0.5 {
            fromRGB = lowRGB
            toRGB = accentRGB
            t = clamped * 2
        } else {
            fromRGB = accentRGB
            toRGB = highRGB
            t = (clamped - 0.5) * 2
        }

        let r = fromRGB.r + (toRGB.r - fromRGB.r) * t
        let g = fromRGB.g + (toRGB.g - fromRGB.g) * t
        let b = fromRGB.b + (toRGB.b - fromRGB.b) * t
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - RGB補間用の値

    private struct RGB {
        let r: Double, g: Double, b: Double
    }

    private var lowRGB: RGB {
        switch self {
        case .ocean: return RGB(r: 0.60, g: 0.75, b: 0.90)
        case .lavender: return RGB(r: 0.75, g: 0.65, b: 0.85)
        case .monoGold: return RGB(r: 0.80, g: 0.78, b: 0.70)
        case .forest: return RGB(r: 0.65, g: 0.80, b: 0.68)
        }
    }

    private var accentRGB: RGB {
        switch self {
        case .ocean: return RGB(r: 0.10, g: 0.30, b: 0.65)
        case .lavender: return RGB(r: 0.50, g: 0.25, b: 0.70)
        case .monoGold: return RGB(r: 0.75, g: 0.60, b: 0.20)
        case .forest: return RGB(r: 0.15, g: 0.50, b: 0.30)
        }
    }

    private var highRGB: RGB {
        switch self {
        case .ocean: return RGB(r: 0.05, g: 0.25, b: 0.60)
        case .lavender: return RGB(r: 0.40, g: 0.15, b: 0.65)
        case .monoGold: return RGB(r: 0.70, g: 0.55, b: 0.10)
        case .forest: return RGB(r: 0.08, g: 0.45, b: 0.20)
        }
    }
}
