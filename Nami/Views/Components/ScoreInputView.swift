//
//  ScoreInputView.swift
//  Nami
//
//  スコア入力のディスパッチャー（ボタン/スライダーの切替）
//

import SwiftUI

/// スコア入力ビュー
/// inputType と minScore/maxScore に応じてボタンまたはスライダーを表示する
struct ScoreInputView: View {
    let inputType: ScoreInputType
    let minScore: Int
    let maxScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    /// ボタン数が多すぎる場合はスライダーを強制
    private var effectiveInputType: ScoreInputType {
        let totalButtons = maxScore - minScore + 1
        if totalButtons > 31 {
            return .slider
        }
        return inputType
    }

    var body: some View {
        switch effectiveInputType {
        case .buttons:
            ButtonGridScoreInput(
                minScore: minScore,
                maxScore: maxScore,
                themeColors: themeColors,
                onScore: onScore
            )
        case .slider:
            SliderScoreInput(
                minScore: minScore,
                maxScore: maxScore,
                themeColors: themeColors,
                onScore: onScore
            )
        }
    }
}

#Preview {
    ScoreInputView(inputType: .buttons, minScore: 1, maxScore: 10, themeColors: .ocean) { _ in }
}
