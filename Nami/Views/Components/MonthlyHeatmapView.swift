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
    let currentMinScore: Int
    let colors: ThemeColors

    /// 表示中の月（月初日を基準にする）
    @State private var displayedMonth: Date = {
        Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    }()
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
        let hasMultiple = dayEntries.count >= 2

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
                // Background color based on score
                if hasMultiple, let morningColor = periodColor(entries: dayEntries, isMorning: true),
                   let eveningColor = periodColor(entries: dayEntries, isMorning: false) {
                    // Split circle: top = morning avg, bottom = evening avg
                    VStack(spacing: 0) {
                        morningColor.opacity(0.7)
                        eveningColor.opacity(0.7)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let score = avgScore {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colors.color(for: Int(score.rounded()), minScore: currentMinScore, maxScore: currentMaxScore).opacity(0.7))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.04))
                }

                // Day number text
                VStack(spacing: 0) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(.caption2, design: .rounded, weight: avgScore != nil ? .semibold : .regular))
                        .foregroundStyle(avgScore != nil ? .white : .secondary)

                    // Multi-record dot indicator
                    if hasMultiple {
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 3, height: 3)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isToday ? colors.accent : (isSelected ? colors.accent.opacity(0.5) : .clear), lineWidth: isToday ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Returns color for morning (before 14:00) or evening (14:00+) entries.
    /// Returns nil if no entries exist in that period, indicating single-color fallback.
    private func periodColor(entries: [MoodEntry], isMorning: Bool) -> Color? {
        let periodEntries = entries.filter { entry in
            let hour = calendar.component(.hour, from: entry.createdAt)
            return isMorning ? hour < 14 : hour >= 14
        }
        guard !periodEntries.isEmpty else { return nil }
        let avg = periodEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(periodEntries.count)
        let scaled = avg * Double(currentMaxScore - currentMinScore) + Double(currentMinScore)
        return colors.color(for: Int(scaled.rounded()), minScore: currentMinScore, maxScore: currentMaxScore)
    }

    // MARK: - 日の詳細

    @ViewBuilder
    private func dayDetailView(for day: Date) -> some View {
        let dayEntries = entriesFor(day: day).sorted { $0.createdAt < $1.createdAt }

        VStack(spacing: 6) {
            Text(day, format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.wide))
                .font(.system(.caption, design: .rounded, weight: .semibold))

            if dayEntries.isEmpty {
                Text("記録なし")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    // Entry count
                    Label("\(dayEntries.count)件", systemImage: "pencil.line")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)

                    // Average score
                    if let avg = averageScoreFor(entries: dayEntries) {
                        Label(String(localized: "平均") + String(format: " %.1f", avg), systemImage: "chart.bar.fill")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(colors.accent)
                    }
                }

                // Per-entry details
                VStack(spacing: 4) {
                    ForEach(dayEntries, id: \.id) { entry in
                        entryDetailRow(entry)
                    }
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

    /// Single entry row in day detail
    @ViewBuilder
    private func entryDetailRow(_ entry: MoodEntry) -> some View {
        HStack(spacing: 6) {
            // Score with color
            Text("\(entry.score)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(
                    colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore)
                )
                .frame(width: 24)

            // Time
            Text(entry.createdAt, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            // Energy level icon
            if let energy = entry.energyLevel {
                Image(systemName: energyIcon(for: energy))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            // Weather icon
            if let weather = entry.weatherCondition {
                Image(systemName: weatherIcon(for: weather))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            // Tags
            if !entry.tags.isEmpty {
                Text(entry.tags.prefix(2).joined(separator: " "))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(colors.accent.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Mini memo preview (first 20 chars)
            if let memo = entry.memo, !memo.isEmpty {
                Text(String(memo.prefix(20)))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    /// Icon for energy level
    private func energyIcon(for level: Int) -> String {
        switch level {
        case 1: return "battery.25"
        case 2: return "battery.50"
        case 3: return "battery.100"
        default: return "battery.50"
        }
    }

    /// Icon for weather condition
    private func weatherIcon(for condition: String) -> String {
        switch condition {
        case "sunny": return "sun.max.fill"
        case "cloudy": return "cloud.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "stormy": return "cloud.bolt.fill"
        case "foggy": return "cloud.fog.fill"
        default: return "questionmark"
        }
    }

    // MARK: - ヘルパー

    /// 表示月の日配列を生成（nilはオフセット用の空セル）
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) // 1=日, 2=月...
        // ロケールに基づく週の開始曜日を考慮（日本: 日曜=1, 米国: 日曜=1, ISO: 月曜=2）
        let offsetCount = (firstWeekday - calendar.firstWeekday + 7) % 7

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

    /// エントリの平均スコア（現在のレンジにスケール）
    private func averageScoreFor(entries: [MoodEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        let avg = entries.reduce(0.0) { $0 + $1.normalizedScore } / Double(entries.count)
        return avg * Double(currentMaxScore - currentMinScore) + Double(currentMinScore)
    }
}

#Preview {
    MonthlyHeatmapView(
        entries: [],
        currentMaxScore: 10,
        currentMinScore: 1,
        colors: .ocean
    )
    .padding()
}
