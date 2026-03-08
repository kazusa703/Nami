//
//  SliderScoreInput.swift
//  Nami
//
//  スライダーによるスコア入力コンポーネント
//

import SwiftUI

/// スライダーでスコアを入力するビュー
/// 大きな数字表示 + スライダー + 記録ボタン
struct SliderScoreInput: View {
    let maxScore: Int
    let minScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    @State private var sliderValue: Double = 5

    /// 現在のスライダー値を整数に変換
    private var currentScore: Int {
        Int(sliderValue.rounded())
    }

    var body: some View {
        VStack(spacing: 28) {
            // スコア数字表示
            Text("\(currentScore)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(themeColors.color(for: currentScore, maxScore: maxScore, minScore: minScore))
                .contentTransition(.numericText(value: Double(currentScore)))
                .animation(.snappy(duration: 0.15), value: currentScore)

            // スライダー
            VStack(spacing: 8) {
                Slider(
                    value: $sliderValue,
                    in: Double(minScore) ... Double(maxScore),
                    step: 1
                )
                .tint(themeColors.color(for: currentScore, maxScore: maxScore, minScore: minScore))

                // 範囲ラベル
                HStack {
                    Text("\(minScore)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(maxScore)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // 記録ボタン
            Button {
                onScore(currentScore)
            } label: {
                Text("記録する")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeColors.accent)
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            // 初期値を中間に設定
            sliderValue = Double(minScore + maxScore) / 2.0
        }
    }
}

#Preview {
    SliderScoreInput(maxScore: 100, minScore: 1, themeColors: .ocean) { score in
        print("Score: \(score)")
    }
    .padding()
}
