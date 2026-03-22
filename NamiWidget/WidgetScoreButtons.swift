//
//  WidgetScoreButtons.swift
//  NamiWidget
//
//  Interactive score buttons for widgets (1 row of 5 representative scores)
//

import SwiftUI
import WidgetKit
import AppIntents

/// Helper to compute representative scores for a given range
enum WidgetScoreHelper {
    /// Returns `count` evenly-distributed representative scores from minScore to maxScore
    static func quickPickScores(minScore: Int, maxScore: Int, count: Int = 5) -> [Int] {
        let total = maxScore - minScore + 1
        guard total > count else {
            return Array(minScore...maxScore)
        }
        var scores: [Int] = []
        for i in 0..<count {
            let value = minScore + Int(Double(i) / Double(count - 1) * Double(maxScore - minScore))
            scores.append(value)
        }
        return scores
    }
}

// MARK: - Small widget score buttons (1 row × 5)

struct SmallScoreButtons: View {
    let minScore: Int
    let maxScore: Int
    let theme: WidgetTheme

    var body: some View {
        let scores = WidgetScoreHelper.quickPickScores(minScore: minScore, maxScore: maxScore, count: 5)

        HStack(spacing: 6) {
            ForEach(scores, id: \.self) { score in
                Button(intent: RecordMoodIntent(score: score)) {
                    Text("\(score)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.colorForScore(score, minScore: minScore, maxScore: maxScore))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Medium widget score buttons (1 row × 5)

struct MediumScoreButtons: View {
    let minScore: Int
    let maxScore: Int
    let theme: WidgetTheme

    var body: some View {
        let scores = WidgetScoreHelper.quickPickScores(minScore: minScore, maxScore: maxScore, count: 5)

        HStack(spacing: 6) {
            ForEach(scores, id: \.self) { score in
                Button(intent: RecordMoodIntent(score: score)) {
                    Text("\(score)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.colorForScore(score, minScore: minScore, maxScore: maxScore))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Large widget score buttons (1 row × 5)

struct LargeScoreButtons: View {
    let minScore: Int
    let maxScore: Int
    let theme: WidgetTheme

    var body: some View {
        let scores = WidgetScoreHelper.quickPickScores(minScore: minScore, maxScore: maxScore, count: 5)

        HStack(spacing: 6) {
            ForEach(scores, id: \.self) { score in
                Button(intent: RecordMoodIntent(score: score)) {
                    Text("\(score)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.colorForScore(score, minScore: minScore, maxScore: maxScore))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
