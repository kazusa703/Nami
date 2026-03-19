//
//  GraphView.swift
//  Nami
//
//  Created by Claude on 2024/05/22.
//  Based on user requests and design standards.
//
//  修正履歴:
//  - Fix 1:  overviewChart タップ時に range 外の日付を除外
//  - Fix 2:  FullscreenChartView の minZoom/maxZoom を明示的に Double 型に統一
//  - Fix 3:  findAndShowClosestEntry の許容距離を dateMode に応じて動的に変更
//  - Fix 4:  dayLevelChart の graphMode 判定を switch に変更
//  - Fix 5:  buildPlotDays のコメントを整理（segmentId ロジックの意図を明示）
//  - Fix 6:  periodRange の週計算を ISO8601（月曜始まり保証）に変更
//  - Fix 7:  formattedTargetDate の週表示で年またぎ時に年付きフォーマットに切り替え
//  - Fix 8:  overviewChart の segmentCount 計算を O(n²) → O(1) に改善
//  - Fix 9:  daily / plotDays の計算を body 先頭でキャッシュ
//  - Fix 10: dateMode / targetDate 変更時に selectedDay をリセット
//  - Fix 11: dayEntryRow と entryDetailCard の selectedEntry/showDetail 設定を統一
//  - Fix 12: MonthYearPicker / YearPicker の currentYear 二重計算を解消

import SwiftUI
import SwiftData
import Charts

// MARK: - Enums & Constants

enum GraphMode: String, CaseIterable {
    case line = "折れ線"
    case bar = "棒グラフ"
    case heatmap = "ピクセル"

    var iconName: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .bar: return "chart.bar.fill"
        case .heatmap: return "square.grid.3x3.fill"
        }
    }
}

enum DateSelectionMode: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "週"
    case month = "月"
    case year = "年"
    var id: String { rawValue }
}

// MARK: - Helper Functions (Date & Data Processing)

/// 選択された単位と日付から、フルレンジ（開始日時〜終了日時）を計算する
func periodRange(mode: DateSelectionMode, targetDate: Date) -> (start: Date, end: Date) {
    // Fix 6: ISO8601 カレンダーを使用して月曜始まりを保証する
    var isoCal = Calendar(identifier: .iso8601)
    isoCal.locale = Locale(identifier: "ja_JP")

    let cal = Calendar.current
    let startOfDay = cal.startOfDay(for: targetDate)

    switch mode {
    case .day:
        let end = cal.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        return (startOfDay, end)
    case .week:
        // Fix 6: ISO8601 カレンダーを使用して月曜始まりを保証
        let startOfWeek = isoCal.date(from: isoCal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)) ?? startOfDay
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)!.addingTimeInterval(-1)
        return (startOfWeek, endOfWeek)
    case .month:
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: startOfDay)) ?? startOfDay
        let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!.addingTimeInterval(-1)
        return (startOfMonth, endOfMonth)
    case .year:
        let startOfYear = cal.date(from: cal.dateComponents([.year], from: startOfDay)) ?? startOfDay
        let endOfYear = cal.date(byAdding: .year, value: 1, to: startOfYear)!.addingTimeInterval(-1)
        return (startOfYear, endOfYear)
    }
}

/// 期間内のエントリをフィルタ
func filteredEntries(entries: [MoodEntry], mode: DateSelectionMode, targetDate: Date) -> [MoodEntry] {
    let range = periodRange(mode: mode, targetDate: targetDate)
    return entries
        .filter { $0.createdAt >= range.start && $0.createdAt <= range.end }
        .sorted { $0.createdAt < $1.createdAt }
}

/// 日別集約データ
struct DailyData: Identifiable {
    let date: Date
    let entries: [MoodEntry]
    var id: Date { date }

    var average: Double? {
        guard !entries.isEmpty else { return nil }
        return entries.map { Double($0.score) }.reduce(0, +) / Double(entries.count)
    }
    var minScore: Int? { entries.map(\.score).min() }
    var maxScore: Int? { entries.map(\.score).max() }
    var count: Int { entries.count }
}

/// プロット用の日データ（描画に使いやすい形に変換）
struct PlotDay: Identifiable {
    let date: Date
    let average: Double
    let minScore: Int
    let maxScore: Int
    let count: Int
    /// 連続したデータ区間を識別するID。空白日をまたぐと値が増える。
    let segmentId: Int
    var id: Date { date }
}

/// DailyDataからPlotDay配列を生成（途切れ区間ID付き）
func buildPlotDays(from daily: [DailyData]) -> [PlotDay] {
    var result: [PlotDay] = []
    // Fix 5: segmentId は「データがない日の後に初めてデータが来たとき」にインクリメントする。
    //        初期値0のまま最初のデータ点で1になるため、segmentId==0 のデータは存在しない（意図通り）。
    var segmentId = 0
    var lastHadData = false
    for day in daily {
        if let avg = day.average {
            if !lastHadData {
                segmentId += 1
            }
            let minVal = day.minScore ?? Int(avg.rounded())
            let maxVal = day.maxScore ?? Int(avg.rounded())
            result.append(PlotDay(
                date: day.date,
                average: avg,
                minScore: minVal,
                maxScore: maxVal,
                count: day.count,
                segmentId: segmentId
            ))
            lastHadData = true
        } else {
            lastHadData = false
        }
    }
    return result
}

/// 指定された期間の全ての日付を含むDailyDataの配列を生成する
func buildDailyData(entries: [MoodEntry], mode: DateSelectionMode, targetDate: Date) -> [DailyData] {
    let cal = Calendar.current
    let range = periodRange(mode: mode, targetDate: targetDate)
    let filtered = filteredEntries(entries: entries, mode: mode, targetDate: targetDate)

    var allDays: [Date] = []
    var current = cal.startOfDay(for: range.start)
    let endDayStart = cal.startOfDay(for: range.end)

    while current <= endDayStart {
        allDays.append(current)
        current = cal.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
    }

    let grouped = Dictionary(grouping: filtered) { entry in
        cal.startOfDay(for: entry.createdAt)
    }

    return allDays.map { day in
        DailyData(date: day, entries: grouped[day] ?? [])
    }
}

// MARK: - Helper Functions (Chart Appearance)

/// Y軸の表示範囲（ドメイン）を計算する。
/// - 下限: min から少し余白を引く（棒グラフの底部が X 軸ラベルに被らないよう最低 0.5 は確保）
/// - 上限: max に少し余白を足す
func yAxisDomain(min: Int, max: Int) -> ClosedRange<Double> {
    let range = Double(max - min)
    let padding = Swift.max(range * 0.12, 0.8)
    let rawLower = Double(min) - padding
    // min >= 0 のとき下限をスコア範囲の5%分だけマイナス側にする
    // → 棒グラフの底辺がX軸ラベルから浮く。範囲が大きくなっても比例して隙間が確保される。
    let gap = Swift.max(Double(max - min) * 0.05, 0.5)
    let lower: Double = min >= 0 ? -gap : rawLower
    let upper = Double(max) + padding
    return lower...upper
}

/// Y軸の目盛り値を動的に生成する。
/// - step の倍数のみを返す（min/max を無条件追加しないことで密集ラベルを防ぐ）
/// - 負あり範囲では必ず 0 を含める
func smartYAxisValues(min: Int, max: Int) -> [Int] {
    let range = max - min
    guard range > 0 else { return [min, max] }

    let step: Int
    switch range {
    case 0...10:   step = 2
    case 11...20:  step = 5
    case 21...50:  step = 10
    case 51...100: step = 25
    default:       step = 50
    }

    var values: [Int] = []
    // min 以上の最初の step 倍数から開始
    var v = Int(ceil(Double(min) / Double(step))) * step
    while v <= max {
        values.append(v)
        v += step
    }
    // 負あり範囲は 0 を必ず含める
    if min < 0 && max > 0 && !values.contains(0) {
        values.append(0)
        values.sort()
    }
    return values
}

// MARK: - Date Picker Components

struct MonthYearPicker: View {
    @Binding var date: Date
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    private let cal = Calendar.current

    init(date: Binding<Date>) {
        self._date = date
        self._selectedYear = State(initialValue: cal.component(.year, from: date.wrappedValue))
        self._selectedMonth = State(initialValue: cal.component(.month, from: date.wrappedValue))
    }

    var body: some View {
        // Fix 12: currentYear を一度だけ計算してから使用
        let currentYear = cal.component(.year, from: Date())
        HStack {
            Picker("年", selection: $selectedYear) {
                ForEach((currentYear - 10)...(currentYear + 5), id: \.self) { year in
                    Text("\(String(format: "%d", year))年").tag(year)
                }
            }.pickerStyle(.wheel)

            Picker("月", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text("\(month)月").tag(month)
                }
            }.pickerStyle(.wheel)
        }
        .onChange(of: selectedYear) { _, _ in updateDate() }
        .onChange(of: selectedMonth) { _, _ in updateDate() }
    }

    private func updateDate() {
        if let newDate = cal.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
            date = newDate
        }
    }
}

struct YearPicker: View {
    @Binding var date: Date
    @State private var selectedYear: Int
    private let cal = Calendar.current

    init(date: Binding<Date>) {
        self._date = date
        self._selectedYear = State(initialValue: cal.component(.year, from: date.wrappedValue))
    }

    var body: some View {
        // Fix 12: currentYear を一度だけ計算
        let currentYear = cal.component(.year, from: Date())
        Picker("年", selection: $selectedYear) {
            ForEach((currentYear - 10)...(currentYear + 5), id: \.self) { year in
                Text("\(String(format: "%d", year))年").tag(year)
            }
        }
        .pickerStyle(.wheel)
        .onChange(of: selectedYear) { _, year in
            if let newDate = cal.date(from: DateComponents(year: year, month: 1, day: 1)) {
                date = newDate
            }
        }
    }
}

// MARK: - Week Calendar Picker

/// 週単位でハイライトするカレンダーピッカー
/// 選択した日を含む月曜〜日曜の1週間を丸角バーで強調表示する
struct WeekCalendarPicker: View {
    @Binding var date: Date

    @State private var displayMonth: Date
    private let cal: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.locale = Locale(identifier: "ja_JP")
        return c
    }()

    init(date: Binding<Date>) {
        self._date = date
        self._displayMonth = State(initialValue: date.wrappedValue)
    }

    // 表示月の1日
    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
    }

    // 表示月のカレンダーグリッド（6週分、42セル）
    private var weeks: [[Date?]] {
        // 月曜始まりなので weekday 1 = Monday
        let firstWeekday = cal.component(.weekday, from: monthStart)
        // ISO: Mon=2 ... Sun=1 → 先頭に埋める空白数
        let leadingBlanks = (firstWeekday + 5) % 7  // Mon=0, Tue=1, ... Sun=6

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        let range = cal.range(of: .day, in: .month, for: monthStart)!
        for d in 1...range.count {
            days.append(cal.date(byAdding: .day, value: d - 1, to: monthStart))
        }
        // 7の倍数になるよう末尾を埋める
        while days.count % 7 != 0 { days.append(nil) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0+7]) }
    }

    // 選択中の週の月曜・日曜
    private var selectedWeekStart: Date {
        let wd = cal.component(.weekday, from: date)
        let offset = (wd + 5) % 7   // Mon=0
        return cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: date))!
    }
    private var selectedWeekEnd: Date {
        cal.date(byAdding: .day, value: 6, to: selectedWeekStart)!
    }

    private let weekdayLabels = ["月","火","水","木","金","土","日"]
    private let colCount = 7

    var body: some View {
        VStack(spacing: 12) {
            // ── 月ナビゲーション ──
            HStack {
                Button {
                    displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth)!
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button {
                    displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth)!
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)

            // ── 曜日ヘッダー ──
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // ── 日付グリッド ──
            VStack(spacing: 4) {
                ForEach(weeks.indices, id: \.self) { wi in
                    let week = weeks[wi]
                    // この行に選択週が含まれるか
                    let isSelectedRow = week.compactMap { $0 }.contains { d in
                        d >= selectedWeekStart && d <= selectedWeekEnd
                    }

                    ZStack {
                        // 選択週のハイライトバー
                        if isSelectedRow {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.1))
                                .padding(.horizontal, 4)
                        }

                        HStack(spacing: 0) {
                            ForEach(0..<colCount, id: \.self) { ci in
                                if let day = week[ci] {
                                    let isSelected = cal.isDate(day, equalTo: date, toGranularity: .day)
                                    Button {
                                        date = day
                                        // displayMonth をタップした日の月に合わせる
                                        displayMonth = day
                                    } label: {
                                        ZStack {
                                            if isSelected {
                                                Circle()
                                                    .fill(Color.primary)
                                                    .frame(width: 36, height: 36)
                                            }
                                            Text("\(cal.component(.day, from: day))")
                                                .font(.callout)
                                                .fontWeight(isSelected ? .bold : .regular)
                                                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: displayMonth)
    }
}


struct DateSelectorSheet: View {
    @Binding var dateMode: DateSelectionMode
    @Binding var targetDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var tempMode: DateSelectionMode
    @State private var tempDate: Date

    init(dateMode: Binding<DateSelectionMode>, targetDate: Binding<Date>) {
        self._dateMode = dateMode
        self._targetDate = targetDate
        self._tempMode = State(initialValue: dateMode.wrappedValue)
        self._tempDate = State(initialValue: targetDate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("表示単位")) {
                    Picker("単位", selection: $tempMode) {
                        ForEach(DateSelectionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("対象の期間")) {
                    switch tempMode {
                    case .day:
                        DatePicker("日付を選択", selection: $tempDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    case .week:
                        WeekCalendarPicker(date: $tempDate)
                    case .month:
                        MonthYearPicker(date: $tempDate)
                    case .year:
                        YearPicker(date: $tempDate)
                    }
                }
            }
            .navigationTitle("期間の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.body, weight: .medium))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 12) {
                        Button {
                            tempMode = .week
                            tempDate = .now
                        } label: {
                            Text(String(localized: "リセット"))
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Button(String(localized: "適用")) {
                            dateMode = tempMode
                            targetDate = tempDate
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Main Graph View

struct GraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1

    @State private var graphMode: GraphMode = .line
    @State private var dateMode: DateSelectionMode = .week
    @State private var targetDate: Date = .now
    @State private var showDateSelector = false

    @State private var selectedEntry: MoodEntry?
    @State private var showDetail = false
    @State private var editingEntry: MoodEntry?
    @State private var entryToDelete: MoodEntry?

    @State private var rawSelectedDate: Date?
    @State private var selectedDay: Date?

    var onShowFullscreen: ((GraphMode, DateSelectionMode, Date) -> Void)? = nil

    var body: some View {
        let colors = themeManager.colors
        let yValues = smartYAxisValues(min: currentMinScore, max: currentMaxScore)
        let yDomain = yAxisDomain(min: currentMinScore, max: currentMaxScore)

        // Fix 9: daily / plotDays / segmentCounts を body 先頭で一度だけ計算してキャッシュ
        let daily = buildDailyData(entries: entries, mode: dateMode, targetDate: targetDate)
        let plotDays = buildPlotDays(from: daily)
        // Fix 8: segmentCount を O(1) で引けるように Dictionary に変換
        let segmentCounts = Dictionary(grouping: plotDays, by: \.segmentId).mapValues(\.count)

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    if entries.isEmpty {
                        Spacer()
                        emptyStateView(colors: colors)
                        Spacer()
                    } else if let day = selectedDay {
                        // MARK: 日詳細モード
                        controlBar(colors: colors)
                        ScrollView {
                            VStack(spacing: 16) {
                                dayDetailChart(day: day, yValues: yValues, yDomain: yDomain, colors: colors)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))

                                let dayEntries = entries
                                    .filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) }
                                    .sorted { $0.createdAt < $1.createdAt }
                                VStack(spacing: 8) {
                                    ForEach(dayEntries) { entry in
                                        dayEntryRow(entry: entry, colors: colors)
                                    }
                                }.padding(.horizontal)

                                if showDetail, let entry = selectedEntry {
                                    entryDetailCard(entry: entry, colors: colors)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                            .padding(.vertical)
                        }
                    } else if graphMode == .heatmap {
                        // MARK: ヒートマップモード
                        controlBar(colors: colors)
                        ScrollView {
                            YearInPixelsView(entries: entries, themeColors: colors)
                                .padding(.vertical)
                        }
                    } else {
                        // MARK: 通常グラフモード（折れ線・棒）
                        controlBar(colors: colors)

                        Group {
                            if dateMode == .day {
                                dayLevelChart(yValues: yValues, yDomain: yDomain, colors: colors)
                            } else {
                                overviewChart(
                                    yValues: yValues,
                                    yDomain: yDomain,
                                    colors: colors,
                                    plotDays: plotDays,
                                    segmentCounts: segmentCounts
                                )
                            }
                        }
                        .layoutPriority(1)

                        if showDetail, let entry = selectedEntry {
                            entryDetailCard(entry: entry, colors: colors)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.3), value: graphMode)
            .animation(.spring(response: 0.3), value: showDetail)
            .animation(.easeInOut(duration: 0.3), value: dateMode)
            .animation(.spring(response: 0.3), value: selectedDay)
            .onChange(of: rawSelectedDate) { _, newValue in
                if let date = newValue {
                    findAndShowClosestEntry(to: date)
                }
            }
            // Fix 10: dateMode / targetDate 変更時に selectedDay と詳細表示をリセット
            .onChange(of: dateMode) { _, _ in
                withAnimation {
                    selectedDay = nil
                    showDetail = false
                    selectedEntry = nil
                }
            }
            .onChange(of: targetDate) { _, _ in
                withAnimation {
                    selectedDay = nil
                    showDetail = false
                    selectedEntry = nil
                }
            }
            .sheet(isPresented: $showDateSelector) {
                DateSelectorSheet(dateMode: $dateMode, targetDate: $targetDate)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingEntry) { entry in
                MemoInputView(
                    score: entry.score,
                    themeColors: themeManager.colors,
                    editingEntry: entry,
                    onSave: { memo in
                        entry.memo = memo.isEmpty ? nil : String(memo.prefix(100))
                        editingEntry = nil
                    },
                    onSkip: { editingEntry = nil }
                )
            }
            .alert("この記録を削除しますか？", isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            )) {
                Button("削除", role: .destructive) {
                    if let entry = entryToDelete { deleteEntry(entry) }
                }
                Button("キャンセル", role: .cancel) { entryToDelete = nil }
            } message: {
                if let entry = entryToDelete {
                    Text("\(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute()) のスコアを削除します")
                }
            }
        }
    }

    // MARK: - Logic Functions

    /// タップされた日時に最も近いエントリを探して詳細を表示する
    private func findAndShowClosestEntry(to date: Date) {
        let visibleEntries = filteredEntries(entries: entries, mode: dateMode, targetDate: targetDate)
        guard !visibleEntries.isEmpty else { return }

        let closest = visibleEntries.min(by: {
            abs($0.createdAt.timeIntervalSince(date)) < abs($1.createdAt.timeIntervalSince(date))
        })

        // Fix 3: dateMode に応じて許容距離を動的に変更
        let tolerance: TimeInterval
        switch dateMode {
        case .day:   tolerance = 3600 * 2     // 2時間以内
        case .week:  tolerance = 86400         // 1日以内
        case .month: tolerance = 86400 * 3     // 3日以内
        case .year:  tolerance = 86400 * 15    // 15日以内
        }

        if let closest, abs(closest.createdAt.timeIntervalSince(date)) < tolerance {
            if selectedEntry?.id != closest.id || !showDetail {
                selectedEntry = closest
                showDetail = true
                HapticManager.lightFeedback()
            }
        }
        rawSelectedDate = nil
    }

    /// エントリを削除する
    private func deleteEntry(_ entry: MoodEntry) {
        if let photoPath = entry.photoPath { try? FileManager.default.removeItem(atPath: photoPath) }
        if let voicePath = entry.voiceMemoPath { try? FileManager.default.removeItem(atPath: voicePath) }

        if selectedEntry?.id == entry.id {
            withAnimation {
                showDetail = false
                selectedEntry = nil
            }
        }

        modelContext.delete(entry)
        entryToDelete = nil
        HapticManager.lightFeedback()
    }

    // MARK: - View Components (Control Bar)

    @ViewBuilder
    private func controlBar(colors: ThemeColors) -> some View {
        HStack(spacing: 10) {
            if selectedDay != nil {
                Button {
                    withAnimation {
                        selectedDay = nil
                        showDetail = false
                        selectedEntry = nil
                    }
                    HapticManager.lightFeedback()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                        Text("戻る")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(colors.accent.opacity(0.12)))
                    .foregroundStyle(colors.accent)
                }

                if let day = selectedDay {
                    Text(day, format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.abbreviated))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(colors.accent)
                }
                Spacer()
            } else {
                HStack(spacing: 4) {
                    ForEach(GraphMode.allCases, id: \.self) { mode in
                        let isSelected = graphMode == mode
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                graphMode = mode
                                showDetail = false
                                selectedEntry = nil
                            }
                            HapticManager.lightFeedback()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.iconName).font(.system(.caption, design: .rounded))
                                if isSelected {
                                    Text(LocalizedStringKey(mode.rawValue))
                                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, isSelected ? 12 : 0)
                            .frame(minWidth: 36, minHeight: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? colors.accent : Color(.systemGray5).opacity(0.6)))
                            .foregroundStyle(isSelected ? .white : .primary)
                        }.buttonStyle(.plain)
                    }
                }

                if graphMode != .heatmap {
                    Button {
                        showDateSelector = true
                        HapticManager.lightFeedback()
                    } label: {
                        HStack(spacing: 4) {
                            Text(formattedTargetDate())
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(colors.accent.opacity(0.12)))
                        .foregroundStyle(colors.accent)
                    }

                    Button {
                        onShowFullscreen?(graphMode, dateMode, targetDate)
                        HapticManager.lightFeedback()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(.caption, design: .rounded))
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5).opacity(0.6)))
                            .foregroundStyle(.primary)
                    }.buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// 現在の期間モードに合わせて日付をフォーマットする
    private func formattedTargetDate() -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        switch dateMode {
        case .day:
            f.dateFormat = "yyyy年M月d日"
            return f.string(from: targetDate)
        case .week:
            let range = periodRange(mode: .week, targetDate: targetDate)
            // Fix 7: 年をまたぐ場合は年付きフォーマットに切り替える
            let startYear = cal.component(.year, from: range.start)
            let endYear   = cal.component(.year, from: range.end)
            if startYear != endYear {
                f.dateFormat = "yyyy/M/d"
            } else {
                f.dateFormat = "M/d"
            }
            return "\(f.string(from: range.start)) - \(f.string(from: range.end))"
        case .month:
            f.dateFormat = "yyyy年M月"
            return f.string(from: targetDate)
        case .year:
            f.dateFormat = "yyyy年"
            return f.string(from: targetDate)
        }
    }

    // MARK: - View Components (Charts)

    /// 1日レベル（時間単位）のチャート
    @ViewBuilder
    private func dayLevelChart(yValues: [Int], yDomain: ClosedRange<Double>, colors: ThemeColors) -> some View {
        let range = periodRange(mode: .day, targetDate: targetDate)
        let visibleEntries = filteredEntries(entries: entries, mode: .day, targetDate: targetDate)

        Chart {
            if currentMinScore < 0 {
                RuleMark(y: .value("ゼロ", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
            }

            ForEach(visibleEntries) { entry in
                let score = Double(entry.score)
                // Fix 4: heatmap はこの関数が呼ばれないので bar/line のみハンドル
                if graphMode == .bar {
                    let barColor = colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore)
                    BarMark(
                        x: .value("時刻", entry.createdAt),
                        y: .value("スコア", score),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(LinearGradient(colors: [barColor.opacity(0.6), barColor], startPoint: .bottom, endPoint: .top))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    if visibleEntries.count > 1 {
                        LineMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                            .foregroundStyle(colors.graphLine)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.monotone)
                        AreaMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                            .foregroundStyle(LinearGradient(colors: [colors.graphLine.opacity(0.3), colors.graphLine.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                    }
                    PointMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                        .foregroundStyle(colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore))
                        .symbolSize(60)
                }
            }

            if showDetail, let sel = selectedEntry {
                RuleMark(x: .value("選択", sel.createdAt))
                    .foregroundStyle(colors.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXSelection(value: $rawSelectedDate)
        .chartXScale(domain: range.start...range.end)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated))).font(.system(.caption2, design: .rounded))
            }
        }
        .chartYAxis {
            AxisMarks(values: yValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel().font(.system(.caption2, design: .rounded))
            }
        }
        .clipped()
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }

    /// 概要レベル（日単位集計）のチャート
    /// Fix 8/9: plotDays と segmentCounts を呼び出し元から受け取ることでキャッシュを活用
    @ViewBuilder
    private func overviewChart(
        yValues: [Int],
        yDomain: ClosedRange<Double>,
        colors: ThemeColors,
        plotDays: [PlotDay],
        segmentCounts: [Int: Int]
    ) -> some View {
        let range = periodRange(mode: dateMode, targetDate: targetDate)

        Chart {
            if currentMinScore < 0 {
                RuleMark(y: .value("ゼロ", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
            }

            ForEach(plotDays) { p in
                // dateMode に応じて適切な時間単位を選択
                // year → .month（棒が月幅になり視認性UP）
                // week/month → .day（1日単位）
                let barUnit: Calendar.Component = dateMode == .year ? .month : .day

                if graphMode == .bar {
                    let barColor = colors.color(for: Int(p.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore)
                    BarMark(x: .value("日", p.date, unit: barUnit), y: .value("平均", p.average), width: .ratio(0.7))
                        .foregroundStyle(LinearGradient(colors: [barColor.opacity(0.6), barColor], startPoint: .bottom, endPoint: .top))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    if p.count > 1, p.minScore != p.maxScore {
                        RectangleMark(
                            x: .value("日", p.date, unit: barUnit),
                            yStart: .value("最低", Double(p.minScore)),
                            yEnd: .value("最高", Double(p.maxScore)),
                            width: 3
                        )
                        .foregroundStyle(colors.graphLine.opacity(0.5))
                        .cornerRadius(1.5)
                    }

                } else {
                    // Fix 8: segmentCounts から O(1) で取得
                    let segmentCount = segmentCounts[p.segmentId] ?? 0
                    // 各日の正午（noon）を使うことで点・線が日付ラベルの中心に揃う
                    let noon = p.date.addingTimeInterval(43200)
                    if segmentCount > 1 {
                        LineMark(x: .value("日", noon), y: .value("平均", p.average))
                            .foregroundStyle(colors.graphLine)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.monotone)
                        AreaMark(x: .value("日", noon), y: .value("平均", p.average))
                            .foregroundStyle(LinearGradient(colors: [colors.graphLine.opacity(0.3), colors.graphLine.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                    }
                    PointMark(x: .value("日", noon), y: .value("平均", p.average))
                        .foregroundStyle(colors.color(for: Int(p.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))
                        .symbolSize(60)

                    // 1日複数記録時の min-max 範囲バー
                    // unit: .day を使うと year 表示で极細になるため固定ピクセル幅で描く
                    if p.count > 1 && p.minScore != p.maxScore {
                        RectangleMark(x: .value("日", noon), yStart: .value("最低", Double(p.minScore)), yEnd: .value("最高", Double(p.maxScore)), width: 4)
                            .foregroundStyle(colors.graphLine.opacity(0.2))
                            .cornerRadius(2)
                    }
                }
            }

        }
        .chartXScale(domain: range.start...range.end)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            let strideComponent: Calendar.Component = (dateMode == .month || dateMode == .week) ? .day : .month
            let count = dateMode == .month ? 5 : 1

            AxisMarks(values: .stride(by: strideComponent, count: count)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                if dateMode == .month || dateMode == .week {
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                        .font(.system(.caption2, design: .rounded))
                } else {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(.caption2, design: .rounded))
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: yValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel().font(.system(.caption2, design: .rounded))
            }
        }
        .clipped()
        .padding(.top, 12)
        .padding(.bottom, 20)
        // Fix 1: タップ位置が表示範囲外の場合は無視する
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let xPos = location.x - geometry[plotFrame].origin.x
                        guard let date: Date = proxy.value(atX: xPos) else { return }

                        // Fix 1: タップした日付が表示期間内にあるか検証
                        guard date >= range.start && date <= range.end else { return }

                        let cal = Calendar.current
                        let tappedDay = cal.startOfDay(for: date)

                        withAnimation {
                            selectedDay = tappedDay
                            showDetail = false
                            selectedEntry = nil
                        }
                        HapticManager.lightFeedback()
                    }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }

    /// 日詳細モードで表示するチャート
    @ViewBuilder
    private func dayDetailChart(day: Date, yValues: [Int], yDomain: ClosedRange<Double>, colors: ThemeColors) -> some View {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!.addingTimeInterval(-1)
        let dayEntries = entries
            .filter { cal.isDate($0.createdAt, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }

        VStack(alignment: .leading, spacing: 16) {
            Text("1日の流れ")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.horizontal)

            Chart {
                if currentMinScore < 0 {
                    RuleMark(y: .value("ゼロ", 0))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
                }
                ForEach(dayEntries) { entry in
                    let score = Double(entry.score)
                    switch graphMode {
                    case .bar:
                        let barColor = colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore)
                        BarMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score), width: .ratio(0.6))
                            .foregroundStyle(LinearGradient(colors: [barColor.opacity(0.6), barColor], startPoint: .bottom, endPoint: .top))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    default:
                        if dayEntries.count > 1 {
                            LineMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                                .foregroundStyle(colors.graphLine)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                                .interpolationMethod(.monotone)
                            AreaMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                                .foregroundStyle(LinearGradient(colors: [colors.graphLine.opacity(0.3), colors.graphLine.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                        }
                        PointMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                            .foregroundStyle(colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore))
                            .symbolSize(60)
                    }
                }

                if showDetail, let sel = selectedEntry {
                    RuleMark(x: .value("選択", sel.createdAt))
                        .foregroundStyle(colors.accent.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXSelection(value: $rawSelectedDate)
            .chartXScale(domain: dayStart...dayEnd)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated))).font(.system(.caption2, design: .rounded))
                }
            }
            .chartYAxis {
                AxisMarks(values: yValues) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel().font(.system(.caption2, design: .rounded))
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(height: 220)
            .padding(.horizontal)
        }
    }

    // MARK: - View Components (Rows & States)

    /// エントリのリスト行
    @ViewBuilder
    private func dayEntryRow(entry: MoodEntry, colors: ThemeColors) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.score)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt, format: .dateTime.hour().minute())
                    .font(.system(.subheadline, design: .rounded, weight: .medium))

                if let memo = entry.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                            Text(tag)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(colors.accent.opacity(0.1)))
                                .foregroundStyle(colors.accent)
                        }
                    }
                }
            }
            Spacer()
            // Fix 11: 詳細カードとの選択状態を統一（selectedEntry + showDetail の両方を設定）
            Button {
                withAnimation {
                    selectedEntry = entry
                    showDetail = true
                }
                HapticManager.lightFeedback()
            } label: {
                Image(systemName: showDetail && selectedEntry?.id == entry.id ? "chevron.down" : "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(colors.accent.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    /// データがない時の表示
    @ViewBuilder
    private func emptyStateView(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(colors.accent.opacity(0.3))
                .background(
                    Circle()
                        .fill(colors.accent.opacity(0.1))
                        .frame(width: 120, height: 120)
                )

            VStack(spacing: 8) {
                Text("まだ記録がありません")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("今の気分を記録してみましょう。\nグラフで変化が見えるようになります。")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
    }

    /// 選択されたエントリの詳細カード
    @ViewBuilder
    private func entryDetailCard(entry: MoodEntry, colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation {
                        showDetail = false
                        selectedEntry = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(entry.score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore))
                    Text("スコア")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if let memo = entry.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.system(.body, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("メモはありません")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    HStack(spacing: 12) {
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("編集", systemImage: "pencil")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(colors.accent)

                        Spacer()

                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("削除", systemImage: "trash")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}

// MARK: - Fullscreen Chart View

/// chartScrollableAxes / chartXVisibleDomain / chartScrollPosition は
/// MagnifyGesture と干渉して動作不良になるため廃止。
/// domainStart / domainEnd を State で直接管理し、
/// chartOverlay に貼った DragGesture / MagnifyGesture で操作する。
struct FullscreenChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1

    let graphMode: GraphMode
    let initialDateMode: DateSelectionMode
    let targetDate: Date
    var onDismiss: () -> Void

    @State private var selectedEntry: MoodEntry?
    @State private var showDetail = false

    /// 表示ウィンドウの開始・終了 Date
    @State private var domainStart: Date
    @State private var domainEnd: Date

    /// ドラッグ開始時のドメインスナップショット
    @State private var dragAnchor: (Date, Date)?
    /// ピンチ開始時のドメインスナップショット
    @State private var pinchAnchor: (Date, Date)?

    private let minZoom: TimeInterval = 3600.0
    private let maxZoom: TimeInterval = 86400.0 * 365.0 * 5.0
    private let cal = Calendar.current

    init(graphMode: GraphMode, dateMode: DateSelectionMode, targetDate: Date, onDismiss: @escaping () -> Void) {
        self.graphMode = graphMode
        self.initialDateMode = dateMode
        self.targetDate = targetDate
        self.onDismiss = onDismiss

        let range = periodRange(mode: dateMode, targetDate: targetDate)
        self._domainStart = State(initialValue: range.start)
        self._domainEnd   = State(initialValue: range.end)
    }

    // MARK: - Computed helpers

    private var visibleDuration: TimeInterval {
        domainEnd.timeIntervalSince(domainStart)
    }

    private var domainCenter: Date {
        domainStart.addingTimeInterval(visibleDuration / 2)
    }

    // MARK: - Body

    var body: some View {
        let colors = themeManager.colors
        let yValues = smartYAxisValues(min: currentMinScore, max: currentMaxScore)
        let yDomain  = yAxisDomain(min: currentMinScore, max: currentMaxScore)

        ZStack {
            colors.backgroundGradient(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 0) {
                // ヘッダー
                ZStack {
                    HStack {
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        Spacer()
                        // ズームボタン（ピンチズームの補助）
                        HStack(spacing: 4) {
                            Button {
                                let newDur = max(minZoom, visibleDuration / 2)
                                let center = domainCenter
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    domainStart = center.addingTimeInterval(-newDur / 2)
                                    domainEnd   = center.addingTimeInterval( newDur / 2)
                                }
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                let newDur = min(maxZoom, visibleDuration * 2)
                                let center = domainCenter
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    domainStart = center.addingTimeInterval(-newDur / 2)
                                    domainEnd   = center.addingTimeInterval( newDur / 2)
                                }
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.trailing)
                    }
                    Text(headerDateString())
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .animation(.easeInOut, value: visibleDuration)
                }
                .background(.ultraThinMaterial)

                // チャート本体
                fullscreenChart(yValues: yValues, yDomain: yDomain, colors: colors)
                    .padding(.top, 20)
                    .layoutPriority(1)
            }

            // 詳細カード
            if showDetail, let entry = selectedEntry {
                VStack {
                    Spacer()
                    fullscreenDetailCard(entry: entry, colors: colors)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding()
                }
            }
        }
        .animation(.spring(response: 0.3), value: showDetail)
    }

    // MARK: - Header

    private func headerDateString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        // 時間・日レベル（< 3日）→ 年月日まで表示して迷子防止
        if visibleDuration < 86400.0 * 3 {
            f.dateFormat = "yyyy年M月d日(E)"
        } else if visibleDuration < 86400.0 * 60 {
            f.dateFormat = "yyyy年M月"
        } else {
            f.dateFormat = "yyyy年"
        }
        return f.string(from: domainCenter)
    }

    // MARK: - Fullscreen Chart

    @ViewBuilder
    private func fullscreenChart(yValues: [Int], yDomain: ClosedRange<Double>, colors: ThemeColors) -> some View {
        // visibleDuration をローカル変数に取り出す（クロージャ内で self を介さずに参照するため）
        let dur = visibleDuration

        Chart {
            if currentMinScore < 0 {
                RuleMark(y: .value("ゼロ", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
            }

            ForEach(entries) { entry in
                let score = Double(entry.score)
                if graphMode == .bar {
                    let barColor = colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore)
                    BarMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                        .foregroundStyle(LinearGradient(colors: [barColor.opacity(0.6), barColor], startPoint: .bottom, endPoint: .top))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    if entries.count > 1 {
                        LineMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                            .foregroundStyle(colors.graphLine)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.monotone)
                        AreaMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                            .foregroundStyle(LinearGradient(colors: [colors.graphLine.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                    }
                    PointMark(x: .value("時刻", entry.createdAt), y: .value("スコア", score))
                        .foregroundStyle(colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore))
                        .symbolSize(50)
                }
            }

            if showDetail, let sel = selectedEntry {
                RuleMark(x: .value("選択", sel.createdAt))
                    .foregroundStyle(colors.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        // ── スクロール API を使わず、明示的なドメインで制御 ──
        .chartXScale(domain: domainStart...domainEnd)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(values: yValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel().font(.system(.caption2, design: .rounded))
            }
        }
        .chartXAxis {
            // ラベル密集を防ぐため、表示幅に応じてラベル密度を段階的に制御する
            // 目安: 画面幅 ~375pt, 1ラベルあたり最低 40pt 確保 → 最大 ~9ラベル
            if dur <= 3600.0 * 6 {
                // ≤ 6時間: 1時間ごと → "9時"
                AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour()).font(.system(.caption2, design: .rounded))
                }
            } else if dur <= 86400.0 * 1 {
                // ≤ 1日: 3時間ごと → "9時"  (最大8ラベル)
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour()).font(.system(.caption2, design: .rounded))
                }
            } else if dur <= 86400.0 * 4 {
                // 1〜4日: 12時間ごと、0時のみ "M/d" ラベル。正午はグリッドのみ
                AxisMarks(values: .stride(by: .hour, count: 12)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    if let d = value.as(Date.self), cal.component(.hour, from: d) == 0 {
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                    } else {
                        // 正午はラベル非表示（グリッドのみ）
                        AxisValueLabel("").font(.system(.caption2, design: .rounded))
                    }
                }
            } else if dur <= 86400.0 * 14 {
                // 4〜14日: 1日ごと → "2/18"  (最大14ラベル、画面に収まる範囲)
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                        .font(.system(.caption2, design: .rounded))
                }
            } else if dur <= 86400.0 * 60 {
                // 2週間〜2ヶ月: 週ごと → "2/18"  (最大~8ラベル)
                AxisMarks(values: .stride(by: .weekOfYear, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                        .font(.system(.caption2, design: .rounded))
                }
            } else if dur <= 86400.0 * 365.0 * 2 {
                // 2ヶ月〜2年: 月ごと → "2月"  (最大24ラベル→短いので許容)
                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated)).font(.system(.caption2, design: .rounded))
                }
            } else if dur <= 86400.0 * 365.0 * 5 {
                // 2〜5年: 半年ごと → "2026年1月"
                AxisMarks(values: .stride(by: .month, count: 6)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.year().month(.abbreviated)).font(.system(.caption2, design: .rounded))
                }
            } else {
                // > 5年: 年ごと → "2026年"
                AxisMarks(values: .stride(by: .year, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: .dateTime.year()).font(.system(.caption2, design: .rounded))
                }
            }
        }
        .clipped()
        .padding(.top, 12)
        .padding(.bottom, 20)
        // ── インタラクション: chartOverlay で全て管理 ──
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plotOriginX: CGFloat = proxy.plotFrame.map { geo[$0].origin.x } ?? 0
                let plotWidth: CGFloat   = proxy.plotFrame.map { geo[$0].width }   ?? geo.size.width

                Color.clear.contentShape(Rectangle())
                    // タップ → エントリ選択
                    .onTapGesture { location in
                        let x = location.x - plotOriginX
                        guard x >= 0, x <= plotWidth else { return }
                        guard let tappedDate: Date = proxy.value(atX: x) else { return }
                        let tolerance = visibleDuration * 0.05
                        let closest = entries.min(by: {
                            abs($0.createdAt.timeIntervalSince(tappedDate)) < abs($1.createdAt.timeIntervalSince(tappedDate))
                        })
                        if let entry = closest, abs(entry.createdAt.timeIntervalSince(tappedDate)) < tolerance {
                            withAnimation { selectedEntry = entry; showDetail = true }
                            HapticManager.lightFeedback()
                        } else {
                            withAnimation { showDetail = false; selectedEntry = nil }
                        }
                    }
                    // 1本指ドラッグ → パン
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                if dragAnchor == nil { dragAnchor = (domainStart, domainEnd) }
                                guard let (s, e) = dragAnchor else { return }
                                let duration = e.timeIntervalSince(s)
                                let secsPerPixel = duration / Double(max(plotWidth, 1))
                                let offset = Double(-value.translation.width) * secsPerPixel
                                domainStart = s.addingTimeInterval(offset)
                                domainEnd   = e.addingTimeInterval(offset)
                            }
                            .onEnded { _ in dragAnchor = nil }
                    )
                    // 2本指ピンチ → ズーム
                    .simultaneousGesture(
                        MagnifyGesture()
                            .onChanged { value in
                                if pinchAnchor == nil { pinchAnchor = (domainStart, domainEnd) }
                                guard let (s, e) = pinchAnchor else { return }
                                let center = s.addingTimeInterval(e.timeIntervalSince(s) / 2)
                                var newDur = e.timeIntervalSince(s) / value.magnification
                                newDur = max(minZoom, min(maxZoom, newDur))
                                domainStart = center.addingTimeInterval(-newDur / 2)
                                domainEnd   = center.addingTimeInterval(newDur / 2)
                            }
                            .onEnded { _ in pinchAnchor = nil }
                    )
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
    }

    // MARK: - Detail Card

    @ViewBuilder
    private func fullscreenDetailCard(entry: MoodEntry, colors: ThemeColors) -> some View {
        HStack(spacing: 16) {
            Text("\(entry.score)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: entry.score, minScore: currentMinScore, maxScore: currentMaxScore))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                if let memo = entry.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button {
                withAnimation { showDetail = false; selectedEntry = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
        )
    }
}

// MARK: - Previews

#Preview("GraphView - 通常") {
    GraphView()
        .environment(\.themeManager, ThemeManager())
}

#Preview("FullscreenChartView - 全画面") {
    FullscreenChartView(
        graphMode: .line,
        dateMode: .month,
        targetDate: Date(),
        onDismiss: {}
    )
    .environment(\.themeManager, ThemeManager())
}

