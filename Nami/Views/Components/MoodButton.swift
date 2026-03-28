//
//  MoodButton.swift
//  Nami
//
//  1〜maxScoreのスコアボタンコンポーネント
//

import SwiftUI

/// 個別の気分スコアボタン
/// 大きく押しやすいサイズ（最低44pt）で表示する
struct MoodButton: View {
    let score: Int
    let minScore: Int
    let maxScore: Int
    let themeColors: ThemeColors
    /// コンパクトモード（ボタン数が多い場合に小サイズ化）
    let compact: Bool
    let action: () -> Void

    init(score: Int, minScore: Int = 1, maxScore: Int = 10, themeColors: ThemeColors, compact: Bool = false, action: @escaping () -> Void) {
        self.score = score
        self.minScore = minScore
        self.maxScore = maxScore
        self.themeColors = themeColors
        self.compact = compact
        self.action = action
    }

    /// スコアに対応する色
    private var scoreColor: Color {
        themeColors.color(for: score, minScore: minScore, maxScore: maxScore)
    }

    /// Descriptive accessibility label (e.g. "スコア7、良い気分")
    private var scoreAccessibilityLabel: String {
        let range = maxScore - minScore
        let position = Double(score - minScore) / Double(max(range, 1))
        let mood: String
        if position >= 0.8 { mood = String(localized: "とても良い気分") }
        else if position >= 0.6 { mood = String(localized: "良い気分") }
        else if position >= 0.4 { mood = String(localized: "普通") }
        else if position >= 0.2 { mood = String(localized: "やや低い気分") }
        else { mood = String(localized: "低い気分") }
        return String(localized: "スコア\(score)、\(mood)")
    }

    var body: some View {
        Button(action: action) {
            Text("\(score)")
                .font(.system(compact ? .caption : .title2, design: .rounded, weight: .bold))
                .frame(minWidth: compact ? 44 : 56, minHeight: compact ? 44 : 56)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 10 : 14)
                        .fill(scoreColor.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 10 : 14)
                        .stroke(scoreColor, lineWidth: compact ? 1.5 : 2)
                )
                .foregroundStyle(scoreColor)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(scoreAccessibilityLabel)
        .accessibilityValue(String(localized: "\(minScore)から\(maxScore)の範囲"))
        .accessibilityHint(String(localized: "ダブルタップで記録"))
        .accessibilityAddTraits(.isButton)
    }
}

/// タップ時にスケールダウンするボタンスタイル
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HStack {
        ForEach(1 ... 5, id: \.self) { score in
            MoodButton(score: score, themeColors: .ocean) {}
        }
    }
    .padding()
}
