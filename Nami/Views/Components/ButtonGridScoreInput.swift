//
//  ButtonGridScoreInput.swift
//  Nami
//
//  ボタングリッドによるスコア入力コンポーネント
//

import SwiftUI

/// ボタングリッドでスコアを入力するビュー
/// minScore〜maxScoreに応じてグリッドレイアウトを調整する
struct ButtonGridScoreInput: View {
    let minScore: Int
    let maxScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    /// ボタンの総数
    private var totalButtons: Int {
        maxScore - minScore + 1
    }

    /// グリッドの列数（ボタン数に応じて調整）
    private var columns: [GridItem] {
        let count: Int
        switch totalButtons {
        case ...10:
            count = 5  // 2行×5列
        case ...21:
            count = 7  // 3行×7列
        case ...30:
            count = 6  // 5行×6列
        default:
            count = 5
        }
        return Array(repeating: GridItem(.flexible(), spacing: compact ? 6 : 12), count: count)
    }

    /// コンパクトモード（ボタン数が多い場合）
    private var compact: Bool {
        totalButtons > 10
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: compact ? 6 : 12) {
            ForEach(Array(minScore...maxScore), id: \.self) { score in
                MoodButton(score: score, minScore: minScore, maxScore: maxScore, themeColors: themeColors, compact: compact) {
                    onScore(score)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 20)
    }
}

#Preview {
    ButtonGridScoreInput(minScore: 1, maxScore: 10, themeColors: .ocean) { _ in }
        .padding()
}
