//
//  CalendarHeatmapView.swift
//  Nami
//
//  GitHubの芝生スタイルのカレンダーヒートマップ
//  横軸=週、縦軸=曜日（月〜日）、各セルは角丸の正方形
//

import SwiftUI

/// GitHub芝生スタイルのカレンダーヒートマップ
/// 不規則な記録間隔でも、次の記録まで値が維持されているものとして表現する
struct CalendarHeatmapView: View {
    let entries: [MoodEntry]
    let themeColors: ThemeColors

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10

    /// 表示する週数（直近何週分を表示するか）
    @State private var weekCount: Int = 26
    /// タップされたセルの日付
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    /// 曜日ラベル（月〜日）- ローカライズキーの衝突を避けるため「曜」付き
    private let weekdayLabels = [String(localized: "月曜"), String(localized: "火曜"), String(localized: "水曜"), String(localized: "木曜"), String(localized: "金曜"), String(localized: "土曜"), String(localized: "日曜")]

    // MARK: - データ準備

    /// 日ごとの「有効スコア」を計算（記録がない日は直前の記録の値を維持）
    /// スコアは正規化（0.0〜1.0）→ 現在のレンジにスケーリングして統一表示
    private var dailyScores: [Date: (score: Double, maxScore: Int, hasEntry: Bool, entryCount: Int)] {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [:] }

        // まず実際に記録がある日をセット（正規化スコアで集計）
        var byDay: [Date: (normalizedScores: [Double], count: Int)] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.createdAt)
            var existing = byDay[day] ?? (normalizedScores: [], count: 0)
            existing.normalizedScores.append(entry.normalizedScore)
            existing.count += 1
            byDay[day] = existing
        }

        // 表示範囲の開始日
        let today = calendar.startOfDay(for: .now)
        let totalDays = weekCount * 7
        guard let startDate = calendar.date(byAdding: .day, value: -totalDays + 1, to: today) else {
            return [:]
        }

        var result: [Date: (score: Double, maxScore: Int, hasEntry: Bool, entryCount: Int)] = [:]
        var lastNormalized: Double? = nil

        // 全期間の記録で最初より前のものがあれば、その最後の値を初期値にする
        let entriesBefore = sorted.filter { calendar.startOfDay(for: $0.createdAt) < startDate }
        if let last = entriesBefore.last {
            lastNormalized = last.normalizedScore
        }

        // 開始日から今日までの各日を走査
        var current = startDate
        while current <= today {
            if let dayData = byDay[current] {
                let avgNormalized = dayData.normalizedScores.reduce(0, +) / Double(dayData.normalizedScores.count)
                let scaledScore = avgNormalized * Double(currentMaxScore - 1) + 1.0
                result[current] = (score: scaledScore, maxScore: currentMaxScore, hasEntry: true, entryCount: dayData.count)
                lastNormalized = avgNormalized
            } else if let carry = lastNormalized {
                let scaledScore = carry * Double(currentMaxScore - 1) + 1.0
                result[current] = (score: scaledScore, maxScore: currentMaxScore, hasEntry: false, entryCount: 0)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    /// 表示するグリッドの週配列を生成
    private var weeks: [[Date?]] {
        let today = calendar.startOfDay(for: .now)
        let totalDays = weekCount * 7

        guard let rawStart = calendar.date(byAdding: .day, value: -totalDays + 1, to: today) else {
            return []
        }

        // rawStartを直前の月曜日に揃える
        let rawWeekday = calendar.component(.weekday, from: rawStart)
        let mondayOffset = rawWeekday == 1 ? -6 : -(rawWeekday - 2)
        guard let gridStart = calendar.date(byAdding: .day, value: mondayOffset, to: rawStart) else {
            return []
        }

        var result: [[Date?]] = []
        var weekStart = gridStart

        while weekStart <= today {
            var week: [Date?] = []
            for dayOffset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                    week.append(nil)
                    continue
                }
                week.append(day > today ? nil : day)
            }
            result.append(week)
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = nextWeek
        }
        return result
    }

    /// サマリー統計（記録のある日数、期間内の合計記録数）
    private var summaryStats: (activeDays: Int, totalEntries: Int, averageScore: Double?) {
        let scores = dailyScores
        let activeDays = scores.values.filter { $0.hasEntry }.count
        let totalEntries = scores.values.reduce(0) { $0 + $1.entryCount }
        let entryScores = scores.values.filter { $0.hasEntry }
        let avg: Double? = entryScores.isEmpty ? nil : entryScores.reduce(0.0) { $0 + $1.score } / Double(entryScores.count)
        return (activeDays, totalEntries, avg)
    }

    var body: some View {
        VStack(spacing: 16) {
            // 期間セレクタ
            periodSelector

            // サマリーバー
            summaryBar

            // ヒートマップグリッド
            heatmapGrid

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
        .animation(.easeInOut(duration: 0.3), value: weekCount)
    }

    // MARK: - 期間セレクタ

    private var periodSelector: some View {
        HStack(spacing: 6) {
            ForEach([(13, "3ヶ月"), (26, "半年"), (52, "1年")], id: \.0) { count, label in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        weekCount = count
                        selectedDate = nil
                    }
                    HapticManager.lightFeedback()
                } label: {
                    Text(label)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(weekCount == count ? themeColors.accent : Color(.systemGray5).opacity(0.8))
                        )
                        .foregroundStyle(weekCount == count ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - サマリーバー

    private var summaryBar: some View {
        let stats = summaryStats

        return HStack(spacing: 0) {
            // 記録日数
            summaryItem(
                value: "\(stats.activeDays)",
                label: "日記録",
                icon: "calendar.badge.checkmark"
            )

            miniDivider

            // 記録数
            summaryItem(
                value: "\(stats.totalEntries)",
                label: "件",
                icon: "pencil.line"
            )

            miniDivider

            // 平均スコア
            if let avg = stats.averageScore {
                summaryItem(
                    value: String(format: "%.1f", avg),
                    label: "平均",
                    icon: "chart.bar.fill"
                )
            } else {
                summaryItem(
                    value: "-",
                    label: "平均",
                    icon: "chart.bar.fill"
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }

    private func summaryItem(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(themeColors.accent.opacity(0.7))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.3))
            .frame(width: 1, height: 28)
    }

    // MARK: - 凡例

    private var legend: some View {
        HStack(spacing: 5) {
            // 低→高のグラデーション凡例
            Text("1")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            ForEach(1...5, id: \.self) { level in
                let score = Int(Double(level) / 5.0 * Double(currentMaxScore - 1)) + 1
                RoundedRectangle(cornerRadius: 3)
                    .fill(themeColors.color(for: score, maxScore: currentMaxScore))
                    .frame(width: 12, height: 12)
            }

            Text("\(currentMaxScore)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer()

            // 維持セル凡例
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeColors.accent.opacity(0.2))
                    .frame(width: 10, height: 10)
                Text("維持")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // 記録なしセル凡例
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5).opacity(0.3))
                    .frame(width: 10, height: 10)
                Text("なし")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - ヒートマップグリッド

    private var heatmapGrid: some View {
        let scores = dailyScores

        return ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { scrollProxy in
                HStack(alignment: .top, spacing: 0) {
                    // 曜日ラベル列
                    VStack(spacing: cellSpacing) {
                        // 月ヘッダーの高さ分の空白
                        Color.clear.frame(width: 20, height: 14)

                        ForEach(0..<7, id: \.self) { row in
                            if row % 2 == 0 {
                                Text(weekdayLabels[row])
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, height: cellSize)
                            } else {
                                Color.clear.frame(width: 20, height: cellSize)
                            }
                        }
                    }

                    // 週グリッド
                    HStack(spacing: cellSpacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { weekIdx, week in
                            VStack(spacing: cellSpacing) {
                                monthLabel(for: week)

                                ForEach(0..<7, id: \.self) { row in
                                    if let date = week[row] {
                                        cellView(for: date, scores: scores)
                                    } else {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.clear)
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                            .id(weekIdx)
                        }
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    if let lastIdx = weeks.indices.last {
                        scrollProxy.scrollTo(lastIdx, anchor: .trailing)
                    }
                }
                .onChange(of: weekCount) { _, _ in
                    // 期間変更時も右端にスクロール
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let lastIdx = weeks.indices.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scrollProxy.scrollTo(lastIdx, anchor: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 月ラベル（週の最初の日が1-7日なら月名を表示）
    @ViewBuilder
    private func monthLabel(for week: [Date?]) -> some View {
        if let firstDay = week.compactMap({ $0 }).first {
            let day = calendar.component(.day, from: firstDay)
            if day <= 7 {
                Text(firstDay, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeColors.accent.opacity(0.7))
                    .frame(height: 14)
            } else {
                Color.clear.frame(height: 14)
            }
        } else {
            Color.clear.frame(height: 14)
        }
    }

    /// 個別セル
    @ViewBuilder
    private func cellView(for date: Date, scores: [Date: (score: Double, maxScore: Int, hasEntry: Bool, entryCount: Int)]) -> some View {
        let day = calendar.startOfDay(for: date)
        let data = scores[day]
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedDate = nil
                } else {
                    selectedDate = date
                }
            }
            HapticManager.lightFeedback()
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(cellColor(data: data))
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    Group {
                        if isToday {
                            // 今日は二重ボーダー（目立つ表示）
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(themeColors.accent, lineWidth: 2)
                        } else if isSelected {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(themeColors.accent.opacity(0.7), lineWidth: 1.5)
                        }
                    }
                )
                .scaleEffect(isSelected ? 1.3 : 1.0)
                .zIndex(isSelected ? 1 : 0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    /// セルの色
    private func cellColor(data: (score: Double, maxScore: Int, hasEntry: Bool, entryCount: Int)?) -> Color {
        guard let data else {
            return Color(.systemGray5).opacity(0.3)
        }
        let score = max(1, Int(data.score.rounded()))
        let color = themeColors.color(for: score, maxScore: data.maxScore)
        return data.hasEntry ? color : color.opacity(0.35)
    }

    // MARK: - 選択された日の詳細

    @ViewBuilder
    private func selectedDayDetail(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let data = dailyScores[day]
        let dayEntries = entries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }

        VStack(spacing: 10) {
            // ヘッダー
            HStack {
                HStack(spacing: 6) {
                    // 日付カラーインジケータ
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
                    // スコア表示
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", data.score))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColors.color(for: Int(data.score.rounded()), maxScore: currentMaxScore))

                        if data.hasEntry {
                            Text("\(data.entryCount)件の記録")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 8))
                                Text("前回の値を維持")
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .foregroundStyle(.tertiary)
                        }
                    }

                    // 記録のメモとタグ
                    if !dayEntries.isEmpty {
                        Divider().frame(height: 50)

                        VStack(alignment: .leading, spacing: 6) {
                            // メモ表示
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

                            // タグ表示
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

                // 複数記録がある日のスコア推移
                if dayEntries.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(dayEntries, id: \.id) { entry in
                            HStack(spacing: 2) {
                                Text("\(entry.score)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(themeColors.color(for: entry.score, maxScore: entry.maxScore))

                                Text(entry.createdAt, format: .dateTime.hour().minute())
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeColors.color(for: entry.score, maxScore: entry.maxScore).opacity(0.08))
                            )

                            if entry.id != dayEntries.last?.id {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("この日は記録がありません")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }
}

#Preview {
    let sampleEntries = [0, 1, 3, 5, 8, 12, 15, 20, 25, 30].map { i in
        MoodEntry(
            score: Int.random(in: 2...9),
            memo: i % 5 == 0 ? "テスト" : nil,
            tags: i % 3 == 0 ? ["嬉しい", "仕事"] : [],
            createdAt: Calendar.current.date(byAdding: .day, value: -i, to: .now)!
        )
    }
    return CalendarHeatmapView(
        entries: sampleEntries,
        themeColors: .ocean
    )
    .padding()
}
