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
    let minScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    /// Total number of buttons
    private var buttonCount: Int {
        maxScore - minScore + 1
    }

    /// グリッドの列数（maxScoreに応じて調整）
    private var columns: [GridItem] {
        let count: Int
        switch buttonCount {
        case ...11:
            count = 5 // 2行×5列 (1-10) or 3行 (-10〜10 → 21 buttons → 7列)
        case ...30:
            count = 6 // 5行×6列
        default:
            count = 5
        }
        // -10〜10 (21 buttons) → 7列×3行
        let finalCount = buttonCount == 21 ? 7 : count
        return Array(repeating: GridItem(.flexible(), spacing: compact ? 6 : 12), count: finalCount)
    }

    /// コンパクトモード（ボタン数が多い場合）
    private var compact: Bool {
        buttonCount > 11
    }

    var body: some View {
        let safeMin = minScore
        let safeMax = max(safeMin, maxScore)
        LazyVGrid(columns: columns, spacing: compact ? 6 : 12) {
            ForEach(safeMin ... safeMax, id: \.self) { score in
                MoodButton(score: score, maxScore: maxScore, minScore: minScore, themeColors: themeColors, compact: compact) {
                    onScore(score)
                }
            }
        }
        .padding(.horizontal, compact ? 8 : 20)
    }
}

#Preview {
    ButtonGridScoreInput(maxScore: 10, minScore: 1, themeColors: .ocean) { _ in }
        .padding()
}
