//
//  ButtonGridScoreInput.swift
//  Nami
//
//  ボタングリッドによるスコア入力コンポーネント
//

import SwiftUI

/// ボタングリッドでスコアを入力するビュー
/// maxScoreに応じてグリッドレイアウトを調整する
struct ButtonGridScoreInput: View {
    let maxScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    /// グリッドの列数（maxScoreに応じて調整）
    private var columns: [GridItem] {
        let count: Int
        switch maxScore {
        case ...10:
            count = 5  // 2行×5列
        case ...30:
            count = 6  // 5行×6列
        default:
            count = 5
        }
        return Array(repeating: GridItem(.flexible(), spacing: compact ? 6 : 12), count: count)
    }

    /// コンパクトモード（ボタン数が多い場合）
    private var compact: Bool {
        maxScore > 10
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: compact ? 6 : 12) {
            ForEach(1...maxScore, id: \.self) { score in
                MoodButton(score: score, maxScore: maxScore, themeColors: themeColors, compact: compact) {
                    onScore(score)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 20)
    }
}

#Preview {
    ButtonGridScoreInput(maxScore: 10, themeColors: .ocean) { _ in }
        .padding()
}
