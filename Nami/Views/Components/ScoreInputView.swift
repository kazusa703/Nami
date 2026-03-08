//
//  ScoreInputView.swift
//  Nami
//
//  スコア入力のディスパッチャー（ボタン/スライダーの切替）
//

import SwiftUI

/// スコア入力ビュー
/// inputType と maxScore に応じてボタンまたはスライダーを表示する
struct ScoreInputView: View {
    let inputType: ScoreInputType
    let maxScore: Int
    let minScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    /// maxScore > 30 の場合はスライダーを強制
    private var effectiveInputType: ScoreInputType {
        if maxScore > 30 {
            return .slider
        }
        return inputType
    }

    var body: some View {
        switch effectiveInputType {
        case .buttons:
            ButtonGridScoreInput(
                maxScore: maxScore,
                minScore: minScore,
                themeColors: themeColors,
                onScore: onScore
            )
        case .slider:
            SliderScoreInput(
                maxScore: maxScore,
                minScore: minScore,
                themeColors: themeColors,
                onScore: onScore
            )
        }
    }
}

#Preview {
    ScoreInputView(inputType: .buttons, maxScore: 10, minScore: 1, themeColors: .ocean) { _ in }
}
