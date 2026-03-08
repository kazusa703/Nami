//
//  MonthlyHeatmapView.swift
//  Nami
//
//  月間カレンダーヒートマップ - 日ごとの平均スコアを色で表示
//

import SwiftUI

/// 月間カレンダーヒートマップ
/// 各日のセルをスコア平均に基づいた色で表示する
struct MonthlyHeatmapView: View {
    let entries: [MoodEntry]
    let currentMaxScore: Int
    var currentMinScore: Int = 1
    let colors: ThemeColors

    /// 表示中の月（月初日を基準にする）
    @State private var displayedMonth: Date = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    /// タップされた日の詳細表示
    @State private var selectedDay: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            // 月ナビゲーション
            monthNavigation

            // 曜日ヘッダー
            weekdayHeader

            // カレンダーグリッド
            calendarGrid

            // 選択日の詳細
            if let selectedDay {
                dayDetailView(for: selectedDay)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .animation(.easeInOut(duration: 0.2), value: selectedDay)
    }

    // MARK: - 月ナビゲーション

    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(colors.accent)
            }

            Spacer()

            Text(displayedMonth, format: .dateTime.year().month(.defaultDigits))
                .font(.system(.headline, design: .rounded))

            Spacer()

            // 未来の月には進めない
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = nextMonth
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(colors.accent)
            }
            .disabled(nextMonth > .now)
            .opacity(nextMonth > .now ? 0.3 : 1)
        }
    }

    // MARK: - 曜日ヘッダー

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - カレンダーグリッド

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                if let day {
                    dayCellView(for: day)
                } else {
                    // 空セル（月初の前のオフセット）
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    /// 日のセル
    @ViewBuilder
    private func dayCellView(for day: Date) -> some View {
        let dayEntries = entriesFor(day: day)
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let avgScore = averageScoreFor(entries: dayEntries)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedDay = nil
                } else {
                    selectedDay = day
                }
            }
        } label: {
            ZStack {
                // 背景色（スコアに基づく）
                if let score = avgScore {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colors.color(for: Int(score.rounded()), maxScore: currentMaxScore, minScore: currentMinScore).opacity(0.7))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.04))
                }

                // 日付テキスト
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(.caption2, design: .rounded, weight: avgScore != nil ? .semibold : .regular))
                    .foregroundStyle(avgScore != nil ? .white : .secondary)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isToday ? colors.accent : (isSelected ? colors.accent.opacity(0.5) : .clear), lineWidth: isToday ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日の詳細

    @ViewBuilder
    private func dayDetailView(for day: Date) -> some View {
        let dayEntries = entriesFor(day: day)

        VStack(spacing: 6) {
            Text(day, format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.wide))
                .font(.system(.caption, design: .rounded, weight: .semibold))

            if dayEntries.isEmpty {
                Text("記録なし")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    // 記録回数
                    Label("\(dayEntries.count)件", systemImage: "pencil.line")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)

                    // 平均スコア
                    if let avg = averageScoreFor(entries: dayEntries) {
                        Label(String(localized: "平均") + String(format: " %.1f", avg), systemImage: "chart.bar.fill")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(colors.accent)
                    }

                    // スコア一覧
                    let scores = dayEntries
                        .sorted { $0.createdAt < $1.createdAt }
                        .map { "\($0.score)" }
                        .joined(separator: " → ")
                    Text(scores)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colors.accent.opacity(0.08))
        )
    }

    // MARK: - ヘルパー

    /// 表示月の日配列を生成（nilはオフセット用の空セル）
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) // 1=日, 2=月...
        let offsetCount = firstWeekday - 1 // 空セル数

        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        var days: [Date?] = Array(repeating: nil, count: offsetCount)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    /// 指定日のエントリをフィルタ
    private func entriesFor(day: Date) -> [MoodEntry] {
        entries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    /// エントリの平均スコア（生スコアの平均）
    private func averageScoreFor(entries: [MoodEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        return entries.reduce(0.0) { $0 + Double($1.score) } / Double(entries.count)
    }
}

#Preview {
    MonthlyHeatmapView(
        entries: [],
        currentMaxScore: 10,
        colors: .ocean
    )
    .padding()
}
