//
//  SmallWidgetView.swift
//  NamiWidget
//
//  小サイズウィジェット: スコア + インタラクティブスコアボタン
//

import SwiftUI
import WidgetKit

/// 小サイズウィジェット
struct SmallWidgetView: View {
    let entry: MoodWidgetEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = entry.theme

        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    colorScheme == .dark ? theme.backgroundStartDark : theme.backgroundStartLight,
                    colorScheme == .dark ? theme.backgroundEndDark : theme.backgroundEndLight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // ヘッダー: Nami + ストリーク
                HStack {
                    Link(destination: URL(string: "nami://open")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Nami")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(theme.accent.opacity(0.7))
                    }

                    Spacer()

                    // ストリークバッジ
                    if entry.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                            Text("\(entry.currentStreak)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.orange)
                    }
                }

                Spacer()

                // メインスコア（少し縮小）
                if let score = entry.latestScore {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .minimumScaleFactor(0.6)

                    // 今日の記録数
                    if entry.todayCount > 0 {
                        Text("今日 \(entry.todayCount)件")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.accent.opacity(0.4))
                }

                Spacer()

                // インタラクティブスコアボタン（2行）
                SmallScoreButtons(maxScore: entry.maxScore, theme: theme)
            }
            .padding(14)
        }
    }
}
