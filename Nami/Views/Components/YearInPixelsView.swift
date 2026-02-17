//
//  YearInPixelsView.swift
//  Nami
//
//  365日グリッドビュー（Year in Pixels）
//  12行（月）× 最大31列（日）のカラーグリッドで1年分の気分を表示する
//

import SwiftUI

/// Year in Pixels - 1年分の気分記録を月×日のグリッドで表示
struct YearInPixelsView: View {
    let entries: [MoodEntry]
    let themeColors: ThemeColors

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10

    /// 表示中の年
    @State private var displayYear: Int = Calendar.current.component(.year, from: .now)
    /// タップされたセルの日付
    @State private var selectedDate: Date?

    private let calendar = Calendar.current

    /// 月ラベル
    private let monthLabels = ["1月", "2月", "3月", "4月", "5月", "6月",
                                "7月", "8月", "9月", "10月", "11月", "12月"]

    /// 日付ヘッダーに表示する日（混雑回避のため一部だけ）
    private let headerDays = [1, 5, 10, 15, 20, 25, 30]

    // MARK: - データ準備

    /// 表示年の日ごとのスコアデータ
    private var dailyScores: [Date: (score: Double, hasEntry: Bool, entryCount: Int, memo: String?)] {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [:] }

        var result: [Date: (score: Double, hasEntry: Bool, entryCount: Int, memo: String?)] = [:]

        // 表示年のエントリのみフィルタ
        let yearEntries = sorted.filter {
            calendar.component(.year, from: $0.createdAt) == displayYear
        }

        // 日別に集計
        var dayGroups: [Date: [MoodEntry]] = [:]
        for entry in yearEntries {
            let day = calendar.startOfDay(for: entry.createdAt)
            dayGroups[day, default: []].append(entry)
        }

        for (day, group) in dayGroups {
            let avgNorm = group.reduce(0.0) { $0 + $1.normalizedScore } / Double(group.count)
            let scaled = avgNorm * Double(currentMaxScore - 1) + 1.0
            let memos = group.compactMap(\.memo).filter { !$0.isEmpty }
            result[day] = (score: scaled, hasEntry: true, entryCount: group.count, memo: memos.first)
        }

        return result
    }

    /// サマリー統計
    private var summaryStats: (recordedDays: Int, totalDays: Int, averageScore: Double?) {
        let scores = dailyScores
        let recordedDays = scores.values.filter { $0.hasEntry }.count

        // 表示年の合計日数
        let currentYear = Calendar.current.component(.year, from: .now)
        let totalDays: Int
        if displayYear == currentYear {
            totalDays = calendar.ordinality(of: .day, in: .year, for: .now) ?? 365
        } else {
            let isLeap = (displayYear % 4 == 0 && displayYear % 100 != 0) || displayYear % 400 == 0
            totalDays = isLeap ? 366 : 365
        }

        let entryScores = scores.values.filter { $0.hasEntry }
        let avg: Double? = entryScores.isEmpty ? nil : entryScores.reduce(0.0) { $0 + $1.score } / Double(entryScores.count)

        return (recordedDays, totalDays, avg)
    }

    /// 指定月の日数
    private func daysInMonth(_ month: Int) -> Int {
        guard let date = calendar.date(from: DateComponents(year: displayYear, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date)
        else { return 30 }
        return range.count
    }

    var body: some View {
        VStack(spacing: 12) {
            // 年セレクター
            yearSelector

            // サマリーバー
            summaryBar

            // グリッド
            pixelGrid

            // 凡例
            legend

            // 選択された日の詳細
            if let date = selectedDate {
                selectedDayDetail(for: date)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.3), value: selectedDate)
        .animation(.easeInOut(duration: 0.3), value: displayYear)
    }

    // MARK: - 年セレクター

    private var yearSelector: some View {
        HStack(spacing: 20) {
            Button {
                displayYear -= 1
                selectedDate = nil
                HapticManager.lightFeedback()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(themeColors.accent)
            }

            Text(String(displayYear))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()

            Button {
                let currentYear = calendar.component(.year, from: .now)
                guard displayYear < currentYear else { return }
                displayYear += 1
                selectedDate = nil
                HapticManager.lightFeedback()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(
                        displayYear < calendar.component(.year, from: .now)
                            ? themeColors.accent
                            : Color.gray.opacity(0.3)
                    )
            }
            .disabled(displayYear >= calendar.component(.year, from: .now))
        }
    }

    // MARK: - サマリーバー

    private var summaryBar: some View {
        let stats = summaryStats

        return HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 11))
                    .foregroundStyle(themeColors.accent.opacity(0.7))
                Text("\(stats.recordedDays)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("/ \(stats.totalDays)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("記録した日")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let avg = stats.averageScore {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(themeColors.accent.opacity(0.7))
                    Text(String(format: "%.1f", avg))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text("平均")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }

    // MARK: - ピクセルグリッド

    private var pixelGrid: some View {
        GeometryReader { geometry in
            let monthLabelWidth: CGFloat = 32
            let horizontalPadding: CGFloat = 32
            let daySpacing: CGFloat = 1.5
            let availableWidth = geometry.size.width - monthLabelWidth - horizontalPadding
            let cellSize = max(6, (availableWidth - daySpacing * 30) / 31)
            let rowHeight = cellSize + daySpacing

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 日付ヘッダー行
                    HStack(spacing: 0) {
                        Color.clear.frame(width: monthLabelWidth, height: 14)
                        ForEach(1...31, id: \.self) { day in
                            if headerDays.contains(day) {
                                Text("\(day)")
                                    .font(.system(size: 7, weight: .medium, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: cellSize + daySpacing, height: 14)
                            } else {
                                Color.clear.frame(width: cellSize + daySpacing, height: 14)
                            }
                        }
                    }

                    // 月行
                    ForEach(1...12, id: \.self) { month in
                        HStack(spacing: 0) {
                            // 月ラベル
                            Text(monthLabels[month - 1])
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(themeColors.accent.opacity(0.7))
                                .frame(width: monthLabelWidth, height: rowHeight, alignment: .leading)

                            // 日セル
                            let days = daysInMonth(month)
                            ForEach(1...31, id: \.self) { day in
                                if day <= days {
                                    let date = calendar.date(from: DateComponents(year: displayYear, month: month, day: day))
                                    cellView(for: date, cellSize: cellSize)
                                        .padding(.trailing, daySpacing)
                                        .padding(.bottom, daySpacing)
                                } else {
                                    Color.clear
                                        .frame(width: cellSize + daySpacing, height: cellSize)
                                        .padding(.bottom, daySpacing)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(height: 260)
    }

    /// 個別セル
    @ViewBuilder
    private func cellView(for date: Date?, cellSize: CGFloat) -> some View {
        if let date {
            let day = calendar.startOfDay(for: date)
            let data = dailyScores[day]
            let isFuture = date > Date.now
            let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            let isToday = calendar.isDateInToday(date)

            Button {
                guard !isFuture else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isSelected {
                        selectedDate = nil
                    } else {
                        selectedDate = date
                    }
                }
                HapticManager.lightFeedback()
            } label: {
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(data: data, isFuture: isFuture))
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        Group {
                            if isToday {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(themeColors.accent, lineWidth: 1.5)
                            } else if isSelected {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(themeColors.accent.opacity(0.7), lineWidth: 1)
                            }
                        }
                    )
                    .scaleEffect(isSelected ? 1.4 : 1.0)
                    .zIndex(isSelected ? 1 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
        }
    }

    /// セルの色
    private func cellColor(data: (score: Double, hasEntry: Bool, entryCount: Int, memo: String?)?, isFuture: Bool) -> Color {
        if isFuture {
            return Color.clear
        }
        guard let data, data.hasEntry else {
            return Color(.systemGray5).opacity(0.3)
        }
        let score = max(1, Int(data.score.rounded()))
        return themeColors.color(for: score, maxScore: currentMaxScore)
    }

    // MARK: - 凡例

    private var legend: some View {
        HStack(spacing: 5) {
            Text("1")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            ForEach(1...5, id: \.self) { level in
                let score = Int(Double(level) / 5.0 * Double(currentMaxScore - 1)) + 1
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeColors.color(for: score, maxScore: currentMaxScore))
                    .frame(width: 12, height: 12)
            }

            Text("\(currentMaxScore)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer()

            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5).opacity(0.3))
                    .frame(width: 10, height: 10)
                Text("記録なし")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 選択された日の詳細

    @ViewBuilder
    private func selectedDayDetail(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let data = dailyScores[day]
        let dayEntries = entries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }

        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    if let data {
                        Circle()
                            .fill(themeColors.color(for: Int(data.score.rounded()), maxScore: currentMaxScore))
                            .frame(width: 8, height: 8)
                    }

                    Text(date, format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.wide))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                Spacer()

                if calendar.isDateInToday(date) {
                    Text("今日")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(themeColors.accent.opacity(0.15)))
                        .foregroundStyle(themeColors.accent)
                }

                Button {
                    withAnimation { selectedDate = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
            }

            if let data {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", data.score))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColors.color(for: Int(data.score.rounded()), maxScore: currentMaxScore))

                        Text("\(data.entryCount)件の記録")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if !dayEntries.isEmpty {
                        Divider().frame(height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            let memos = dayEntries.compactMap(\.memo).filter { !$0.isEmpty }
                            ForEach(memos.prefix(2), id: \.self) { memo in
                                HStack(spacing: 4) {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                    Text(memo)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            let allTags = Array(Set(dayEntries.flatMap(\.tags)))
                            if !allTags.isEmpty {
                                HStack(spacing: 3) {
                                    ForEach(allTags.prefix(4), id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(themeColors.accent.opacity(0.1)))
                                            .foregroundStyle(themeColors.accent)
                                    }
                                    if allTags.count > 4 {
                                        Text("+\(allTags.count - 4)")
                                            .font(.system(size: 9, design: .rounded))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("記録なし")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }
}

#Preview {
    let sampleEntries = (0..<60).map { i in
        MoodEntry(
            score: Int.random(in: 2...9),
            memo: i % 5 == 0 ? "テスト" : nil,
            tags: i % 3 == 0 ? ["嬉しい", "仕事"] : [],
            createdAt: Calendar.current.date(byAdding: .day, value: -i, to: .now)!
        )
    }
    return YearInPixelsView(
        entries: sampleEntries,
        themeColors: .ocean
    )
    .padding()
}
