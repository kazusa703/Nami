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
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1

    /// 表示中の年
    @State private var displayYear: Int = Calendar.current.component(.year, from: .now)
    /// タップされたセルの日付
    @State private var selectedDate: Date?
    /// キャッシュされた日ごとのスコアデータ（entries/displayYear変更時のみ再計算）
    @State private var cachedDailyScores: [Date: (score: Double, hasEntry: Bool, entryCount: Int, memo: String?)] = [:]
    /// キャッシュ生成に使ったentriesのcount（変更検知用）
    @State private var lastEntriesCount: Int = -1

    private let calendar = Calendar.current

    /// 月ラベル（ロケール対応）
    private var monthLabels: [String] {
        Calendar.current.shortMonthSymbols
    }

    /// 日付ヘッダーに表示する日（混雑回避のため一部だけ）
    private let headerDays = [1, 5, 10, 15, 20, 25, 30]

    // MARK: - データ準備

    /// cachedDailyScoresキャッシュを再計算する
    private func rebuildDailyScores() {
        let cal = calendar
        let year = displayYear

        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else {
            cachedDailyScores = [:]
            lastEntriesCount = entries.count
            return
        }

        var result: [Date: (score: Double, hasEntry: Bool, entryCount: Int, memo: String?)] = [:]

        let yearEntries = sorted.filter {
            cal.component(.year, from: $0.createdAt) == year
        }

        var dayGroups: [Date: [MoodEntry]] = [:]
        for entry in yearEntries {
            let day = cal.startOfDay(for: entry.createdAt)
            dayGroups[day, default: []].append(entry)
        }

        for (day, group) in dayGroups {
            // UI崩れ・ズレ防止: 他のグラフと統一し、純粋なスコアの平均値を計算
            let avgScore = group.reduce(0.0) { $0 + Double($1.score) } / Double(group.count)
            let memos = group.compactMap(\.memo).filter { !$0.isEmpty }
            result[day] = (score: avgScore, hasEntry: true, entryCount: group.count, memo: memos.first)
        }

        cachedDailyScores = result
        lastEntriesCount = entries.count
    }

    /// サマリー統計
    private var summaryStats: (recordedDays: Int, totalDays: Int, averageScore: Double?) {
        let scores = cachedDailyScores
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
        .onAppear { rebuildDailyScores() }
        .onChange(of: displayYear) { _, _ in rebuildDailyScores() }
        .onChange(of: entries.count) { _, _ in rebuildDailyScores() }
        .onChange(of: currentMaxScore) { _, _ in rebuildDailyScores() } // 範囲変更時も再計算
        .onChange(of: currentMinScore) { _, _ in rebuildDailyScores() }
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
            let monthLabelWidth: CGFloat = 30
            let horizontalPadding: CGFloat = 32
            let gap: CGFloat = 2
            let availableWidth = geometry.size.width - monthLabelWidth - horizontalPadding
            let cellSize = max(6, floor((availableWidth - gap * 30) / 31))

            VStack(alignment: .leading, spacing: 0) {
                // 日付ヘッダー行
                HStack(spacing: gap) {
                    Color.clear.frame(width: monthLabelWidth, height: 12)
                    ForEach(1...31, id: \.self) { day in
                        if headerDays.contains(day) {
                            Text("\(day)")
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: cellSize, height: 12)
                        } else {
                            Color.clear.frame(width: cellSize, height: 12)
                        }
                    }
                }

                // 月行
                ForEach(1...12, id: \.self) { month in
                    HStack(spacing: gap) {
                        // 月ラベル
                        Text(monthLabels[month - 1])
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeColors.accent.opacity(0.7))
                            .frame(width: monthLabelWidth, alignment: .leading)

                        // 日セル
                        let days = daysInMonth(month)
                        ForEach(1...31, id: \.self) { day in
                            if day <= days {
                                let date = calendar.date(from: DateComponents(year: displayYear, month: month, day: day))
                                cellView(for: date, cellSize: cellSize)
                            } else {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                    .padding(.bottom, gap)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 220)
    }

    /// 個別セル
    @ViewBuilder
    private func cellView(for date: Date?, cellSize: CGFloat) -> some View {
        if let date {
            let day = calendar.startOfDay(for: date)
            let data = cachedDailyScores[day]
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
                Rectangle()
                    .fill(cellColor(data: data, isFuture: isFuture))
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        Group {
                            if isToday {
                                Rectangle()
                                    .stroke(themeColors.accent, lineWidth: 1.5)
                            } else if isSelected {
                                Rectangle()
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

    /// セルの色（クランプ付きで安全に取得）
    private func cellColor(data: (score: Double, hasEntry: Bool, entryCount: Int, memo: String?)?, isFuture: Bool) -> Color {
        if isFuture {
            return Color.clear
        }
        guard let data, data.hasEntry else {
            return Color(.systemGray5).opacity(0.3)
        }
        // UI崩れ防止: スコアが範囲外になってもクラッシュしないよう丸めてクランプする
        let safeScore = min(currentMaxScore, max(currentMinScore, Int(data.score.rounded())))
        return themeColors.color(for: safeScore, minScore: currentMinScore, maxScore: currentMaxScore)
    }

    // MARK: - 凡例（動的調整・UI崩れ防止対応）

    private var legend: some View {
        HStack(spacing: 4) {
            Text("\(currentMinScore)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.5) // 文字数が増えても縮小して収める
                .frame(minWidth: 16, alignment: .trailing)

            // スコア範囲に応じて表示するブロック数を調整（最大5個）
            let blockCount = min(5, max(1, currentMaxScore - currentMinScore + 1))
            ForEach(0..<blockCount, id: \.self) { index in
                let fraction = blockCount > 1 ? Double(index) / Double(blockCount - 1) : 0.5
                let score = Int(round(fraction * Double(currentMaxScore - currentMinScore))) + currentMinScore
                
                Rectangle()
                    .fill(themeColors.color(for: score, minScore: currentMinScore, maxScore: currentMaxScore))
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            Text("\(currentMaxScore)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(minWidth: 16, alignment: .leading)

            Spacer(minLength: 4)

            HStack(spacing: 3) {
                Rectangle()
                    .fill(Color(.systemGray5).opacity(0.3))
                    .frame(width: 10, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text("記録なし")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .layoutPriority(1) // 最優先で表示領域を確保
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 選択された日の詳細

    @ViewBuilder
    private func selectedDayDetail(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let data = cachedDailyScores[day]
        let dayEntries = entries
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }

        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    if let data {
                        // 安全な色取得
                        let safeScore = min(currentMaxScore, max(currentMinScore, Int(data.score.rounded())))
                        Circle()
                            .fill(themeColors.color(for: safeScore, minScore: currentMinScore, maxScore: currentMaxScore))
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
                let safeScore = min(currentMaxScore, max(currentMinScore, Int(data.score.rounded())))
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", data.score))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColors.color(for: safeScore, minScore: currentMinScore, maxScore: currentMaxScore))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5) // 文字数増大に対応

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
        themeColors: .ocean // 仮のテーマカラー
    )
    .padding()
}
