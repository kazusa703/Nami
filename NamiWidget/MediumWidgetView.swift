//
//  MediumWidgetView.swift
//  NamiWidget
//
//  中サイズウィジェット: 左パネル（スコア+ストリーク+トレンド）+ 右パネル（7日チャート）+ スコアボタン
//

import SwiftUI
import WidgetKit

/// 中サイズウィジェット
struct MediumWidgetView: View {
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

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // 左パネル: スコア + メタ情報
                    leftPanel(theme: theme)
                        .frame(maxWidth: 110)

                    // 区切り線
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 1.5)
                        .padding(.vertical, 4)

                    // 右パネル: 7日間チャート
                    rightPanel(theme: theme)
                }

                // インタラクティブスコアボタン（1行）
                MediumScoreButtons(maxScore: entry.maxScore, theme: theme)
            }
            .padding(14)
        }
    }

    // MARK: - 左パネル

    private func leftPanel(theme: WidgetTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー: Nami ロゴ
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

            // メインスコア
            if let score = entry.latestScore {
                Text("\(score)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .minimumScaleFactor(0.6)
            } else {
                Text("--")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.4))
            }

            Spacer()

            // メタ情報: ストリーク + トレンド
            VStack(alignment: .leading, spacing: 4) {
                // ストリーク
                if entry.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(entry.currentStreak)日連続")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // 週間トレンド
                if let trend = entry.weeklyTrend {
                    HStack(spacing: 3) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(trend >= 0 ? .green : .orange)
                        Text(String(format: "%+.1f", trend))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 右パネル

    private func rightPanel(theme: WidgetTheme) -> some View {
        VStack(spacing: 6) {
            // 週間平均バー
            if let avg = entry.weeklyAverage {
                HStack {
                    Spacer()
                    Text("週間平均")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", avg))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                }
            }

            // 7日間のバーチャート（少し縮小）
            if hasData {
                barChart(theme: theme)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("記録を始めよう")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - バーチャート

    private func barChart(theme: WidgetTheme) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                let daily = index < entry.dailyData.count ? entry.dailyData[index] : nil

                VStack(spacing: 2) {
                    // バー
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            if let daily, daily.entryCount > 0 {
                                let fraction = daily.averageScore / Double(entry.maxScore)
                                let height = max(geo.size.height * CGFloat(fraction), 4)
                                let score = max(1, Int(daily.averageScore.rounded()))

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(theme.colorForScore(score, maxScore: entry.maxScore))
                                    .frame(height: height)
                            } else {
                                // 記録なしの日: 薄いプレースホルダー
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray5).opacity(0.4))
                                    .frame(height: 4)
                            }
                        }
                    }

                    // 曜日ラベル
                    if let daily {
                        Text(dayLabel(for: daily.date))
                            .font(.system(size: 7, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - ヘルパー

    private var hasData: Bool {
        entry.dailyData.contains { $0.entryCount > 0 }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        let full = formatter.string(from: date)
        return String(full.prefix(1))
    }
}
