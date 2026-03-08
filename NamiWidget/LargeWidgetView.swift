//
//  LargeWidgetView.swift
//  NamiWidget
//
//  大サイズウィジェット: ヘッダー + 統計カード + スコアボタン + 7日バーチャート + ピクセルストリップ
//

import SwiftUI
import WidgetKit

/// 大サイズウィジェット
struct LargeWidgetView: View {
    let entry: MoodWidgetEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = entry.theme

        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    colorScheme == .dark ? theme.backgroundStartDark : theme.backgroundStartLight,
                    colorScheme == .dark ? theme.backgroundEndDark : theme.backgroundEndLight,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                // ヘッダー: ロゴ + ストリーク
                headerSection(theme: theme)

                // メインスコアと統計カード
                statsRow(theme: theme)

                // インタラクティブスコアボタン（2行）
                LargeScoreButtons(maxScore: entry.maxScore, minScore: entry.minScore, theme: theme)

                // 7日間の詳細バーチャート
                dailyBarChart(theme: theme)

                // 7日ピクセルストリップ（日付ラベル付き）
                pixelStrip(theme: theme)
            }
            .padding(16)
        }
    }

    // MARK: - ヘッダー

    private func headerSection(theme: WidgetTheme) -> some View {
        HStack {
            Link(destination: URL(string: "nami://open") ?? URL(string: "about:blank")!) {
                HStack(spacing: 4) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Nami")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(theme.accent)
            }

            Spacer()

            // ストリーク
            if entry.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("\(entry.currentStreak)日連続")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // 今日の記録数
            if entry.todayCount > 0 {
                Text("今日 \(entry.todayCount)件")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - 統計カード

    private func statsRow(theme: WidgetTheme) -> some View {
        HStack(spacing: 10) {
            // 最新スコア
            statCard(
                title: "今の気分",
                value: entry.latestScore.map { "\($0)" } ?? "--",
                icon: "heart.fill",
                iconColor: theme.accent,
                theme: theme
            )

            // 週間平均
            statCard(
                title: "週間平均",
                value: entry.weeklyAverage.map { String(format: "%.1f", $0) } ?? "--",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: theme.graphLine,
                theme: theme
            )

            // 月間平均
            statCard(
                title: "月間平均",
                value: entry.monthlyAverage.map { String(format: "%.1f", $0) } ?? "--",
                icon: "calendar",
                iconColor: theme.accent.opacity(0.7),
                theme: theme
            )

            // トレンド
            let trendText: String = {
                guard let trend = entry.weeklyTrend else { return "--" }
                return String(format: "%+.1f", trend)
            }()
            let trendColor: Color = {
                guard let trend = entry.weeklyTrend else { return .secondary }
                return trend >= 0 ? .green : .orange
            }()
            statCard(
                title: "先週比",
                value: trendText,
                icon: (entry.weeklyTrend ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right",
                iconColor: trendColor,
                theme: theme
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, iconColor: Color, theme _: WidgetTheme) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.03)
                )
        )
    }

    // MARK: - 7日バーチャート

    private func dailyBarChart(theme: WidgetTheme) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0 ..< 7, id: \.self) { index in
                let daily = index < entry.dailyData.count ? entry.dailyData[index] : nil

                VStack(spacing: 3) {
                    // スコアラベル
                    if let daily, daily.entryCount > 0 {
                        Text(String(format: "%.0f", daily.averageScore))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accent)
                    } else {
                        Text("")
                            .font(.system(size: 9))
                    }

                    // バー
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            if let daily, daily.entryCount > 0 {
                                let fraction = daily.averageScore / Double(entry.maxScore)
                                let height = max(geo.size.height * CGFloat(fraction), 6)
                                let score = max(1, Int(daily.averageScore.rounded()))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                theme.colorForScore(score, maxScore: entry.maxScore),
                                                theme.colorForScore(score, maxScore: entry.maxScore).opacity(0.6),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: height)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5).opacity(0.3))
                                    .frame(height: 6)
                            }
                        }
                    }
                    .frame(height: 50)

                    // 日付ラベル（M/d）
                    if let daily {
                        Text(dateLabel(for: daily.date))
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - ピクセルストリップ

    private func pixelStrip(theme: WidgetTheme) -> some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 7, id: \.self) { index in
                let daily = index < entry.dailyData.count ? entry.dailyData[index] : nil
                let isToday = index == entry.dailyData.count - 1

                VStack(spacing: 2) {
                    // 曜日ラベル
                    if let daily {
                        Text(dayLabel(for: daily.date))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(isToday ? theme.accent : .secondary)
                    }

                    // 色付きセル（記録数に応じてサイズ変更）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pixelColor(daily: daily, theme: theme))
                        .frame(height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isToday ? theme.accent : .clear, lineWidth: 1.5)
                        )
                        .overlay {
                            // 記録件数表示
                            if let daily, daily.entryCount > 1 {
                                Text("\(daily.entryCount)")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - ヘルパー

    private func pixelColor(daily: DailyMood?, theme: WidgetTheme) -> Color {
        guard let daily, daily.entryCount > 0 else {
            return Color(.systemGray5).opacity(0.3)
        }
        let score = max(1, Int(daily.averageScore.rounded()))
        return theme.colorForScore(score, maxScore: entry.maxScore)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        let full = formatter.string(from: date)
        return String(full.prefix(1))
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
