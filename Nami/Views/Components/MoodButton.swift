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
    let maxScore: Int
    let themeColors: ThemeColors
    /// コンパクトモード（ボタン数が多い場合に小サイズ化）
    let compact: Bool
    let action: () -> Void

    init(score: Int, maxScore: Int = 10, themeColors: ThemeColors, compact: Bool = false, action: @escaping () -> Void) {
        self.score = score
        self.maxScore = maxScore
        self.themeColors = themeColors
        self.compact = compact
        self.action = action
    }

    /// スコアに対応する色
    private var scoreColor: Color {
        themeColors.color(for: score, maxScore: maxScore)
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
        .accessibilityLabel(String(localized: "気分スコア \(score)"))
        .accessibilityHint(String(localized: "タップして気分を\(score)として記録"))
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
        ForEach(1...5, id: \.self) { score in
            MoodButton(score: score, themeColors: .ocean) { }
        }
    }
    .padding()
}
