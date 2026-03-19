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
    let minScore: Int
    let maxScore: Int
    let themeColors: ThemeColors
    let onScore: (Int) -> Void

    @State private var sliderValue: Double = 5
    /// ユーザーがスライダーに触れたかどうか
    @State private var hasInteracted: Bool = false
    /// onAppear初期値セット完了フラグ
    @State private var didSetInitial: Bool = false

    /// 現在のスライダー値を整数に変換
    private var currentScore: Int {
        Int(sliderValue.rounded())
    }

    var body: some View {
        VStack(spacing: 28) {
            // スコア数字表示（触れるまで「?」）
            if hasInteracted {
                Text("\(currentScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColors.color(for: currentScore, minScore: minScore, maxScore: maxScore))
                    .contentTransition(.numericText(value: Double(currentScore)))
                    .animation(.snappy(duration: 0.15), value: currentScore)
            } else {
                VStack(spacing: 8) {
                    Text("?")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("スライダーを動かしてスコアを選択")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // スライダー
            VStack(spacing: 8) {
                Slider(
                    value: $sliderValue,
                    in: Double(minScore)...Double(maxScore),
                    step: 1
                )
                .tint(hasInteracted
                    ? themeColors.color(for: currentScore, minScore: minScore, maxScore: maxScore)
                    : Color.gray.opacity(0.4)
                )

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

            // 記録ボタン（触れるまでは無効）
            Button {
                onScore(currentScore)
            } label: {
                Text("記録する")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(hasInteracted ? themeColors.accent : Color.gray.opacity(0.3))
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!hasInteracted)
            .padding(.horizontal, 40)
        }
        .onChange(of: sliderValue) {
            // onAppearの初期値セットは無視し、それ以降の変更でインタラクション検知
            if didSetInitial && !hasInteracted {
                withAnimation(.easeOut(duration: 0.2)) {
                    hasInteracted = true
                }
            }
        }
        .onAppear {
            sliderValue = Double(minScore + maxScore) / 2.0
            // 次のランループで初期セット完了をマーク
            DispatchQueue.main.async {
                didSetInitial = true
            }
        }
    }
}

#Preview {
    SliderScoreInput(minScore: -10, maxScore: 10, themeColors: .ocean) { score in
        print("Score: \(score)")
    }
    .padding()
}
