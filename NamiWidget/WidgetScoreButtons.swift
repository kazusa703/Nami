//
//  WidgetScoreButtons.swift
//  NamiWidget
//
//  ウィジェット用のインタラクティブスコアボタン
//

import SwiftUI
import WidgetKit
import AppIntents

/// maxScore>10 の場合に代表値を計算するヘルパー
enum WidgetScoreHelper {
    /// maxScore に対して5つの代表スコアを返す（均等分布）
    static func quickPickScores(maxScore: Int, count: Int = 5) -> [Int] {
        guard maxScore > count else {
            return Array(1...maxScore)
        }
        var scores: [Int] = []
        for i in 0..<count {
            let value = 1 + Int(Double(i) / Double(count - 1) * Double(maxScore - 1))
            scores.append(value)
        }
        return scores
    }
}

// MARK: - 小サイズ用スコアボタン（2行）

/// 小ウィジェット用: 2行×5列のスコアボタン
struct SmallScoreButtons: View {
    let maxScore: Int
    let theme: WidgetTheme

    var body: some View {
        let scores: [Int] = {
            if maxScore <= 10 {
                return Array(1...maxScore)
            } else {
                return WidgetScoreHelper.quickPickScores(maxScore: maxScore)
            }
        }()

        if maxScore <= 10 {
            // 2行×5列
            let firstRow = Array(scores.prefix(5))
            let secondRow = Array(scores.dropFirst(5))

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(firstRow, id: \.self) { score in
                        scoreButton(score: score)
                    }
                }
                if !secondRow.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(secondRow, id: \.self) { score in
                            scoreButton(score: score)
                        }
                    }
                }
            }
        } else {
            // 1行×5ボタン（代表値）
            HStack(spacing: 4) {
                ForEach(scores, id: \.self) { score in
                    scoreButton(score: score)
                }
            }
        }
    }

    private func scoreButton(score: Int) -> some View {
        Button(intent: RecordMoodIntent(score: score)) {
            Text("\(score)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.colorForScore(score, maxScore: maxScore))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 中サイズ用スコアボタン（1行）

/// 中ウィジェット用: 1行のスコアボタン
struct MediumScoreButtons: View {
    let maxScore: Int
    let theme: WidgetTheme

    var body: some View {
        let scores: [Int] = {
            if maxScore <= 10 {
                return Array(1...maxScore)
            } else {
                return WidgetScoreHelper.quickPickScores(maxScore: maxScore)
            }
        }()

        HStack(spacing: 4) {
            ForEach(scores, id: \.self) { score in
                Button(intent: RecordMoodIntent(score: score)) {
                    Text("\(score)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.colorForScore(score, maxScore: maxScore))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 大サイズ用スコアボタン（2行）

/// 大ウィジェット用: 2行×5列のスコアボタン
struct LargeScoreButtons: View {
    let maxScore: Int
    let theme: WidgetTheme

    var body: some View {
        let scores: [Int] = {
            if maxScore <= 10 {
                return Array(1...maxScore)
            } else {
                return WidgetScoreHelper.quickPickScores(maxScore: maxScore)
            }
        }()

        if maxScore <= 10 {
            let firstRow = Array(scores.prefix(5))
            let secondRow = Array(scores.dropFirst(5))

            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    ForEach(firstRow, id: \.self) { score in
                        scoreButton(score: score)
                    }
                }
                if !secondRow.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(secondRow, id: \.self) { score in
                            scoreButton(score: score)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 5) {
                ForEach(scores, id: \.self) { score in
                    scoreButton(score: score)
                }
            }
        }
    }

    private func scoreButton(score: Int) -> some View {
        Button(intent: RecordMoodIntent(score: score)) {
            Text("\(score)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.colorForScore(score, maxScore: maxScore))
                )
        }
        .buttonStyle(.plain)
    }
}
