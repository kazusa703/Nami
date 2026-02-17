//
//  GraphView.swift
//  Nami
//
//  ライングラフ画面 - 気分の波を可視化する
//

import SwiftUI
import SwiftData
import Charts

/// グラフの表示期間
enum ChartPeriod: String, CaseIterable, Identifiable {
    case week = "1週間"
    case month = "1ヶ月"
    case threeMonths = "3ヶ月"
    case sixMonths = "6ヶ月"
    case year = "1年"
    case all = "全期間"

    var id: String { rawValue }

    /// 期間の開始日（nilは全期間）
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -7, to: now)
        case .month: return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: now)
        case .year: return calendar.date(byAdding: .year, value: -1, to: now)
        case .all: return nil
        }
    }
}

/// グラフの表示モード
enum GraphMode: String, CaseIterable {
    case line = "折れ線"
    case step = "ステップ"
    case bar = "棒グラフ"
    case heatmap = "芝生"

    /// SF Symbols アイコン名
    var iconName: String {
        switch self {
        case .line: return "chart.xyaxis.line"
        case .step: return "chart.line.flattrend.xyaxis"
        case .bar: return "chart.bar.fill"
        case .heatmap: return "square.grid.3x3.fill"
        }
    }

    /// ZoomableChartContainer で描画可能かどうか
    var isChartType: Bool {
        self != .heatmap
    }
}

/// X軸の日付粒度
enum TimeScale: String, CaseIterable {
    case hourly = "時間"
    case daily = "日"
    case weekly = "週"
    case monthly = "月"

    /// X軸のフォーマット
    var dateFormat: Date.FormatStyle {
        switch self {
        case .hourly: return .dateTime.month(.defaultDigits).day(.defaultDigits).hour()
        case .daily: return .dateTime.month(.defaultDigits).day(.defaultDigits)
        case .weekly: return .dateTime.month(.defaultDigits).day(.defaultDigits)
        case .monthly: return .dateTime.month(.defaultDigits).day(.defaultDigits)
        }
    }

    /// SF Symbols アイコン名
    var iconName: String {
        switch self {
        case .hourly: return "clock"
        case .daily: return "calendar.day.timeline.left"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        }
    }
}

/// ドリルダウンのレベル（フルスクリーン用）
/// 年→月→日の階層でグラフを掘り下げる
enum DrillLevel: Hashable {
    case year(Int)           // 年レベル: X軸=月
    case month(Int, Int)     // 月レベル: X軸=日
    case day(Int, Int, Int)  // 日レベル: X軸=時

    /// ヘッダー表示テキスト
    var headerText: String {
        switch self {
        case .year(let y): return "\(y)年"
        case .month(let y, let m): return "\(y)年\(m)月"
        case .day(_, let m, let d): return "\(m)月\(d)日"
        }
    }

    /// 一つ上のレベル（戻る先）
    var parent: DrillLevel? {
        switch self {
        case .year: return nil
        case .month(let y, _): return .year(y)
        case .day(let y, let m, _): return .month(y, m)
        }
    }

    /// このレベルの日付範囲
    var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let fallback = Date.now
        switch self {
        case .year(let y):
            let start = cal.date(from: DateComponents(year: y, month: 1, day: 1)) ?? fallback
            let end = cal.date(from: DateComponents(year: y + 1, month: 1, day: 1)) ?? fallback
            return start...end
        case .month(let y, let m):
            let start = cal.date(from: DateComponents(year: y, month: m, day: 1)) ?? fallback
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? fallback
            return start...end
        case .day(let y, let m, let d):
            let start = cal.date(from: DateComponents(year: y, month: m, day: d)) ?? fallback
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? fallback
            return start...end
        }
    }
}

/// グラフ画面
/// 記録された気分スコアを時系列の折れ線グラフで表示する
struct GraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    /// 表示モード
    @State private var graphMode: GraphMode = .line
    /// 選択中の表示期間
    @State private var selectedPeriod: ChartPeriod = .week
    /// X軸の日付粒度
    @State private var selectedTimeScale: TimeScale = .daily
    /// 選択されたエントリ（詳細表示用）
    @State private var selectedEntry: MoodEntry?
    /// 詳細表示フラグ
    @State private var showDetail = false
    /// メモ編集シートの対象エントリ
    @State private var editingEntry: MoodEntry?
    /// 全画面表示フラグ
    @State private var showFullscreen = false
    /// 削除確認対象エントリ
    @State private var entryToDelete: MoodEntry?

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if entries.isEmpty {
                        // データ0件の場合の案内ビュー
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 52))
                                .foregroundStyle(colors.accent.opacity(0.3))

                            Text("気分の波を可視化")
                                .font(.system(.title3, design: .rounded, weight: .bold))

                            Text("記録が増えるほど、折れ線グラフ・ステップチャート・\nカレンダーヒートマップで気分の変化が見えてきます")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                graphFeatureChip(icon: "chart.xyaxis.line", text: "折れ線", colors: colors)
                                graphFeatureChip(icon: "chart.line.flattrend.xyaxis", text: "ステップ", colors: colors)
                                graphFeatureChip(icon: "square.grid.3x3.fill", text: "芝生", colors: colors)
                            }
                        }
                        .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // 表示モード + 期間 + 全画面ボタン
                                controlBar(colors: colors)

                                switch graphMode {
                                case .line, .step, .bar:
                                    chartContent(colors: colors, mode: graphMode)
                                        .id("chart-\(graphMode.rawValue)")

                                case .heatmap:
                                    YearInPixelsView(
                                        entries: entries,
                                        themeColors: colors
                                    )
                                }
                            }
                            .padding(.vertical)
                        }
                    }

                    // 広告バナー（画面最下部に固定）
                    BannerAdView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.3), value: graphMode)
            .animation(.spring(response: 0.3), value: showDetail)
            .animation(.spring(response: 0.3), value: selectedPeriod)
            .sheet(item: $editingEntry) { entry in
                MemoInputView(
                    score: entry.score,
                    themeColors: themeManager.colors,
                    editingEntry: entry,
                    onSave: { memo in
                        entry.memo = memo.isEmpty ? nil : String(memo.prefix(100))
                        editingEntry = nil
                    },
                    onSkip: {
                        editingEntry = nil
                    }
                )
            }
            .fullScreenCover(isPresented: $showFullscreen, onDismiss: {
                // フルスクリーン解除時にポートレートに強制復帰
                NamiAppDelegate.allowLandscape = false
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
            }) {
                FullscreenChartView(
                    entries: entries,
                    themeColors: themeManager.colors,
                    graphMode: graphMode,
                    period: selectedPeriod,
                    timeScale: selectedTimeScale,
                    onDeleteEntry: { entry in
                        deleteEntry(entry)
                    }
                )
            }
            .alert("この記録を削除しますか？", isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            )) {
                Button("削除", role: .destructive) {
                    if let entry = entryToDelete {
                        deleteEntry(entry)
                    }
                }
                Button("キャンセル", role: .cancel) {
                    entryToDelete = nil
                }
            } message: {
                if let entry = entryToDelete {
                    Text("\(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute()) のスコア \(entry.score) を削除します")
                }
            }
        }
    }

    // MARK: - エントリ削除

    /// エントリを削除する（関連ファイルも含む）
    private func deleteEntry(_ entry: MoodEntry) {
        // 写真ファイルを削除
        if let photoPath = entry.photoPath {
            try? FileManager.default.removeItem(atPath: photoPath)
        }
        // ボイスメモファイルを削除
        if let voicePath = entry.voiceMemoPath {
            try? FileManager.default.removeItem(atPath: voicePath)
        }
        // 選択中のエントリだった場合はクリア
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

    /// グラフ機能チップ（空状態表示用）
    private func graphFeatureChip(icon: String, text: String, colors: ThemeColors) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .foregroundStyle(colors.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(colors.accent.opacity(0.1)))
    }

    // MARK: - コントロールバー（モード + 期間 + 全画面）

    @ViewBuilder
    private func controlBar(colors: ThemeColors) -> some View {
        HStack(spacing: 10) {
            // モード切り替えボタン群
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
                            Image(systemName: mode.iconName)
                                .font(.system(.caption, design: .rounded))
                            if isSelected {
                                Text(LocalizedStringKey(mode.rawValue))
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, isSelected ? 12 : 0)
                        .frame(minWidth: 36, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? colors.accent : Color(.systemGray5).opacity(0.6))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 期間メニュー（折れ線/ステップモード時のみ表示）
            if graphMode != .heatmap {
                periodMenu(colors: colors)
                timeScaleMenu(colors: colors)
            }

            Spacer()

            // 全画面ボタン（折れ線/ステップ時のみ）
            if graphMode != .heatmap {
                Button {
                    showFullscreen = true
                    HapticManager.lightFeedback()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(.subheadline, design: .rounded))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5).opacity(0.6))
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 期間メニュー（ドロップダウン）

    @ViewBuilder
    private func periodMenu(colors: ThemeColors) -> some View {
        Menu {
            ForEach(ChartPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                        showDetail = false
                    }
                    HapticManager.lightFeedback()
                } label: {
                    HStack {
                        Text(LocalizedStringKey(period.rawValue))
                        if period == selectedPeriod {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(LocalizedStringKey(selectedPeriod.rawValue))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(colors.accent.opacity(0.12))
            )
            .foregroundStyle(colors.accent)
        }
    }

    // MARK: - 日付粒度メニュー（ドロップダウン）

    @ViewBuilder
    private func timeScaleMenu(colors: ThemeColors) -> some View {
        Menu {
            ForEach(TimeScale.allCases, id: \.self) { scale in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeScale = scale
                    }
                    HapticManager.lightFeedback()
                } label: {
                    HStack {
                        Label(LocalizedStringKey(scale.rawValue), systemImage: scale.iconName)
                        if scale == selectedTimeScale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedTimeScale.iconName)
                    .font(.system(size: 10, weight: .bold))
                Text(LocalizedStringKey(selectedTimeScale.rawValue))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(colors.accent.opacity(0.12))
            )
            .foregroundStyle(colors.accent)
        }
    }

    // MARK: - チャートコンテンツ（折れ線/ステップ/棒グラフ共通）

    @ViewBuilder
    private func chartContent(colors: ThemeColors, mode: GraphMode) -> some View {
        // チャート（通常ビューではズーム・パン無効）
        GeometryReader { geo in
            ZoomableChartContainer(
                entries: entries,
                themeColors: colors,
                period: selectedPeriod,
                graphMode: mode,
                timeScale: selectedTimeScale,
                zoomEnabled: false,
                onPointTap: { entry in
                    selectedEntry = entry
                    showDetail = true
                    HapticManager.lightFeedback()
                },
                onPointLongPress: { entry in
                    entryToDelete = entry
                    HapticManager.recordFeedback()
                },
                chartWidth: geo.size.width
            )
        }
        .frame(height: 250)
        .padding(.horizontal)

        // 選択されたエントリの詳細
        if showDetail, let entry = selectedEntry {
            entryDetailCard(entry: entry, colors: colors)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
        }
    }

    // MARK: - エントリ詳細カード

    @ViewBuilder
    private func entryDetailCard(entry: MoodEntry, colors: ThemeColors) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("記録の詳細")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Button {
                    withAnimation {
                        showDetail = false
                        selectedEntry = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }

            HStack(spacing: 16) {
                Text("\(entry.score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.color(for: entry.score, maxScore: entry.maxScore))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                        .font(.system(.subheadline, design: .rounded))

                    if let memo = entry.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // タグチップ表示
                    if !entry.tags.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(.caption2, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                                    .foregroundStyle(colors.accent)
                            }
                            if entry.tags.count > 3 {
                                Text("+\(entry.tags.count - 3)")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                // メモ編集ボタン
                Button {
                    editingEntry = entry
                } label: {
                    Image(systemName: entry.memo?.isEmpty == false ? "pencil.circle.fill" : "plus.circle")
                        .font(.title3)
                        .foregroundStyle(colors.accent.opacity(0.7))
                }
                .buttonStyle(.plain)

                // 削除ボタン
                Button {
                    entryToDelete = entry
                } label: {
                    Image(systemName: "trash.circle")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
}

// MARK: - ズーム・パン対応チャートコンテナ

/// ピンチズームとドラッグパンに対応したチャートラッパー
struct ZoomableChartContainer: View {
    let entries: [MoodEntry]
    let themeColors: ThemeColors
    let period: ChartPeriod
    /// チャートの表示モード（折れ線/ステップ/棒グラフ）
    var graphMode: GraphMode = .line
    var timeScale: TimeScale = .daily
    /// ズーム・パンの有効/無効（通常ビューではfalse）
    var zoomEnabled: Bool = true
    /// ドリルダウン時のレベル指定（フルスクリーン用）
    var drillLevel: DrillLevel? = nil
    let onPointTap: ((MoodEntry) -> Void)?
    /// ドリルダウンタップコールバック（フルスクリーン用）
    var onDrillTap: ((Date) -> Void)? = nil
    /// 長押し時のコールバック（削除確認用）
    var onPointLongPress: ((MoodEntry) -> Void)? = nil
    /// フルスクリーン用の高さ上書き
    var chartHeight: CGFloat = 250
    /// チャートの実際の幅（棒グラフ幅計算用）
    var chartWidth: CGFloat = 0

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10

    /// ズーム倍率（1.0 = 等倍）
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    /// パンオフセット（秒単位）
    @State private var panOffset: TimeInterval = 0
    @State private var lastPanOffset: TimeInterval = 0
    /// 長押しの位置追跡用
    @State private var lastLongPressLocation: CGPoint = .zero

    /// 表示期間でフィルタリングされたエントリ
    private var allFilteredEntries: [MoodEntry] {
        // ドリルダウン時はレベルの日付範囲でフィルタ
        if let drillLevel {
            let range = drillLevel.dateRange
            return entries
                .filter { range.contains($0.createdAt) }
                .sorted { $0.createdAt < $1.createdAt }
        }
        guard let startDate = period.startDate else {
            return entries.sorted { $0.createdAt < $1.createdAt }
        }
        return entries
            .filter { $0.createdAt >= startDate }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Y軸の上限（maxScoreと実際のスコアの両方を考慮）
    private var yAxisMax: Int {
        let maxScoreMax = allFilteredEntries.map(\.maxScore).max() ?? 10
        let scoreMax = allFilteredEntries.map(\.score).max() ?? 10
        return max(currentMaxScore, maxScoreMax, scoreMax)
    }

    /// ズーム・パン適用後の表示範囲
    private var visibleDateRange: ClosedRange<Date> {
        // ドリルダウン時はレベルの日付範囲をベースにする
        if let drillLevel {
            let range = drillLevel.dateRange
            let totalSpan = range.upperBound.timeIntervalSince(range.lowerBound)
            let visibleSpan = totalSpan / scale
            let center = range.lowerBound.timeIntervalSince1970 + totalSpan / 2 + panOffset
            let start = Date(timeIntervalSince1970: center - visibleSpan / 2)
            let end = Date(timeIntervalSince1970: center + visibleSpan / 2)
            return start...end
        }

        guard let first = allFilteredEntries.first?.createdAt,
              let last = allFilteredEntries.last?.createdAt else {
            let now = Date.now
            return now...now
        }

        // データが短期間に集中している場合、最低3日分の幅を確保
        let minSpan: TimeInterval = 3 * 24 * 3600
        let rawSpan = last.timeIntervalSince(first)
        let totalSpan = max(rawSpan, minSpan)

        let visibleSpan = totalSpan / scale
        // データの中心を基準にする（短期間データの場合はパディングが均等になる）
        let dataCenter = first.timeIntervalSince1970 + rawSpan / 2
        let center = dataCenter + panOffset

        let start = Date(timeIntervalSince1970: center - visibleSpan / 2)
        let end = Date(timeIntervalSince1970: center + visibleSpan / 2)
        return start...end
    }

    /// 表示範囲内のエントリ
    /// パフォーマンス保護: 最大描画エントリ数
    private static let maxVisibleEntries = 300

    private var visibleEntries: [MoodEntry] {
        let range = visibleDateRange
        let filtered = allFilteredEntries.filter { range.contains($0.createdAt) }
        // 大量エントリ時はサンプリングしてパフォーマンスを保護
        if filtered.count > Self.maxVisibleEntries {
            let step = max(filtered.count / Self.maxVisibleEntries, 1)
            return stride(from: 0, to: filtered.count, by: step).map { filtered[$0] }
        }
        return filtered
    }

    /// スコア範囲変更日
    private var rangeChangeDates: [(date: Date, from: Int, to: Int)] {
        let sorted = visibleEntries
        guard sorted.count >= 2 else { return [] }
        var changes: [(date: Date, from: Int, to: Int)] = []
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            if prev.maxScore != curr.maxScore {
                let midTime = (prev.createdAt.timeIntervalSinceReferenceDate + curr.createdAt.timeIntervalSinceReferenceDate) / 2
                changes.append((Date(timeIntervalSinceReferenceDate: midTime), prev.maxScore, curr.maxScore))
            }
        }
        return changes
    }

    var body: some View {
        if allFilteredEntries.isEmpty {
            ContentUnavailableView {
                Label("データなし", systemImage: "chart.line.downtrend.xyaxis")
            } description: {
                Text("この期間のデータがありません。\n気分を記録してグラフを見てみましょう。")
            }
            .frame(height: chartHeight)
        } else {
            let chart = chartBody
                .frame(height: chartHeight)
                .contentShape(Rectangle())

            if zoomEnabled {
                chart
                    .gesture(pinchGesture)
                    .simultaneousGesture(dragGesture)
                    .onChange(of: period) { _, _ in
                        // 期間変更時にズーム・パンをリセット
                        withAnimation(.easeOut(duration: 0.2)) {
                            scale = 1.0
                            lastScale = 1.0
                            panOffset = 0
                            lastPanOffset = 0
                        }
                    }
            } else {
                chart
            }
        }
    }

    // MARK: - チャート描画

    /// バーの幅（エントリ数とチャート幅に応じて動的調整）
    private var barWidth: MarkDimension {
        let count = visibleEntries.count
        guard count > 0 else { return .fixed(16) }

        // チャートの実幅（Y軸ラベル分を差し引く）
        let effectiveWidth = chartWidth > 0 ? max(chartWidth - 40, 200) : max(chartHeight * 1.2, 300)
        // 各バーに割り当てられるピクセル（バー間の余白込み）
        let pixelsPerBar = effectiveWidth / CGFloat(count)
        // バー幅はピクセルの60%、残り40%は間隔
        let width = min(max(pixelsPerBar * 0.6, 2), 24)
        return .fixed(width)
    }

    @ViewBuilder
    private var chartBody: some View {
        let isStep = graphMode == .step
        let isBar = graphMode == .bar
        // 折れ線モード: データが少ない時はlinear（catmullRomは3点未満でオーバーシュートする）
        let interpolation: InterpolationMethod = isStep
            ? .stepEnd
            : (visibleEntries.count >= 4 ? .catmullRom : .linear)

        Chart {
            ForEach(visibleEntries, id: \.id) { entry in
                let rawScore = entry.maxScore == yAxisMax
                    ? Double(entry.score)
                    : entry.scaledScore(to: yAxisMax)
                let displayScore = min(rawScore, Double(yAxisMax))

                if isBar {
                    // 棒グラフモード
                    BarMark(
                        x: .value("日時", entry.createdAt),
                        y: .value("スコア", displayScore),
                        width: barWidth
                    )
                    .foregroundStyle(
                        themeColors.color(for: Int(displayScore.rounded()), maxScore: yAxisMax).gradient
                    )
                    .cornerRadius(3)
                } else {
                    // 折れ線/ステップモード
                    LineMark(
                        x: .value("日時", entry.createdAt),
                        y: .value("スコア", displayScore)
                    )
                    .foregroundStyle(themeColors.graphLine)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(interpolation)

                    AreaMark(
                        x: .value("日時", entry.createdAt),
                        y: .value("スコア", displayScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeColors.graphLine.opacity(0.2), themeColors.graphLine.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(interpolation)

                    PointMark(
                        x: .value("日時", entry.createdAt),
                        y: .value("スコア", displayScore)
                    )
                    .foregroundStyle(
                        isStep
                            ? themeColors.color(for: Int(displayScore.rounded()), maxScore: yAxisMax)
                            : themeColors.graphLine
                    )
                    .symbolSize(isStep ? 40 : 30)
                }
            }

            // スコア範囲変更の縦線
            ForEach(Array(rangeChangeDates.enumerated()), id: \.offset) { _, change in
                RuleMark(x: .value("範囲変更", change.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .center) {
                        Text("\(change.from)→\(change.to)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5).opacity(0.6))
                            )
                    }
            }
        }
        .chartXScale(domain: visibleDateRange)
        .chartYScale(domain: 1...yAxisMax)
        .chartYAxis {
            AxisMarks(values: yAxisValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel()
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .chartXAxis {
            if let drillLevel {
                switch drillLevel {
                case .year:
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(.caption2, design: .rounded))
                    }
                case .month:
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.day())
                            .font(.system(.caption2, design: .rounded))
                    }
                case .day:
                    AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.hour())
                            .font(.system(.caption2, design: .rounded))
                    }
                }
            } else {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(format: xAxisFormat)
                        .font(.system(.caption2, design: .rounded))
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, proxy: proxy, geometry: geometry)
                    }
                    .gesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                            .onEnded { value in
                                switch value {
                                case .second(true, let drag):
                                    if let location = drag?.location {
                                        handleLongPress(at: location, proxy: proxy, geometry: geometry)
                                    } else {
                                        // ドラッグなしで長押し完了 → lastLongPressLocationを使用
                                        handleLongPress(at: lastLongPressLocation, proxy: proxy, geometry: geometry)
                                    }
                                default:
                                    break
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                lastLongPressLocation = value.location
                            }
                    )
            }
        }
    }

    // MARK: - ジェスチャー

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, 1.0), 10.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let effectiveSpan: TimeInterval
                let maxPanRatio: Double

                if let drillLevel {
                    // ドリルダウン時はレベル範囲でパン制限（±10%）
                    let range = drillLevel.dateRange
                    effectiveSpan = range.upperBound.timeIntervalSince(range.lowerBound)
                    maxPanRatio = 0.1
                } else {
                    guard let first = allFilteredEntries.first?.createdAt,
                          let last = allFilteredEntries.last?.createdAt else { return }
                    let minSpan: TimeInterval = 3 * 24 * 3600
                    let rawSpan = last.timeIntervalSince(first)
                    effectiveSpan = max(rawSpan, minSpan)
                    maxPanRatio = 0.5
                }

                // ドラッグ距離をタイムオフセットに変換
                let dragRatio = -value.translation.width / 300.0
                let offsetChange = dragRatio * (effectiveSpan / scale)
                let newOffset = lastPanOffset + offsetChange

                // データ範囲外にパンしすぎないよう制限
                let maxPan = effectiveSpan * maxPanRatio
                panOffset = min(max(newOffset, -maxPan), maxPan)
            }
            .onEnded { _ in
                lastPanOffset = panOffset
            }
    }

    // MARK: - ヘルパー

    private var yAxisValues: [Int] {
        switch yAxisMax {
        case ...10: return [1, 3, 5, 7, 10]
        case ...30: return [1, 5, 10, 15, 20, 25, 30]
        default: return [1, 20, 40, 60, 80, 100]
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        timeScale.dateFormat
    }

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let xPosition = location.x - frame.origin.x

        guard let date: Date = proxy.value(atX: xPosition) else { return }

        // ドリルダウンモード: year/monthレベルではonDrillTapを呼ぶ
        if let drillLevel, let onDrillTap {
            switch drillLevel {
            case .year, .month:
                onDrillTap(date)
                return
            case .day:
                break // dayレベルはポイントタップにフォールスルー
            }
        }

        // ポイントタップ（通常ビュー or dayレベル）
        guard let onPointTap else { return }
        let closest = visibleEntries.min { a, b in
            abs(a.createdAt.timeIntervalSince(date)) < abs(b.createdAt.timeIntervalSince(date))
        }
        if let closest { onPointTap(closest) }
    }

    /// 長押しでデータポイントを検出してコールバックを呼ぶ
    private func handleLongPress(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let onPointLongPress,
              let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let xPosition = location.x - frame.origin.x

        guard let date: Date = proxy.value(atX: xPosition) else { return }

        let closest = visibleEntries.min { a, b in
            abs(a.createdAt.timeIntervalSince(date)) < abs(b.createdAt.timeIntervalSince(date))
        }
        if let closest { onPointLongPress(closest) }
    }
}

// MARK: - 全画面チャートビュー

/// グラフを全画面で表示するビュー（ドリルダウンナビゲーション対応）
/// 月→日→時の階層でグラフを掘り下げ、横向き表示にも対応
struct FullscreenChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    let entries: [MoodEntry]
    let themeColors: ThemeColors
    let graphMode: GraphMode
    let period: ChartPeriod
    let timeScale: TimeScale
    /// 削除時のコールバック（親ビューのmodelContextで削除する）
    let onDeleteEntry: ((MoodEntry) -> Void)?

    /// 現在のドリルダウンレベル
    @State private var currentLevel: DrillLevel
    /// 戻るナビゲーション用スタック
    @State private var levelHistory: [DrillLevel] = []
    @State private var selectedEntry: MoodEntry?
    @State private var showDetail = false
    /// 削除確認対象エントリ
    @State private var entryToDelete: MoodEntry?

    init(entries: [MoodEntry], themeColors: ThemeColors, graphMode: GraphMode,
         period: ChartPeriod, timeScale: TimeScale = .daily,
         onDeleteEntry: ((MoodEntry) -> Void)? = nil) {
        self.entries = entries
        self.themeColors = themeColors
        self.graphMode = graphMode
        self.period = period
        self.timeScale = timeScale
        self.onDeleteEntry = onDeleteEntry

        // 初期レベル: 期間が長い場合は年レベル、それ以外は月レベル
        let cal = Calendar.current
        let now = Date()
        let initialLevel: DrillLevel
        switch period {
        case .year, .all:
            initialLevel = .year(cal.component(.year, from: now))
        default:
            initialLevel = .month(
                cal.component(.year, from: now),
                cal.component(.month, from: now)
            )
        }
        _currentLevel = State(initialValue: initialLevel)
    }

    var body: some View {
        GeometryReader { geometry in
            let headerHeight: CGFloat = 56
            let detailHeight: CGFloat = (showDetail && isDayLevel) ? 90 : 0
            let chartHeight = max(geometry.size.height - headerHeight - detailHeight - 32, 200)

            ZStack {
                themeColors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // ヘッダーバー
                    headerBar
                        .frame(height: headerHeight)
                        .padding(.horizontal)

                    // チャート（ドリルダウン対応）
                    ZoomableChartContainer(
                        entries: entries,
                        themeColors: themeColors,
                        period: period,
                        graphMode: graphMode,
                        timeScale: timeScale,
                        drillLevel: currentLevel,
                        onPointTap: { entry in
                            selectedEntry = entry
                            showDetail = true
                            HapticManager.lightFeedback()
                        },
                        onDrillTap: { date in
                            handleDrillTap(date)
                        },
                        onPointLongPress: { entry in
                            entryToDelete = entry
                            HapticManager.recordFeedback()
                        },
                        chartHeight: chartHeight,
                        chartWidth: geometry.size.width - 32
                    )
                    .id(currentLevel)
                    .padding(.horizontal)

                    Spacer(minLength: 0)

                    // エントリ詳細カード（dayレベルのみ）
                    if isDayLevel, showDetail, let entry = selectedEntry {
                        fullscreenDetailCard(entry: entry)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3), value: showDetail)
        .animation(.easeInOut(duration: 0.3), value: currentLevel)
        .statusBarHidden()
        .onAppear {
            NamiAppDelegate.allowLandscape = true
        }
        .alert("この記録を削除しますか？", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let entry = entryToDelete {
                    onDeleteEntry?(entry)
                    if selectedEntry?.id == entry.id {
                        withAnimation {
                            showDetail = false
                            selectedEntry = nil
                        }
                    }
                    entryToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            if let entry = entryToDelete {
                Text("\(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute()) のスコア \(entry.score) を削除します")
            }
        }
    }

    /// 現在のレベルがdayかどうか
    private var isDayLevel: Bool {
        if case .day = currentLevel { return true }
        return false
    }

    // MARK: - ヘッダーバー

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            // 戻るボタン（履歴がある or 親レベルがある場合のみ）
            if !levelHistory.isEmpty || currentLevel.parent != nil {
                Button {
                    goBack()
                    HapticManager.lightFeedback()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(themeColors.accent)
                }
            } else {
                Color.clear.frame(width: 60)
            }

            Spacer()

            // レベルヘッダー
            Text(currentLevel.headerText)
                .font(.system(.headline, design: .rounded, weight: .bold))

            Spacer()

            // 閉じるボタン
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: - ドリルダウンナビゲーション

    /// タップされた日付に基づいて次のレベルへドリルダウン
    private func handleDrillTap(_ date: Date) {
        let cal = Calendar.current
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentLevel {
            case .year:
                let y = cal.component(.year, from: date)
                let m = cal.component(.month, from: date)
                levelHistory.append(currentLevel)
                currentLevel = .month(y, m)
            case .month:
                let y = cal.component(.year, from: date)
                let m = cal.component(.month, from: date)
                let d = cal.component(.day, from: date)
                levelHistory.append(currentLevel)
                currentLevel = .day(y, m, d)
            case .day:
                break // dayレベルではポイントタップで処理
            }
            showDetail = false
            selectedEntry = nil
        }
    }

    /// 前のレベルに戻る
    private func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let previous = levelHistory.popLast() {
                currentLevel = previous
            } else if let parent = currentLevel.parent {
                currentLevel = parent
            }
            showDetail = false
            selectedEntry = nil
        }
    }

    // MARK: - エントリ詳細カード

    @ViewBuilder
    private func fullscreenDetailCard(entry: MoodEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.score)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(themeColors.color(for: entry.score, maxScore: entry.maxScore))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                    .font(.system(.caption, design: .rounded))
                if let memo = entry.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    showDetail = false
                    selectedEntry = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }
}

#Preview("空データ") {
    GraphView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}

#Preview("1日複数記録テスト") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MoodEntry.self, configurations: config)

    // テストデータ: 1日に複数回記録 + 複数日にまたがるデータ
    let cal = Calendar.current
    let today = Date()

    // 今日: 5回記録（密集テスト）
    for i in 0..<5 {
        let date = cal.date(byAdding: .hour, value: -i * 3, to: today)!
        let entry = MoodEntry(score: Int.random(in: 3...9), memo: "テストメモ\(i)", createdAt: date)
        container.mainContext.insert(entry)
    }
    // 過去7日間: 各日2〜3回
    for day in 1...7 {
        let baseDate = cal.date(byAdding: .day, value: -day, to: today)!
        for hour in [8, 14, 21] {
            let date = cal.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: baseDate)!
            let entry = MoodEntry(score: Int.random(in: 2...10), createdAt: date)
            container.mainContext.insert(entry)
        }
    }
    // 過去30日間: 各日1〜2回
    for day in 8...30 {
        let baseDate = cal.date(byAdding: .day, value: -day, to: today)!
        let date = cal.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate)!
        let entry = MoodEntry(score: Int.random(in: 1...10), createdAt: date)
        container.mainContext.insert(entry)
    }

    return GraphView()
        .modelContainer(container)
        .environment(\.themeManager, ThemeManager())
}
