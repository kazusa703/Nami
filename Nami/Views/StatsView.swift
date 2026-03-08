//
//  StatsView.swift
//  Nami
//
//  統計画面 - 平均スコア、連続日数、スコア分布等を表示する
//

import Charts
import StoreKit
import SwiftData
import SwiftUI

// MARK: - Stats Range

/// 統計の分析対象期間
enum StatsRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "全期間"

    var id: String {
        rawValue
    }

    var label: String {
        rawValue
    }

    /// Returns the start date for filtering, nil means no filter (all data)
    var startDate: Date? {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: .now)
        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -6, to: now)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            return nil
        }
    }
}

// MARK: - Section IDs & Titles

/// Identifiers for each stats section (used for scroll-to and TOC)
enum StatsSectionID: String, CaseIterable, Identifiable {
    case todayTips
    case insights
    case health
    case weather
    case weeklyReview
    case monthlyReview
    case proMonthlyReport
    case moodRhythm
    case summaryCards
    case distribution
    case average
    case pastComparison
    case weekdayAverage
    case timeOfDay
    case streak
    case yearInPixels
    case calendarHeatmap
    case tagAnalysis
    case premiumAnalytics
    case discovery
    case activity

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .todayTips: "今日のヒント"
        case .insights: "インサイト"
        case .health: "ヘルスケアと気分"
        case .weather: "天気と気分"
        case .weeklyReview: "先週のふりかえり"
        case .monthlyReview: "先月のふりかえり"
        case .proMonthlyReport: ReportFormat.titleMonthSummary
        case .moodRhythm: "あなたの1週間のリズム"
        case .summaryCards: "サマリー"
        case .distribution: "スコア分布"
        case .average: "平均スコア"
        case .pastComparison: "あの頃の自分と比較"
        case .weekdayAverage: "曜日別平均"
        case .timeOfDay: "時間帯別平均"
        case .streak: "ストリーク"
        case .yearInPixels: "365日グリッド"
        case .calendarHeatmap: "月間カレンダー"
        case .tagAnalysis: "タグ分析"
        case .premiumAnalytics: "高度な分析"
        case .discovery: "発見"
        case .activity: "アクティビティ"
        }
    }

    var icon: String {
        switch self {
        case .todayTips: "lightbulb"
        case .insights: "sparkles"
        case .health: "heart.text.square"
        case .weather: "cloud.sun"
        case .weeklyReview: "calendar.badge.checkmark"
        case .monthlyReview: "calendar.badge.checkmark"
        case .proMonthlyReport: "chart.bar.doc.horizontal"
        case .moodRhythm: "waveform.path.ecg"
        case .summaryCards: "square.grid.2x2"
        case .distribution: "chart.bar"
        case .average: "number"
        case .pastComparison: "calendar.badge.clock"
        case .weekdayAverage: "calendar"
        case .timeOfDay: "clock"
        case .streak: "flame"
        case .yearInPixels: "square.grid.3x3.fill"
        case .calendarHeatmap: "calendar"
        case .tagAnalysis: "tag"
        case .premiumAnalytics: "chart.xyaxis.line"
        case .discovery: "binoculars"
        case .activity: "chart.line.uptrend.xyaxis"
        }
    }
}

/// 統計画面
/// 週間/月間/年間の平均スコア、スコア分布、連続記録日数を表示する
struct StatsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    @State private var statsVM = StatsViewModel()
    /// 全件リスト表示フラグ
    @State private var showAllEntries = false
    /// セクション折りたたみ状態
    @State private var expandedSections: Set<String> = ["weekday", "timeOfDay", "streak", "pastComparison"]
    /// メモ編集シートの対象エントリ
    @State private var editingEntry: MoodEntry?
    /// シェアサマリーシート表示フラグ
    @State private var showShareSummary = false
    /// タグ影響分析シート表示フラグ
    @State private var showTagImpactSheet = false
    /// キーワード検索テキスト
    @State private var searchText = ""
    /// デバウンス済み検索テキスト
    @State private var debouncedSearchText = ""
    /// 検索デバウンス用タスク
    @State private var searchDebounceTask: Task<Void, Never>?

    /// 現在のスコア範囲上限
    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10
    /// 現在のスコア範囲下限
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1

    /// プレミアム状態
    @Environment(\.premiumManager) private var premiumManager
    /// HealthKit連携
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @Environment(\.healthKitManager) private var healthKitManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var healthData: [DailyHealthData] = []
    @State private var healthDataLoaded = false
    @State private var healthRefreshID = 0
    /// 月間サマリーの表示月
    @State private var summaryMonth: Date = .now
    /// プレミアム購入シート表示
    @State private var showPremiumSheet = false
    /// PDF export share sheet
    @State private var showPDFShareSheet = false
    @State private var exportedPDFURL: URL?
    /// PDF export month selection dialog
    @State private var showPDFExportDialog = false
    /// Table of contents sheet
    @State private var showTOCSheet = false
    /// Scroll target for TOC jump
    @State private var scrollTarget: StatsSectionID?
    /// Range picker selection
    @State private var selectedRange: StatsRange = .all

    /// Entries filtered by the selected range
    private var filteredEntries: [MoodEntry] {
        guard let start = selectedRange.startDate else { return entries }
        return entries.filter { $0.createdAt >= start }
    }

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                if entries.isEmpty {
                                    emptyStatsView(colors: colors)
                                } else {
                                    // Range picker
                                    AnyView(rangePickerView(colors: colors))
                                    AnyView(insufficientDataBanner(colors: colors))

                                    if filteredEntries.isEmpty {
                                        AnyView(rangeEmptyView(colors: colors))
                                    } else {
                                        // AnyViewで型消去し、LazyVStackで遅延描画（スタックオーバーフロー防止）
                                        let count = filteredEntries.count

                                        AnyView(todayTipsSection(colors: colors))
                                            .id(StatsSectionID.todayTips)
                                        AnyView(insightCarousel(colors: colors))
                                            .id(StatsSectionID.insights)
                                        if healthKitEnabled {
                                            if !healthData.isEmpty {
                                                AnyView(HealthStatsSection(
                                                    healthData: healthData,
                                                    entries: filteredEntries,
                                                    themeColors: colors,
                                                    currentMax: currentMaxScore,
                                                    currentMin: currentMinScore
                                                ))
                                                .id(StatsSectionID.health)
                                            } else if healthDataLoaded {
                                                AnyView(healthEmptyCard(colors: colors))
                                            }
                                        }
                                        if filteredEntries.contains(where: { $0.weatherCondition != nil }) {
                                            AnyView(WeatherStatsSection(
                                                entries: filteredEntries,
                                                themeColors: colors,
                                                currentMax: currentMaxScore,
                                                currentMin: currentMinScore
                                            ))
                                            .id(StatsSectionID.weather)
                                        }
                                        AnyView(weeklyReviewSection(colors: colors))
                                            .id(StatsSectionID.weeklyReview)
                                        AnyView(monthlyReviewSection(colors: colors))
                                            .id(StatsSectionID.monthlyReview)
                                        AnyView(proMonthlyReportCard(colors: colors))
                                            .id(StatsSectionID.proMonthlyReport)
                                        AnyView(moodRhythmSection(colors: colors))
                                            .id(StatsSectionID.moodRhythm)
                                        AnyView(summaryCards(colors: colors))
                                            .id(StatsSectionID.summaryCards)
                                        AnyView(distributionSection(colors: colors))
                                            .id(StatsSectionID.distribution)
                                        AnyView(averageSection(colors: colors))
                                            .id(StatsSectionID.average)
                                        if count >= 3 {
                                            AnyView(pastComparisonSection(colors: colors))
                                                .id(StatsSectionID.pastComparison)
                                            AnyView(weekdayAverageSection(colors: colors))
                                                .id(StatsSectionID.weekdayAverage)
                                            AnyView(timeOfDaySection(colors: colors))
                                                .id(StatsSectionID.timeOfDay)
                                        }
                                        AnyView(streakSection(colors: colors))
                                            .id(StatsSectionID.streak)
                                        AnyView(yearInPixelsSection(colors: colors))
                                            .id(StatsSectionID.yearInPixels)
                                        AnyView(calendarHeatmapSection(colors: colors))
                                            .id(StatsSectionID.calendarHeatmap)
                                        if filteredEntries.contains(where: { !$0.tags.isEmpty }) {
                                            AnyView(tagAnalysisSection(colors: colors))
                                                .id(StatsSectionID.tagAnalysis)
                                        }
                                        if count >= 3 {
                                            AnyView(premiumAnalyticsSection(colors: colors))
                                                .id(StatsSectionID.premiumAnalytics)
                                            AnyView(discoverySection(colors: colors))
                                                .id(StatsSectionID.discovery)
                                        }
                                        AnyView(activitySection(colors: colors))
                                            .id(StatsSectionID.activity)
                                    }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: scrollTarget) { _, target in
                            guard let target else { return }
                            scrollTarget = nil
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollProxy.scrollTo(target, anchor: .top)
                            }
                        }
                    }

                    // 広告バナー（画面最下部に固定）
                    BannerAdView(showRemoveLink: true) {
                        showPremiumSheet = true
                    }
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTOCSheet = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(.body, design: .rounded))
                    }
                    .disabled(entries.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSummary = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(.body, design: .rounded))
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showAllEntries) {
                allEntriesView(colors: colors)
            }
            .sheet(isPresented: $showTagImpactSheet) {
                TagImpactSheet(
                    entries: entries,
                    currentMaxScore: currentMaxScore,
                    currentMinScore: currentMinScore,
                    themeColors: themeManager.colors
                )
            }
            .sheet(isPresented: $showShareSummary) {
                ShareSummaryView(
                    entries: entries,
                    currentMaxScore: currentMaxScore,
                    themeColors: themeManager.colors,
                    statsVM: statsVM
                )
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumPaywallView()
            }
            .sheet(isPresented: $showPDFShareSheet) {
                if let url = exportedPDFURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(item: $editingEntry) { entry in
                MemoInputView(
                    score: entry.score,
                    maxScore: entry.maxScore,
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
            .sheet(isPresented: $showTOCSheet) {
                statsTOCSheet(colors: colors)
            }
            .task(id: "\(healthKitEnabled)-\(healthRefreshID)") {
                guard healthKitEnabled else {
                    healthData = []
                    healthDataLoaded = false
                    return
                }
                let start = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
                healthData = await healthKitManager.fetchDailyData(for: start ... Date())
                healthDataLoaded = true
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && healthKitEnabled {
                    healthRefreshID += 1
                }
            }
        }
    }

    // MARK: - Table of Contents

    /// Compute which sections are currently visible based on data conditions
    private var visibleSections: [StatsSectionID] {
        guard !entries.isEmpty, !filteredEntries.isEmpty else { return [] }
        let count = filteredEntries.count
        var sections: [StatsSectionID] = []

        sections.append(.todayTips)
        sections.append(.insights)
        if healthKitEnabled, !healthData.isEmpty {
            sections.append(.health)
        }
        if filteredEntries.contains(where: { $0.weatherCondition != nil }) {
            sections.append(.weather)
        }
        sections.append(.weeklyReview)
        sections.append(.monthlyReview)
        sections.append(.proMonthlyReport)
        sections.append(.moodRhythm)
        sections.append(.summaryCards)
        sections.append(.distribution)
        sections.append(.average)
        if count >= 3 {
            sections.append(.pastComparison)
            sections.append(.weekdayAverage)
            sections.append(.timeOfDay)
        }
        sections.append(.streak)
        sections.append(.yearInPixels)
        sections.append(.calendarHeatmap)
        if filteredEntries.contains(where: { !$0.tags.isEmpty }) {
            sections.append(.tagAnalysis)
        }
        if count >= 3 {
            sections.append(.premiumAnalytics)
            sections.append(.discovery)
        }
        sections.append(.activity)
        return sections
    }

    /// TOC sheet view
    private func statsTOCSheet(colors _: ThemeColors) -> some View {
        NavigationStack {
            List(visibleSections) { section in
                Button {
                    showTOCSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollTarget = section
                    }
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("目次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        showTOCSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - ヘルスケアデータなしカード

    private func healthEmptyCard(colors _: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(.pink)
                Text("ヘルスケアと気分")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            Text("ヘルスケアデータが見つかりません。iPhoneを持ち歩くか、Apple Watchを使用すると歩数や睡眠データが自動で記録されます。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("データが許可されていない場合は、設定 > ヘルスケア > データアクセスとデバイス > Nami で確認してください。")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Range Picker

    /// Period range selector (matches CalendarHeatmapView style)
    private func rangePickerView(colors: ThemeColors) -> some View {
        HStack(spacing: 6) {
            ForEach(StatsRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                    HapticManager.lightFeedback()
                } label: {
                    Text(range.label)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? colors.accent : Color(.systemGray5).opacity(0.8))
                        )
                        .foregroundStyle(selectedRange == range ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Banner shown when filtered data has fewer than 20 entries
    @ViewBuilder
    private func insufficientDataBanner(colors: ThemeColors) -> some View {
        if selectedRange != .all && filteredEntries.count < 20 && !filteredEntries.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(colors.accent)
                Text("この期間のデータは\(filteredEntries.count)件です。20件以上でより正確な分析になります。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colors.accent.opacity(0.06))
            )
        }
    }

    /// Shown when the selected range has zero entries but total entries exist
    private func rangeEmptyView(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(colors.accent.opacity(0.4))

            Text("この期間にはデータがありません")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Text("別の期間を選択するか、「全期間」に切り替えてください")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - 空状態ビュー

    /// データ0件時に「記録すると何がわかるか」を案内するビュー
    private func emptyStatsView(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(colors.accent.opacity(0.4))

            Text("記録を始めると、\nあなたの気分のパターンが見えてきます")
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            // 機能プレビューカード
            VStack(spacing: 12) {
                featurePreviewRow(
                    icon: "brain.head.profile",
                    title: "AIインサイト",
                    description: "あなただけの気付きを自動で発見",
                    colors: colors
                )
                featurePreviewRow(
                    icon: "calendar",
                    title: "曜日・時間帯の傾向",
                    description: "何曜日が好調か、時間帯ごとの波を分析",
                    colors: colors
                )
                featurePreviewRow(
                    icon: "tag",
                    title: "タグの影響分析",
                    description: "どの活動や感情がスコアに影響するか",
                    colors: colors
                )
                featurePreviewRow(
                    icon: "chart.bar",
                    title: "スコア分布",
                    description: "自分の気分の全体像を可視化",
                    colors: colors
                )
                featurePreviewRow(
                    icon: "flame",
                    title: "連続記録ストリーク",
                    description: "毎日の記録習慣をトラッキング",
                    colors: colors
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )

            Text("「記録」タブから最初の1件を記録してみましょう")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer().frame(height: 20)
        }
    }

    /// 機能プレビュー行
    private func featurePreviewRow(icon: String, title: String, description: String, colors: ThemeColors) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(colors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - 今日のヒントセクション

    @ViewBuilder
    private func todayTipsSection(colors: ThemeColors) -> some View {
        let tips = InsightEngine.generateDailyTips(
            from: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore
        )
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .foregroundStyle(.yellow)
                    Text(StatsSectionID.todayTips.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                ForEach(tips) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: tip.icon)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(colors.accent)
                            .frame(width: 16)
                        Text(tip.text)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        }
    }

    // MARK: - インサイトカルーセル

    @ViewBuilder
    private func insightCarousel(colors: ThemeColors) -> some View {
        let insights = InsightEngine.generate(from: filteredEntries, currentMax: currentMaxScore)

        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(StatsSectionID.insights.title)
                        .font(.system(.headline, design: .rounded))
                }
                .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(insights) { card in
                            insightCardView(card: card, colors: colors)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    /// インサイトカード1枚のビュー
    private func insightCardView(card: InsightCard, colors _: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: card.icon)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(card.tone.color)

                Text(card.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            }

            Text(card.body)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 270, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(card.tone.color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 週間レビューセクション

    @ViewBuilder
    private func weeklyReviewSection(colors: ThemeColors) -> some View {
        if let review = statsVM.weeklyReview(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore) {
            VStack(alignment: .leading, spacing: 14) {
                // ヘッダー
                weeklyReviewHeader(review: review)

                // サマリー
                Text(review.summary)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                // 平均スコア + 前週比
                weeklyReviewAverageRow(review: review, colors: colors)

                // ハイライト & ローポイント
                weeklyReviewHighlights(review: review, colors: colors)

                // Top タグ
                if !review.topTags.isEmpty {
                    weeklyReviewTopTags(tags: review.topTags, colors: colors)
                }

                // 記録回数
                Text("\(review.entryCount)回記録しました")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colors.accent.opacity(0.15), lineWidth: 1)
            )
        }
    }

    /// 週間レビューのヘッダー
    @ViewBuilder
    private func weeklyReviewHeader(review: WeeklyReview) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "book.pages.fill")
                .foregroundStyle(.indigo)
            Text(StatsSectionID.weeklyReview.title)
                .font(.system(.headline, design: .rounded))
        }

        let startText = review.weekStart.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
        let endText = review.weekEnd.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
        Text("\(startText) 〜 \(endText)")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
    }

    /// 平均スコア行（前週比付き）
    private func weeklyReviewAverageRow(review: WeeklyReview, colors: ThemeColors) -> some View {
        HStack {
            Text("平均スコア")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "%.1f", review.average))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: Int(review.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))

            if let prev = review.previousWeekAverage {
                let diff = review.average - prev
                weeklyReviewDiffBadge(diff: diff)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.accent.opacity(0.06))
        )
    }

    /// 前週比バッジ
    private func weeklyReviewDiffBadge(diff: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: abs(diff) < 0.05 ? "equal" : (diff > 0 ? "arrow.up.right" : "arrow.down.right"))
                .font(.caption2)
            Text(String(format: "%+.1f", diff))
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .foregroundColor(abs(diff) < 0.05 ? Color.secondary : (diff > 0 ? Color.green : Color.orange))
    }

    /// ハイライト & ローポイントの表示
    @ViewBuilder
    private func weeklyReviewHighlights(review: WeeklyReview, colors: ThemeColors) -> some View {
        let showBoth = review.highlight != nil && review.lowPoint != nil
            && review.highlight?.date != review.lowPoint?.date

        HStack(spacing: 10) {
            if let highlight = review.highlight {
                reviewPointCard(
                    label: "ハイライト", icon: "arrow.up.circle.fill",
                    iconColor: .green, point: highlight, colors: colors
                )
            }
            if showBoth, let low = review.lowPoint {
                reviewPointCard(
                    label: "ローポイント", icon: "arrow.down.circle.fill",
                    iconColor: .orange, point: low, colors: colors
                )
            }
        }
    }

    /// ハイライト/ローポイントカード1枚
    private func reviewPointCard(label: String, icon: String, iconColor: Color, point: WeeklyReviewPoint, colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text("\(point.score)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(colors.color(for: point.score, maxScore: currentMaxScore, minScore: currentMinScore))

                VStack(alignment: .leading, spacing: 2) {
                    Text(point.date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.abbreviated)))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let memo = point.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(iconColor.opacity(0.06))
        )
    }

    /// Top タグ表示
    private func weeklyReviewTopTags(tags: [(tag: String, count: Int)], colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("よく使ったタグ")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(tags, id: \.tag) { item in
                    HStack(spacing: 3) {
                        Text(item.tag)
                            .font(.system(.caption, design: .rounded))
                        Text("\(item.count)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                    .foregroundStyle(colors.accent)
                }
            }
        }
    }

    // MARK: - 月間レビューセクション（無料 - 先月のみ）

    @ViewBuilder
    private func monthlyReviewSection(colors: ThemeColors) -> some View {
        let calendar = Calendar.current
        let thisMonthStart = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart

        let lastMonthSummary = statsVM.monthlySummary(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore, month: lastMonth)

        if let summary = lastMonthSummary, summary.entryCount >= 3 {
            let summaryText = statsVM.generateMonthlySummaryText(summary: summary, currentMax: currentMaxScore)
            let tagHighlights = statsVM.monthlyTagHighlights(entries: filteredEntries, currentMax: currentMaxScore, month: lastMonth)

            VStack(alignment: .leading, spacing: 14) {
                // Header
                monthlyReviewHeader(summary: summary)

                // Summary text
                Text(summaryText)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                // Average score + previous month diff
                monthlyReviewAverageRow(summary: summary, colors: colors)

                // Best / Worst day
                monthlyReviewHighlights(summary: summary, colors: colors)

                // Top 3 tags as capsule chips
                if !tagHighlights.isEmpty {
                    monthlyReviewTagChips(highlights: Array(tagHighlights.prefix(3)), colors: colors)
                }

                // Best weekday
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("最も好調: \(summary.weekdayBest)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Entry counts
                Text("\(summary.activeDays)日間に\(summary.entryCount)回記録しました")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colors.accent.opacity(0.15), lineWidth: 1)
            )
        } else if let summary = lastMonthSummary, summary.entryCount > 0 {
            // Not enough data for full review
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(colors.accent)
                    Text("先月のふりかえり")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Spacer()
                }
                Text("先月の記録は\(summary.entryCount)件です。3件以上でふりかえりが表示されます。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// Monthly review header
    @ViewBuilder
    private func monthlyReviewHeader(summary: MonthlySummary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .foregroundStyle(.indigo)
            Text(StatsSectionID.monthlyReview.title)
                .font(.system(.headline, design: .rounded))
        }

        let monthText = summary.month.formatted(.dateTime.year().month(.wide))
        Text(monthText)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
    }

    /// Monthly average row with previous month diff badge
    private func monthlyReviewAverageRow(summary: MonthlySummary, colors: ThemeColors) -> some View {
        HStack {
            Text("平均スコア")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "%.1f", summary.average))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: Int(summary.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))

            if let prev = summary.previousMonthAverage {
                let diff = summary.average - prev
                HStack(spacing: 2) {
                    Image(systemName: abs(diff) < 0.05 ? "equal" : (diff > 0 ? "arrow.up.right" : "arrow.down.right"))
                        .font(.caption2)
                    Text(String(format: "%+.1f", diff))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .foregroundColor(abs(diff) < 0.05 ? Color.secondary : (diff > 0 ? Color.green : Color.orange))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.accent.opacity(0.06))
        )
    }

    /// Monthly review best/worst mini cards
    @ViewBuilder
    private func monthlyReviewHighlights(summary: MonthlySummary, colors: ThemeColors) -> some View {
        let showBoth = summary.bestDay != nil && summary.worstDay != nil
            && summary.bestDay?.date != summary.worstDay?.date

        HStack(spacing: 10) {
            if let best = summary.bestDay {
                miniDayCard(label: "ベストの日", score: best.score, date: best.date, memo: best.memo, iconColor: .green, colors: colors)
            }
            if showBoth, let worst = summary.worstDay {
                miniDayCard(label: "ワーストの日", score: worst.score, date: worst.date, memo: worst.memo, iconColor: .orange, colors: colors)
            }
        }
    }

    /// Monthly tag highlight chips
    private func monthlyReviewTagChips(highlights: [StatsViewModel.MonthlyTagHighlight], colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("よく使ったタグ")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(highlights, id: \.tag) { item in
                    HStack(spacing: 3) {
                        Text(item.tag)
                            .font(.system(.caption, design: .rounded))
                        Text("\(item.count)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                    .foregroundStyle(colors.accent)
                }
            }
        }
    }

    // MARK: - ムードリズムセクション

    @ViewBuilder
    private func moodRhythmSection(colors: ThemeColors) -> some View {
        let rhythmData = statsVM.weeklyRhythmData(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let hasRhythmData = rhythmData.contains { $0.average > 0 }

        if hasRhythmData {
            VStack(alignment: .leading, spacing: 16) {
                Text(StatsSectionID.moodRhythm.title)
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 4)

                // 週間リズム波線チャート
                weeklyRhythmChart(rhythmData: rhythmData, colors: colors)

                // ボラティリティ推移
                let volData = statsVM.volatilityTrend(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore)
                if volData.count >= 4 {
                    volatilityChart(volData: volData, colors: colors)
                }
            }
        }
    }

    /// 週間リズム波線チャート（月〜日の平均を滑らかな波で表示）
    private func weeklyRhythmChart(rhythmData: [(label: String, index: Int, average: Double)], colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(rhythmData, id: \.index) { item in
                    if item.average > 0 {
                        LineMark(
                            x: .value("曜日", item.label),
                            y: .value("平均", item.average)
                        )
                        .foregroundStyle(colors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("曜日", item.label),
                            y: .value("平均", item.average)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colors.accent.opacity(0.25), colors.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("曜日", item.label),
                            y: .value("平均", item.average)
                        )
                        .foregroundStyle(colors.color(for: Int(item.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
                        .symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f", item.average))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.color(for: Int(item.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
                        }
                    }
                }
            }
            .chartYScale(domain: Double(currentMinScore) ... Double(currentMaxScore))
            .chartYAxis {
                AxisMarks(values: [Double(currentMinScore), Double(currentMaxScore)]) { _ in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .rounded))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
            }
            .frame(height: 180)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )

            // 高低の曜日をテキストで補足
            let validData = rhythmData.filter { $0.average > 0 }
            if let best = validData.max(by: { $0.average < $1.average }),
               let worst = validData.min(by: { $0.average < $1.average }),
               best.label != worst.label
            {
                HStack(spacing: 12) {
                    Label("\(best.label)が最高", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(worst.label)が最低", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .padding(.horizontal, 4)
            }
        }
    }

    /// ボラティリティ推移チャート（週ごとの標準偏差 = 気分の安定度）
    @ViewBuilder
    private func volatilityChart(volData: [(weekStart: Date, stdDev: Double)], colors: ThemeColors) -> some View {
        let trendInfo = computeVolatilityTrend(volData: volData)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("気分の安定度")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                Spacer()

                // 直近の傾向バッジ
                if let info = trendInfo {
                    volatilityTrendBadge(info: info)
                }
            }
            .padding(.horizontal, 4)

            Text("低いほど気分が安定 ・ 高いほど波が大きい")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            // 直近8週分のチャート
            volatilityLineChart(volData: volData, colors: colors)
        }
    }

    /// ボラティリティ傾向を計算
    private func computeVolatilityTrend(volData: [(weekStart: Date, stdDev: Double)]) -> (label: String, icon: String, color: Color)? {
        guard volData.count >= 4 else { return nil }
        let recentSlice = Array(volData.suffix(2))
        let earlierSlice = Array(volData.dropLast(2).suffix(2))
        guard !recentSlice.isEmpty, !earlierSlice.isEmpty else { return nil }

        let recent = recentSlice.map(\.stdDev).reduce(0, +) / Double(recentSlice.count)
        let earlier = earlierSlice.map(\.stdDev).reduce(0, +) / Double(earlierSlice.count)
        let trend = recent - earlier

        if trend < -0.2 {
            return (String(localized: "安定化"), "checkmark.circle.fill", .green)
        } else if trend > 0.2 {
            return (String(localized: "不安定"), "exclamationmark.circle.fill", .orange)
        } else {
            return (String(localized: "横ばい"), "equal.circle.fill", .secondary)
        }
    }

    /// ボラティリティ傾向バッジ
    private func volatilityTrendBadge(info: (label: String, icon: String, color: Color)) -> some View {
        HStack(spacing: 3) {
            Image(systemName: info.icon)
                .font(.caption2)
            Text(info.label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(info.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(info.color.opacity(0.12)))
    }

    /// ボラティリティ折れ線チャート
    @ViewBuilder
    private func volatilityLineChart(volData: [(weekStart: Date, stdDev: Double)], colors: ThemeColors) -> some View {
        let recentData = Array(volData.suffix(8))
        let maxStd = recentData.map(\.stdDev).max() ?? 1.0
        let yMax = maxStd * 1.3
        let accentColor = colors.accent

        Chart {
            ForEach(recentData, id: \.weekStart) { item in
                LineMark(
                    x: .value("週", item.weekStart),
                    y: .value("変動幅", item.stdDev)
                )
                .foregroundStyle(accentColor.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("週", item.weekStart),
                    y: .value("変動幅", item.stdDev)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor.opacity(0.15), accentColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("週", item.weekStart),
                    y: .value("変動幅", item.stdDev)
                )
                .foregroundStyle(accentColor)
                .symbolSize(25)
            }
        }
        .chartYScale(domain: 0 ... yMax)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .frame(height: 120)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - サマリーカード（2×2グリッド）

    @ViewBuilder
    private func summaryCards(colors: ThemeColors) -> some View {
        let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        LazyVGrid(columns: gridColumns, spacing: 12) {
            // 合計記録回数
            statCard(
                title: "合計記録",
                value: "\(statsVM.totalCount(entries: entries))",
                subtitle: "回",
                icon: "pencil.line",
                colors: colors
            )

            // 連続記録日数
            statCard(
                title: "ストリーク",
                value: "\(statsVM.currentStreak(entries: entries))",
                subtitle: "日連続",
                icon: "flame",
                colors: colors
            )

            // 最高スコア
            if let highest = statsVM.highestScore(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore) {
                statCard(
                    title: "最高スコア",
                    value: "\(highest.score)",
                    subtitle: highest.date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)),
                    icon: "arrow.up.circle",
                    colors: colors
                )
            }

            // 最低スコア
            if let lowest = statsVM.lowestScore(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore) {
                statCard(
                    title: "最低スコア",
                    value: "\(lowest.score)",
                    subtitle: lowest.date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)),
                    icon: "arrow.down.circle",
                    colors: colors
                )
            }
        }
    }

    // MARK: - スコア分布セクション

    @ViewBuilder
    private func distributionSection(colors: ThemeColors) -> some View {
        let distribution = statsVM.scoreDistribution(entries: filteredEntries, maxScore: currentMaxScore, minScore: currentMinScore)

        VStack(alignment: .leading, spacing: 12) {
            // Mood balance pie chart
            moodBalancePieChart(distribution: distribution, colors: colors)

            HStack {
                Text(StatsSectionID.distribution.title)
                    .font(.system(.headline, design: .rounded))

                Spacer()

                // モード値の表示
                if let mode = statsVM.mostCommonScore(entries: filteredEntries, currentMax: currentMaxScore) {
                    Text("最多: \(mode)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(colors.accent.opacity(0.15)))
                        .foregroundStyle(colors.accent)
                }
            }
            .padding(.horizontal, 4)

            // 横棒グラフ
            let maxCount = max(distribution.values.max() ?? 0, 1)

            // 分布が大きい場合はグルーピング表示
            if currentMaxScore > 30 {
                groupedDistributionChart(distribution: distribution, maxCount: maxCount, colors: colors)
            } else {
                Chart {
                    ForEach(currentMinScore ... currentMaxScore, id: \.self) { score in
                        let count = distribution[score] ?? 0
                        BarMark(
                            x: .value("回数", count),
                            y: .value("スコア", "\(score)")
                        )
                        .foregroundStyle(colors.color(for: score, maxScore: currentMaxScore, minScore: currentMinScore).gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXScale(domain: 0 ... (maxCount + 1))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                }
                .frame(height: CGFloat(currentMaxScore - currentMinScore + 1) * 28)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    /// 大きなレンジの場合のグルーピング分布チャート
    @ViewBuilder
    private func groupedDistributionChart(distribution: [Int: Int], maxCount _: Int, colors: ThemeColors) -> some View {
        let groupSize = 10
        let groups = stride(from: currentMinScore, through: currentMaxScore, by: groupSize).map { start -> (label: String, count: Int) in
            let end = min(start + groupSize - 1, currentMaxScore)
            let count = (start ... end).reduce(0) { $0 + (distribution[$1] ?? 0) }
            return ("\(start)-\(end)", count)
        }
        let groupMax = max(groups.map(\.count).max() ?? 0, 1)

        Chart {
            ForEach(groups, id: \.label) { group in
                BarMark(
                    x: .value("回数", group.count),
                    y: .value("スコア", group.label)
                )
                .foregroundStyle(colors.accent.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, spacing: 4) {
                    if group.count > 0 {
                        Text("\(group.count)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXScale(domain: 0 ... (groupMax + 1))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
        }
        .frame(height: 280)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Mood Balance Pie Chart

    /// Mood balance pie chart showing positive / neutral / negative ratio
    @ViewBuilder
    private func moodBalancePieChart(distribution: [Int: Int], colors: ThemeColors) -> some View {
        let range = max(currentMaxScore - currentMinScore, 1)
        let lowThreshold = currentMinScore + Int(Double(range) * 0.33)
        let highThreshold = currentMinScore + Int(Double(range) * 0.66)

        let counts = distribution.reduce(into: (pos: 0, neu: 0, neg: 0)) { result, pair in
            if pair.key > highThreshold {
                result.pos += pair.value
            } else if pair.key >= lowThreshold {
                result.neu += pair.value
            } else {
                result.neg += pair.value
            }
        }
        let total = counts.pos + counts.neu + counts.neg

        if total > 0 {
            let posRatio = Double(counts.pos) / Double(total)
            let neuRatio = Double(counts.neu) / Double(total)
            let negRatio = Double(counts.neg) / Double(total)

            VStack(alignment: .leading, spacing: 12) {
                Text("気分バランス")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 4)

                HStack(spacing: 20) {
                    Chart {
                        SectorMark(angle: .value("ポジティブ", counts.pos), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(colors.highScoreColor)
                        SectorMark(angle: .value("ふつう", counts.neu), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(colors.accent.opacity(0.5))
                        SectorMark(angle: .value("ネガティブ", counts.neg), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(colors.lowScoreColor)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: 10) {
                        moodBalanceLegendRow(color: colors.highScoreColor, label: "ポジティブ", count: counts.pos, ratio: posRatio)
                        moodBalanceLegendRow(color: colors.accent.opacity(0.5), label: "ふつう", count: counts.neu, ratio: neuRatio)
                        moodBalanceLegendRow(color: colors.lowScoreColor, label: "ネガティブ", count: counts.neg, ratio: negRatio)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// Legend row for mood balance pie chart
    private func moodBalanceLegendRow(color: Color, label: String, count: Int, ratio: Double) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                HStack(spacing: 4) {
                    Text("\(count)回")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("(\(Int(ratio * 100))%)")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 平均スコアセクション

    private func averageSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(StatsSectionID.average.title)
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 4)

            // 週間平均
            averageRow(
                label: "今週",
                current: statsVM.weeklyAverage(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore),
                previous: statsVM.lastWeekAverage(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore),
                previousLabel: "先週",
                colors: colors
            )

            // 月間平均
            averageRow(
                label: "今月",
                current: statsVM.monthlyAverage(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore),
                previous: statsVM.lastMonthAverage(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore),
                previousLabel: "先月",
                colors: colors
            )

            // 年間平均
            if let yearAvg = statsVM.yearlyAverage(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore) {
                HStack {
                    Text("今年")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", yearAvg))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(colors.accent)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - あの頃の自分と比較セクション

    @ViewBuilder
    private func pastComparisonSection(colors: ThemeColors) -> some View {
        let comparison = statsVM.pastComparison(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore)

        if comparison.hasLastYearData {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(StatsSectionID.pastComparison.title, sectionKey: "pastComparison", icon: "calendar.badge.clock")

                if expandedSections.contains("pastComparison") {
                    VStack(spacing: 10) {
                        // 今週 vs 1年前の同じ週
                        if let lyWeek = comparison.lastYearSameWeekAvg {
                            pastComparisonRow(
                                label: "1年前の同じ週",
                                current: comparison.currentWeekAvg,
                                past: lyWeek,
                                colors: colors
                            )
                        }

                        // 今月 vs 1年前の同じ月
                        if let lyMonth = comparison.lastYearSameMonthAvg {
                            pastComparisonRow(
                                label: "1年前の同じ月",
                                current: comparison.currentMonthAvg,
                                past: lyMonth,
                                colors: colors
                            )
                        }

                        // 今年 vs 去年
                        if let lyYear = comparison.lastYearAvg {
                            pastComparisonRow(
                                label: "去年",
                                current: comparison.currentYearAvg,
                                past: lyYear,
                                colors: colors
                            )
                        }

                        // 励ましメッセージ
                        if let message = comparison.growthMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(colors.accent)
                                Text(message)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colors.accent.opacity(0.08))
                            )
                        }
                    }
                }
            }
        }
    }

    /// 過去比較の行ビュー
    private func pastComparisonRow(label: String, current: Double?, past: Double, colors: ThemeColors) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Spacer()

            // 1年前スコア
            Text(String(format: "%.1f", past))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // 現在スコア
            if let current {
                Text(String(format: "%.1f", current))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(colors.accent)

                // 差分
                let diff = current - past
                HStack(spacing: 2) {
                    Image(systemName: abs(diff) < 0.05 ? "equal" : (diff > 0 ? "arrow.up.right" : "arrow.down.right"))
                        .font(.system(size: 9))
                    Text(String(format: "%+.1f", diff))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                }
                .foregroundColor(abs(diff) < 0.05 ? Color.secondary : (diff > 0 ? Color.green : Color.orange))
                .frame(width: 50, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer().frame(width: 50)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - 折りたたみセクションヘッダー

    private func collapsibleHeader(_ title: String, sectionKey: String, icon: String? = nil) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedSections.contains(sectionKey) {
                    expandedSections.remove(sectionKey)
                } else {
                    expandedSections.insert(sectionKey)
                }
            }
        } label: {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Image(systemName: expandedSections.contains(sectionKey) ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    // MARK: - 曜日別平均セクション

    private func weekdayAverageSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(StatsSectionID.weekdayAverage.title, sectionKey: "weekday")

            if expandedSections.contains("weekday") {
                let averages = statsVM.weekdayAverages(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore)
                // 月〜日の順（2=月, 3=火, ..., 7=土, 1=日）
                let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
                let weekdayLabels = [String(localized: "月曜"), String(localized: "火曜"), String(localized: "水曜"), String(localized: "木曜"), String(localized: "金曜"), String(localized: "土曜"), String(localized: "日曜")]

                Chart {
                    ForEach(Array(weekdayOrder.enumerated()), id: \.offset) { index, weekday in
                        let avg = averages[weekday] ?? 0
                        BarMark(
                            x: .value("曜日", weekdayLabels[index]),
                            y: .value("平均", avg)
                        )
                        .foregroundStyle(
                            avg > 0
                                ? colors.color(for: Int(avg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore).gradient
                                : Color.gray.opacity(0.3).gradient
                        )
                        .cornerRadius(6)
                    }
                }
                .chartYScale(domain: Double(min(0, currentMinScore)) ... Double(currentMaxScore))
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.system(.caption2, design: .rounded))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                }
                .frame(height: 180)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            } // end if expandedSections weekday
        }
    }

    // MARK: - 時間帯別平均セクション

    private func timeOfDaySection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(StatsSectionID.timeOfDay.title, sectionKey: "timeOfDay")

            if expandedSections.contains("timeOfDay") {
                let averages = statsVM.timeOfDayAverages(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore)
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(TimeOfDay.allCases) { tod in
                        let avg = averages[tod]

                        VStack(spacing: 8) {
                            Image(systemName: tod.icon)
                                .font(.title2)
                                .foregroundStyle(colors.accent)

                            Text(tod.label)
                                .font(.system(.caption, design: .rounded, weight: .semibold))

                            if let avg {
                                Text(String(format: "%.1f", avg))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.color(for: Int(avg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
                            } else {
                                Text("-")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(tod.timeRange)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
            } // end if expandedSections timeOfDay
        }
    }

    // MARK: - ストリーク比較セクション

    private func streakSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(StatsSectionID.streak.title, sectionKey: "streak")

            if expandedSections.contains("streak") {
                let current = statsVM.currentStreak(entries: entries)
                let longest = statsVM.longestStreak(entries: entries)

                HStack(spacing: 12) {
                    // 現在のストリーク
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(colors.accent)

                        Text("\(current)")
                            .font(.system(.title, design: .rounded, weight: .bold))

                        Text("現在")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("日連続")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )

                    // 最長ストリーク
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.title)
                            .foregroundStyle(colors.accent)

                        Text("\(longest)")
                            .font(.system(.title, design: .rounded, weight: .bold))

                        Text("最長記録")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("日連続")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }

                // 現在のストリークが最長と等しいかそれ以上の場合のバッジ
                if current > 0 && current >= longest {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("自己ベスト更新中！")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(colors.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(colors.accent.opacity(0.12))
                    )
                    .frame(maxWidth: .infinity)
                }
            } // end if expandedSections streak
        }
    }

    // MARK: - 365日グリッドセクション

    private func yearInPixelsSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(StatsSectionID.yearInPixels.title)
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 4)

            YearInPixelsView(
                entries: entries,
                themeColors: colors
            )
        }
    }

    // MARK: - カレンダーヒートマップセクション

    private func calendarHeatmapSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(StatsSectionID.calendarHeatmap.title)
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 4)

            MonthlyHeatmapView(
                entries: entries,
                currentMaxScore: currentMaxScore,
                currentMinScore: currentMinScore,
                colors: colors
            )
        }
    }

    // MARK: - タグ分析セクション

    private func tagAnalysisSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(StatsSectionID.tagAnalysis.title)
                    .font(.system(.headline, design: .rounded))

                Spacer()

                // タグの影響を見るボタン
                Button {
                    showTagImpactSheet = true
                    HapticManager.lightFeedback()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                        Text("影響を見る")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(colors.accent.opacity(0.12)))
                    .foregroundStyle(colors.accent)
                }
            }
            .padding(.horizontal, 4)

            // 1. タグ使用頻度
            tagFrequencyChart(colors: colors)

            // 2. タグ別平均スコア
            tagAverageScoreChart(colors: colors)

            // 3. 翌日効果
            nextDayEffectList(colors: colors)

            // 4. タグ共起パターン
            tagCoOccurrenceList(colors: colors)
        }
    }

    /// タグ使用頻度の横棒グラフ
    @ViewBuilder
    private func tagFrequencyChart(colors: ThemeColors) -> some View {
        let frequency = statsVM.tagFrequency(entries: filteredEntries)
        let top10 = Array(frequency.prefix(10))

        if !top10.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("タグ使用頻度")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 4)

                Chart {
                    ForEach(top10, id: \.tag) { item in
                        BarMark(
                            x: .value("回数", item.count),
                            y: .value("タグ", item.tag)
                        )
                        .foregroundStyle(colors.accent.gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text("\(item.count)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(.caption, design: .rounded))
                    }
                }
                .frame(height: CGFloat(top10.count) * 32)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    /// タグ別平均スコアの横棒グラフ
    @ViewBuilder
    private func tagAverageScoreChart(colors: ThemeColors) -> some View {
        let averages = statsVM.tagAverageScores(entries: filteredEntries, currentMax: currentMaxScore)
        let top10 = Array(averages.prefix(10))

        if !top10.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("タグ別平均スコア")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 4)

                Chart {
                    ForEach(top10, id: \.tag) { item in
                        BarMark(
                            x: .value("平均", item.average),
                            y: .value("タグ", item.tag)
                        )
                        .foregroundStyle(colors.color(for: Int(item.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore).gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text(String(format: "%.1f", item.average))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXScale(domain: 0 ... Double(currentMaxScore))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(.caption, design: .rounded))
                    }
                }
                .frame(height: CGFloat(top10.count) * 32)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    /// 翌日効果リスト
    @ViewBuilder
    private func nextDayEffectList(colors _: ThemeColors) -> some View {
        let effects = statsVM.nextDayEffect(entries: filteredEntries, currentMax: currentMaxScore)

        if !effects.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("翌日効果")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 4)

                Text("タグ使用日の翌日スコアと平均との差")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(effects.prefix(8), id: \.tag) { item in
                        HStack {
                            Text(item.tag)
                                .font(.system(.subheadline, design: .rounded))

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: item.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption2)
                                Text(String(format: "%+.1f", item.delta))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(item.delta >= 0 ? .green : .orange)

                            Text("(\(item.sampleSize)日)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)

                        if item.tag != effects.prefix(8).last?.tag {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    /// タグ共起パターンリスト
    @ViewBuilder
    private func tagCoOccurrenceList(colors: ThemeColors) -> some View {
        let coOccurrence = statsVM.tagCoOccurrence(entries: filteredEntries)
        let top5 = Array(coOccurrence.prefix(5))

        if !top5.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("タグ共起パターン")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(top5.enumerated()), id: \.offset) { _, item in
                        HStack {
                            HStack(spacing: 4) {
                                Text(item.tag1)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(colors.accent.opacity(0.1)))

                                Text("&")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(item.tag2)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                            }

                            Spacer()

                            Text("\(item.count)回")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }

    // MARK: - 発見セクション（隠れた相関）

    @ViewBuilder
    private func discoverySection(colors: ThemeColors) -> some View {
        let hasEnoughData = entries.count >= 20

        if hasEnoughData {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(colors.accent)
                    Text(StatsSectionID.discovery.title)
                        .font(.system(.headline, design: .rounded))
                }
                .padding(.horizontal, 4)

                // 記録回数とスコアの関係
                recordCountDiscovery(colors: colors)

                // タグ使用とスコアの関係
                tagUsageDiscovery(colors: colors)

                // 詳細な共起パターン
                detailedCoOccurrenceDiscovery(colors: colors)
            }
        }
    }

    /// 記録回数とスコアの関係
    @ViewBuilder
    private func recordCountDiscovery(colors: ThemeColors) -> some View {
        if let data = statsVM.recordCountVsScore(entries: filteredEntries, currentMax: currentMaxScore) {
            let delta = data.multiAvg - data.singleAvg
            discoveryCard(
                icon: "square.and.pencil",
                iconColor: .blue,
                title: "記録回数 → スコア",
                colors: colors
            ) {
                HStack(spacing: 0) {
                    discoveryStatColumn(
                        label: "複数回/日",
                        value: String(format: "%.1f", data.multiAvg),
                        sub: "\(data.multiDays)日",
                        valueColor: colors.color(for: Int(data.multiAvg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore)
                    )
                    discoveryStatColumn(
                        label: "1回/日",
                        value: String(format: "%.1f", data.singleAvg),
                        sub: "\(data.singleDays)日",
                        valueColor: colors.color(for: Int(data.singleAvg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore)
                    )
                    discoveryDeltaColumn(delta: delta)
                }
            }
        }
    }

    /// タグ使用とスコアの関係
    @ViewBuilder
    private func tagUsageDiscovery(colors: ThemeColors) -> some View {
        if let data = statsVM.tagUsageVsScore(entries: filteredEntries, currentMax: currentMaxScore) {
            let delta = data.taggedAvg - data.untaggedAvg
            discoveryCard(
                icon: "tag.fill",
                iconColor: .purple,
                title: "タグで自己理解",
                colors: colors
            ) {
                HStack(spacing: 0) {
                    discoveryStatColumn(
                        label: "タグあり",
                        value: String(format: "%.1f", data.taggedAvg),
                        sub: "\(data.taggedCount)件",
                        valueColor: colors.color(for: Int(data.taggedAvg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore)
                    )
                    discoveryStatColumn(
                        label: "タグなし",
                        value: String(format: "%.1f", data.untaggedAvg),
                        sub: "\(data.untaggedCount)件",
                        valueColor: colors.color(for: Int(data.untaggedAvg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore)
                    )
                    discoveryDeltaColumn(delta: delta)
                }
            }
        }
    }

    /// 詳細な共起パターン
    @ViewBuilder
    private func detailedCoOccurrenceDiscovery(colors: ThemeColors) -> some View {
        let pairs = statsVM.detailedCoOccurrence(entries: filteredEntries)

        if !pairs.isEmpty {
            discoveryCard(
                icon: "link",
                iconColor: .green,
                title: "よく一緒に使うタグ",
                colors: colors
            ) {
                VStack(spacing: 8) {
                    ForEach(pairs.prefix(3), id: \.tag1) { pair in
                        HStack {
                            HStack(spacing: 4) {
                                Text(pair.tag1)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                                Text("&")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(pair.tag2)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                            }

                            Spacer()

                            Text("共起率\(pair.rate)%")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    /// 発見カードのラッパー
    private func discoveryCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        colors _: ThemeColors,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }

            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    /// 発見カード内のスタットカラム
    private func discoveryStatColumn(label: String, value: String, sub: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
            Text(sub)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 発見カード内の差分カラム
    private func discoveryDeltaColumn(delta: Double) -> some View {
        VStack(spacing: 2) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
            Text(String(format: "%+.1f", delta))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
        }
        .foregroundStyle(delta >= 0 ? .green : .orange)
        .frame(width: 50)
    }

    // MARK: - プレミアム分析セクション

    @ViewBuilder
    private func premiumAnalyticsSection(colors: ThemeColors) -> some View {
        let hasEnoughData = entries.count >= 20
        if hasEnoughData {
            VStack(alignment: .leading, spacing: 16) {
                // セクションヘッダー
                premiumSectionHeader(colors: colors)

                if premiumManager.isPremium {
                    // --- フル表示 ---
                    premiumInsightCarousel(colors: colors)
                    tagInfluenceCard(colors: colors)
                    weatherCorrelationCard(colors: colors)
                    reverseInsightsCard(colors: colors)
                    monthlySummaryCard(colors: colors)
                    tagChainCard(colors: colors)
                    tagEchoCard(colors: colors)
                    divergenceAlertCard(colors: colors)
                    recoveryTriggerCard(colors: colors)
                    synergyCard(colors: colors)
                } else {
                    // --- ロック表示 ---
                    premiumLockedPreview(colors: colors)
                }
            }
        }
    }

    /// プレミアムセクションヘッダー
    private func premiumSectionHeader(colors: ThemeColors) -> some View {
        HStack(spacing: 6) {
            Image(systemName: premiumManager.isPremium ? "sparkles" : "lock.fill")
                .foregroundStyle(premiumManager.isPremium ? colors.accent : .purple)
            Text(StatsSectionID.premiumAnalytics.title)
                .font(.system(.headline, design: .rounded))
            if !premiumManager.isPremium {
                Text("PRO")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.purple))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 4)
    }

    /// ロック表示（無料ユーザー向け — 件数ティーザー付き）
    @ViewBuilder
    private func premiumLockedPreview(colors: ThemeColors) -> some View {
        // Use only lightweight counts to avoid heavy computation for free users
        let taggedCount = entries.filter { !$0.tags.isEmpty }.count
        let weatherCount = entries.filter { $0.weatherCondition != nil }.count

        VStack(spacing: 12) {
            // Unlock CTA
            Button {
                showPremiumSheet = true
                HapticManager.lightFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(.caption, design: .rounded))
                    Text("タップして全機能を解放")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.purple.opacity(0.8))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Capsule().fill(.purple.opacity(0.08)))
            }
            .buttonStyle(.plain)

            if selectedRange != .all {
                Text("全期間（\(entries.count)件）のデータに基づく例")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            lockedPreviewCard(
                icon: "percent",
                title: "タグ影響度",
                preview: "各タグが気分に与える影響を定量化...",
                teaser: taggedCount >= 3 ? "タグデータから影響度を分析できます" : nil,
                colors: colors
            )
            lockedPreviewCard(
                icon: "cloud.sun.fill",
                title: "天気・気圧相関",
                preview: "天気や気圧が気分に与える影響を分析...",
                teaser: weatherCount > 0 ? "\(weatherCount)件の天気データを収集済み" : "天気データを集めると相関を分析します",
                colors: colors
            )
            lockedPreviewCard(
                icon: "brain.head.profile",
                title: "逆インサイト",
                preview: "好調時に多いタグ、不在タグを分析...",
                teaser: taggedCount >= 30 ? "十分なデータでパターンを分析できます" : nil,
                colors: colors
            )
            lockedPreviewCard(
                icon: "calendar.badge.clock",
                title: "月間サマリーレポート",
                preview: "月ごとの詳細な振り返り...",
                teaser: "あなた専用のレポートが準備できています",
                colors: colors
            )
            lockedPreviewCard(
                icon: "arrow.triangle.branch",
                title: "タグ連鎖パターン",
                preview: "タグの遷移パターンを可視化...",
                teaser: taggedCount >= 10 ? "タグの遷移パターンを分析できます" : nil,
                colors: colors
            )
            lockedPreviewCard(
                icon: "waveform.path.ecg",
                title: "残響効果",
                preview: "タグの影響が何日続くか計測...",
                teaser: taggedCount >= 10 ? "タグの残響効果を計測できます" : nil,
                colors: colors
            )
            lockedPreviewCard(
                icon: "exclamationmark.triangle",
                title: "乖離アラート",
                preview: "行動とスコアのズレを検出...",
                teaser: entries.count >= 20 ? "行動とスコアのズレを分析できます" : nil,
                colors: colors
            )
            lockedPreviewCard(
                icon: "heart.circle",
                title: "回復トリガー",
                preview: "落ち込みから回復するきっかけ...",
                teaser: entries.count >= 20 ? "回復のきっかけを分析できます" : nil,
                colors: colors
            )
            lockedPreviewCard(
                icon: "arrow.triangle.merge",
                title: "タグシナジー",
                preview: "相乗効果と危険な組み合わせ...",
                teaser: taggedCount >= 20 ? "タグの組み合わせ効果を分析できます" : nil,
                colors: colors
            )

            // 購入ボタン
            Button {
                showPremiumSheet = true
                HapticManager.lightFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                    Text("プレミアムで解放")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// ロックプレビューカード1枚（件数ティーザー付き）
    private func lockedPreviewCard(icon: String, title: String, preview: String, teaser: String?, colors: ThemeColors) -> some View {
        Button {
            showPremiumSheet = true
            HapticManager.lightFeedback()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(colors.accent)
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                Text(preview)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .blur(radius: 4)

                if let teaser {
                    Text(teaser)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.purple)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - プレミアムインサイトカルーセル

    @ViewBuilder
    private func premiumInsightCarousel(colors: ThemeColors) -> some View {
        let insights = InsightEngine.generatePremium(from: filteredEntries, currentMax: currentMaxScore)
        if !insights.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights) { card in
                        insightCardView(card: card, colors: colors)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 天気相関カード

    @ViewBuilder
    private func weatherCorrelationCard(colors: ThemeColors) -> some View {
        let weatherCount = statsVM.weatherDataCount(entries: filteredEntries)
        let conditionAvgs = statsVM.weatherConditionAverages(entries: filteredEntries, currentMax: currentMaxScore)
        let pressure = statsVM.pressureCorrelation(entries: filteredEntries, currentMax: currentMaxScore)

        if weatherCount >= 5 && (!conditionAvgs.isEmpty || pressure != nil) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundStyle(.blue)
                    Text("天気・気圧と気分")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Spacer()
                    Text("\(weatherCount)件")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // 天気別の平均スコア棒グラフ
                if !conditionAvgs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("天気別の気分")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(conditionAvgs.prefix(6)), id: \.condition) { item in
                            HStack(spacing: 8) {
                                Text(weatherIcon(for: item.condition))
                                    .frame(width: 20)
                                Text(item.condition)
                                    .font(.system(.caption, design: .rounded))
                                    .frame(width: 60, alignment: .leading)

                                GeometryReader { geo in
                                    let ratio = item.averageScore / Double(currentMaxScore)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(colors.color(for: Int(item.averageScore.rounded()), maxScore: currentMaxScore, minScore: currentMinScore).gradient)
                                        .frame(width: geo.size.width * max(ratio, 0.05))
                                }
                                .frame(height: 14)

                                Text(String(format: "%.1f", item.averageScore))
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(colors.color(for: Int(item.averageScore.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
                                    .frame(width: 28, alignment: .trailing)

                                Text("(\(item.entryCount))")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 28)
                            }
                        }
                    }
                }

                // 気圧帯別の比較
                if let p = pressure {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("気圧帯別の気分")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 0) {
                            if p.lowCount >= 2 {
                                pressureColumn(
                                    label: "低気圧",
                                    sublabel: "<1006hPa",
                                    avg: p.lowPressureAvg,
                                    count: p.lowCount,
                                    icon: "arrow.down",
                                    colors: colors
                                )
                            }
                            if p.normalCount >= 2 {
                                pressureColumn(
                                    label: "通常",
                                    sublabel: "1006-1020",
                                    avg: p.normalPressureAvg,
                                    count: p.normalCount,
                                    icon: "equal",
                                    colors: colors
                                )
                            }
                            if p.highCount >= 2 {
                                pressureColumn(
                                    label: "高気圧",
                                    sublabel: ">1020hPa",
                                    avg: p.highPressureAvg,
                                    count: p.highCount,
                                    icon: "arrow.up",
                                    colors: colors
                                )
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        } else if weatherCount > 0 && weatherCount < 5 {
            // データ不足時のメッセージ
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .foregroundStyle(.blue)
                    Text("天気・気圧と気分")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("天気データを集めています... (\(weatherCount)/5件)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// 気圧帯カラム
    private func pressureColumn(label: String, sublabel: String, avg: Double, count: Int, icon: String, colors: ThemeColors) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", avg))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: Int(avg.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
            Text(sublabel)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
            Text("\(count)件")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    /// 天気名からアイコン絵文字へのマッピング
    private func weatherIcon(for condition: String) -> String {
        switch condition {
        case "晴れ", "ほぼ晴れ": return "☀️"
        case "やや曇り": return "⛅"
        case "ほぼ曇り", "曇り": return "☁️"
        case "雨", "小雨": return "🌧️"
        case "大雨": return "⛈️"
        case "雪", "大雪", "にわか雪": return "🌨️"
        case "雷雨", "局地雷雨", "散発雷雨": return "⚡"
        case "霧", "もや": return "🌫️"
        case "強風", "微風": return "💨"
        case "猛暑": return "🔥"
        case "極寒": return "🥶"
        case "天気雨": return "🌦️"
        default: return "🌤️"
        }
    }

    // MARK: - タグ影響度カード

    @ViewBuilder
    private func tagInfluenceCard(colors: ThemeColors) -> some View {
        let influences = statsVM.tagInfluencePercentage(entries: filteredEntries, currentMax: currentMaxScore)
        if !influences.isEmpty {
            let upFactors = Array(influences.filter { $0.influencePercent > 0 }.prefix(5))
            let downFactors = Array(influences.filter { $0.influencePercent < 0 }.prefix(5))

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "percent")
                        .foregroundStyle(.cyan)
                    Text("タグ影響度")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                // 気分アップ要因
                if !upFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("気分アップ要因")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                        ForEach(upFactors, id: \.tag) { item in
                            influenceRow(item: item, isPositive: true, colors: colors)
                        }
                    }
                }

                // 気分ダウン要因
                if !downFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("気分ダウン要因")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                        ForEach(downFactors, id: \.tag) { item in
                            influenceRow(item: item, isPositive: false, colors: colors)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// 影響度行
    private func influenceRow(item: TagInfluence, isPositive: Bool, colors _: ThemeColors) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
                .foregroundStyle(isPositive ? .green : .orange)
                .frame(width: 14)

            Text(item.tag)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text(String(format: "%+.1f%%", item.influencePercent))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(isPositive ? .green : .orange)

            // 信頼度バッジ
            HStack(spacing: 2) {
                Image(systemName: item.confidence.icon)
                    .font(.system(size: 8))
                Text(item.confidence.label)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(item.confidence.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(item.confidence.color.opacity(0.12)))
        }
        .padding(.vertical, 2)
    }

    // MARK: - A. 逆インサイトカード

    @ViewBuilder
    private func reverseInsightsCard(colors: ThemeColors) -> some View {
        let data = statsVM.reverseInsights(entries: filteredEntries, currentMax: currentMaxScore)
        let hasData = !data.highTags.isEmpty || !data.lowTags.isEmpty
        if hasData {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("逆インサイト")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                // 好調時に多いタグ / 好調時に少ないタグ
                HStack(alignment: .top, spacing: 12) {
                    if !data.highTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("好調時に多いタグ")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.green)
                            ForEach(data.highTags.prefix(5), id: \.tag) { item in
                                tagRateBadge(tag: item.tag, rate: item.rate, color: .green, colors: colors)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !data.highAbsentTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("好調時に少ないタグ")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.blue)
                            ForEach(data.highAbsentTags, id: \.tag) { item in
                                tagRateBadge(tag: item.tag, rate: item.rate, color: .blue, colors: colors)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // 不調時に多いタグ
                if !data.lowTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("不調時に多いタグ")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.orange)
                        HStack(spacing: 6) {
                            ForEach(data.lowTags.prefix(5), id: \.tag) { item in
                                tagRateBadge(tag: item.tag, rate: item.rate, color: .orange, colors: colors)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// タグ+出現率バッジ
    private func tagRateBadge(tag: String, rate: Int, color: Color, colors _: ThemeColors) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(.caption, design: .rounded))
            Text("\(rate)%")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.1)))
    }

    // MARK: - B. 月間サマリーカード

    private func monthlySummaryCard(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // ヘッダー + 月セレクター
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.indigo)
                Text("月間サマリー")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        summaryMonth = Calendar.current.date(byAdding: .month, value: -1, to: summaryMonth) ?? summaryMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                    }
                    Text(summaryMonth.formatted(.dateTime.year().month(.wide)))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Button {
                        let next = Calendar.current.date(byAdding: .month, value: 1, to: summaryMonth) ?? summaryMonth
                        if next <= Date.now { summaryMonth = next }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .disabled(Calendar.current.isDate(summaryMonth, equalTo: .now, toGranularity: .month))
                }
            }

            if let summary = statsVM.monthlySummary(entries: filteredEntries, currentMax: currentMaxScore, currentMin: currentMinScore, month: summaryMonth) {
                // 平均 + 前月比
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("平均スコア")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f", summary.average))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(colors.color(for: Int(summary.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
                            if let prev = summary.previousMonthAverage {
                                let diff = summary.average - prev
                                HStack(spacing: 2) {
                                    Image(systemName: abs(diff) < 0.05 ? "equal" : (diff > 0 ? "arrow.up.right" : "arrow.down.right"))
                                        .font(.caption2)
                                    Text(String(format: "%+.1f", diff))
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                }
                                .foregroundColor(abs(diff) < 0.05 ? Color.secondary : (diff > 0 ? Color.green : Color.orange))
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("記録日数")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(summary.activeDays)日")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(colors.accent.opacity(0.06)))

                // ベスト/ワースト (same day → show best only)
                let showBothDays = summary.bestDay != nil && summary.worstDay != nil
                    && summary.bestDay?.date != summary.worstDay?.date
                HStack(spacing: 10) {
                    if let best = summary.bestDay {
                        miniDayCard(label: "ベストの日", score: best.score, date: best.date, memo: best.memo, iconColor: .green, colors: colors)
                    }
                    if showBothDays, let worst = summary.worstDay {
                        miniDayCard(label: "ワーストの日", score: worst.score, date: worst.date, memo: worst.memo, iconColor: .orange, colors: colors)
                    }
                }

                // Topタグ + ポジ/ネガ率 + 安定度
                HStack(spacing: 12) {
                    if !summary.topTags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Topタグ")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(summary.topTags.prefix(3), id: \.tag) { item in
                                HStack(spacing: 4) {
                                    Text(item.tag)
                                        .font(.system(.caption, design: .rounded))
                                    Text("\(item.count)")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ポジティブタグ率")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        monthlySummaryRatioBar(posRate: summary.positiveTagRate, negRate: summary.negativeTagRate, colors: colors)
                        HStack(spacing: 4) {
                            Text("安定度")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", summary.volatility))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(summary.volatility < 1.5 ? .green : (summary.volatility < 2.5 ? .orange : .red))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 最も好調な曜日
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("最も好調: \(summary.weekdayBest)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Tag correlation highlights
                monthlySummaryTagCorrelation(month: summaryMonth, colors: colors)

                // Weather trend (if data exists)
                monthlySummaryWeatherTrend(month: summaryMonth, colors: colors)

                // PDF export button
                Button {
                    exportMonthlyPDF(month: summaryMonth, summary: summary, colors: colors)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        Text("PDFレポートを出力")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(colors.accent))
                }
                .padding(.top, 4)
            } else {
                Text("この月のデータがありません")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - PDF Export

    /// Count entries in a given month (for prev month availability check)
    private func prevMonthEntryCount(prevMonth: Date) -> Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: prevMonth) else { return 0 }
        return entries.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }.count
    }

    /// Generate and export PDF for the previous month
    private func exportPreviousMonthPDF(prevMonth: Date, colors: ThemeColors) {
        guard let summary = statsVM.monthlySummary(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore, month: prevMonth) else { return }
        exportMonthlyPDF(month: prevMonth, summary: summary, colors: colors)
    }

    /// Generate and share a monthly summary PDF report
    private func exportMonthlyPDF(month: Date, summary: MonthlySummary, colors: ThemeColors) {
        let tagHighlights = statsVM.monthlyTagHighlights(entries: entries, currentMax: currentMaxScore, month: month)

        // Phase 1-2 PRO data (only if >= 10 entries in target month)
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: month)
        let monthEntryCount = monthInterval.map { iv in
            entries.filter { $0.createdAt >= iv.start && $0.createdAt < iv.end }.count
        } ?? 0

        let tagDiffs: (positive: [StatsViewModel.TagScoreDiff], negative: [StatsViewModel.TagScoreDiff])?
        let comp: StatsViewModel.MonthlyComparison?
        let outlierList: [StatsViewModel.MonthlyOutlier]?

        if monthEntryCount >= 10 {
            tagDiffs = statsVM.tagScoreDifferences(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore, month: month)
            comp = statsVM.monthlyComparison(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore, month: month)
            outlierList = statsVM.monthlyOutliers(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore, month: month)
        } else {
            tagDiffs = nil
            comp = nil
            outlierList = nil
        }

        let pdfView = MonthlyPDFReportView(
            summary: summary,
            tagHighlights: tagHighlights,
            currentMaxScore: currentMaxScore,
            currentMinScore: currentMinScore,
            colors: colors,
            tagScoreDiffs: tagDiffs,
            comparison: comp,
            outliers: outlierList
        )

        // A4 width in points
        let renderer = ImageRenderer(content: pdfView.frame(width: 595))
        renderer.scale = 2.0

        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let monthLabel = dateFormatter.string(from: month)
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let fileName = "nami_report_\(monthLabel)_\(timestamp).pdf"
        let url = tempDir.appendingPathComponent(fileName)

        // PDF metadata
        let pdfInfo: [CFString: Any] = [
            kCGPDFContextTitle: "Nami Monthly Report - \(monthLabel)",
            kCGPDFContextCreator: "Nami",
        ]

        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdfContext = CGContext(url as CFURL, mediaBox: &box, pdfInfo as CFDictionary) else { return }
            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }

        // Only show share sheet if the file was actually created
        if FileManager.default.fileExists(atPath: url.path) {
            exportedPDFURL = url
            showPDFShareSheet = true
        }
    }

    /// Tag correlation display for monthly summary card
    @ViewBuilder
    private func monthlySummaryTagCorrelation(month: Date, colors: ThemeColors) -> some View {
        let highlights = statsVM.monthlyTagHighlights(entries: filteredEntries, currentMax: currentMaxScore, month: month)
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    Text("タグ相関")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(highlights.prefix(5), id: \.tag) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.influence == "ポジティブ" ? "arrow.up.circle.fill" : (item.influence == "ネガティブ" ? "arrow.down.circle.fill" : "minus.circle.fill"))
                            .font(.caption2)
                            .foregroundStyle(item.influence == "ポジティブ" ? .green : (item.influence == "ネガティブ" ? .orange : .gray))

                        Text(item.tag)
                            .font(.system(.caption, design: .rounded))

                        Spacer()

                        Text(String(format: "%.1f", item.averageScore))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(colors.color(for: Int(item.averageScore.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))

                        Text("(\(item.count)回)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(colors.accent.opacity(0.04)))
        }
    }

    /// Weather trend for monthly summary card
    @ViewBuilder
    private func monthlySummaryWeatherTrend(month: Date, colors _: ThemeColors) -> some View {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: month)
        let monthEntries = monthInterval.map { interval in
            filteredEntries.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
        } ?? []
        let weatherEntries = monthEntries.filter { $0.weatherCondition != nil }

        if weatherEntries.count >= 3 {
            let conditionCounts: [String: Int] = weatherEntries.reduce(into: [:]) { counts, e in
                if let c = e.weatherCondition {
                    counts[c, default: 0] += 1
                }
            }
            let sorted = conditionCounts.sorted { $0.value > $1.value }
            let topConditions = sorted.prefix(3).map { "\($0.key)(\($0.value)件)" }.joined(separator: "・")

            HStack(spacing: 4) {
                Image(systemName: "cloud.sun.fill")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
                Text("天気傾向: \(topConditions)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// ポジ/ネガ比率バー
    private func monthlySummaryRatioBar(posRate: Double, negRate: Double, colors _: ThemeColors) -> some View {
        let clampedPos = max(posRate, 0.05)
        let clampedNeg = max(negRate, 0.05)
        let total = clampedPos + clampedNeg
        // Normalize to prevent overflow
        let normPos = clampedPos / total
        let normNeg = clampedNeg / total
        return GeometryReader { geo in
            HStack(spacing: 1) {
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: geo.size.width * normPos)
                Rectangle()
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: geo.size.width * normNeg)
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }

    /// ミニ日カード（ベスト/ワースト用）
    private func miniDayCard(label: String, score: Int, date: Date, memo: String?, iconColor: Color, colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(iconColor)
            HStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(colors.color(for: score, maxScore: currentMaxScore, minScore: currentMinScore))
                VStack(alignment: .leading, spacing: 1) {
                    Text(date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    if let memo, !memo.isEmpty {
                        Text(memo)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.06)))
    }

    // MARK: - C. タグ連鎖パターンカード

    @ViewBuilder
    private func tagChainCard(colors: ThemeColors) -> some View {
        let chains = statsVM.tagChainPatterns(entries: filteredEntries, currentMax: currentMaxScore)
        if !chains.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.teal)
                    Text("タグ連鎖パターン")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                ForEach(Array(chains.prefix(6).enumerated()), id: \.offset) { _, chain in
                    HStack(spacing: 8) {
                        Text(chain.fromTag)
                            .font(.system(.caption, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(colors.accent.opacity(0.1)))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(chain.toTag)
                            .font(.system(.caption, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(colors.accent.opacity(0.1)))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(chain.occurrences)回")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Image(systemName: chain.avgScoreChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 8))
                                Text(String(format: "%+.1f", chain.avgScoreChange))
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(chain.isNegativeLoop ? .red : .green)
                        }
                    }
                    .padding(.vertical, 2)

                    // ラベル
                    if chain.isNegativeLoop {
                        Text("負のループ")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red.opacity(0.1)))
                    } else if chain.avgScoreChange > 0.5 {
                        Text("回復の予兆")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.green.opacity(0.1)))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - D. 残響効果カード

    @ViewBuilder
    private func tagEchoCard(colors: ThemeColors) -> some View {
        let echoes = statsVM.tagEchoEffect(entries: filteredEntries, currentMax: currentMaxScore)
        // ネガティブ影響（初日が負）の上位3つ
        let negativeEchoes = Array(echoes.filter { ($0.dayEffects.first ?? 0) < -0.3 }.prefix(3))
        if !negativeEchoes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.pink)
                    Text("残響効果")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                ForEach(negativeEchoes, id: \.tag) { echo in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(echo.tag)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                            Spacer()
                            Text(echo.recoveryDays < 4 ? String(format: "平均%.0f日で回復", echo.recoveryDays) : "3日以上残る")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        // ミニ折れ線
                        echoMiniChart(effects: echo.dayEffects, colors: colors)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.pink.opacity(0.05)))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// 残響効果ミニ折れ線チャート
    @ViewBuilder
    private func echoMiniChart(effects: [Double], colors _: ThemeColors) -> some View {
        let labels = ["+0日", "+1日", "+2日", "+3日"]
        Chart {
            ForEach(Array(effects.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("日", labels[index]),
                    y: .value("差分", value)
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("日", labels[index]),
                    y: .value("差分", value)
                )
                .foregroundStyle(value < 0 ? .orange : .green)
                .symbolSize(20)
            }

            RuleMark(y: .value("基準", 0))
                .foregroundStyle(.secondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .frame(height: 80)
    }

    // MARK: - E. ズレ検出アラートカード

    @ViewBuilder
    private func divergenceAlertCard(colors _: ThemeColors) -> some View {
        let divergences = statsVM.actionScoreDivergence(entries: filteredEntries, currentMax: currentMaxScore)
        let negDivergences = Array(divergences.filter { $0.divergence < -1.0 }.prefix(3))
        if !negDivergences.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("行動とスコアのズレ")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                Text("隠れた疲れの兆候かもしれません")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)

                ForEach(negDivergences, id: \.tag) { item in
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("「\(item.tag)」")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("最近 \(String(format: "%.1f", item.recentAvg)) vs 通常 \(String(format: "%.1f", item.historicalAvg))")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.1f", item.divergence))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.orange.opacity(0.06)))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - F. 回復トリガーカード

    @ViewBuilder
    private func recoveryTriggerCard(colors _: ThemeColors) -> some View {
        let triggers = statsVM.recoveryTriggers(entries: filteredEntries, currentMax: currentMaxScore)
        if !triggers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.heart.fill")
                        .foregroundStyle(.green)
                    Text("回復トリガー")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                Text("不調からの回復時")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)

                ForEach(Array(triggers.prefix(3)), id: \.tag) { trigger in
                    HStack {
                        Text(trigger.tag)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.green.opacity(0.1)))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("出現率 \(trigger.appearanceRate)%")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.green)
                            Text(String(format: "+%.1f pt", trigger.avgRecoveryBoost))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.green.opacity(0.04)))
                }

                Text("次回の不調時はまずこれを試してみませんか？")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.green.opacity(0.8))
                    .italic()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - G. シナジー/レッドゾーンカード

    @ViewBuilder
    private func synergyCard(colors: ThemeColors) -> some View {
        let synergies = statsVM.tagSynergyAnalysis(entries: filteredEntries, currentMax: currentMaxScore)
        let positive = synergies.filter { $0.synergyDelta > 0 }
        let redZone = synergies.filter { $0.isRedZone }
        if !positive.isEmpty || !redZone.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundStyle(colors.accent)
                    Text("タグシナジー")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                // 相乗効果
                if !positive.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("相乗効果")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                        ForEach(Array(positive.prefix(3).enumerated()), id: \.offset) { _, syn in
                            synergyRow(synergy: syn, accentColor: .green, colors: colors)
                        }
                    }
                }

                // レッドゾーン
                if !redZone.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("レッドゾーン")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.red)
                        ForEach(Array(redZone.prefix(3).enumerated()), id: \.offset) { _, syn in
                            synergyRow(synergy: syn, accentColor: .red, colors: colors)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// シナジー行1つ
    private func synergyRow(synergy: TagSynergy, accentColor: Color, colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(synergy.tag1)
                    .font(.system(.caption, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                Text("+")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(synergy.tag2)
                    .font(.system(.caption, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                Spacer()
                Text(String(format: "%+.1f", synergy.synergyDelta))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            HStack(spacing: 12) {
                Text("単体: \(String(format: "%.1f", synergy.soloAvg1)) / \(String(format: "%.1f", synergy.soloAvg2))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("組み合わせ: \(String(format: "%.1f", synergy.comboAvg))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("(\(synergy.comboCount)回)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(synergy.isRedZone ? 0.06 : 0.03))
        )
    }

    // MARK: - アクティビティセクション

    private func activitySection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(StatsSectionID.activity.title)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    showAllEntries = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(colors.accent)
                }
            }
            .padding(.horizontal, 4)

            // 最近の記録リスト（直近5件）
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(5)), id: \.id) { entry in
                    entryRow(entry: entry, colors: colors)

                    if entry.id != entries.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )

            // 「すべて見る」ボタン
            if entries.count > 5 {
                Button {
                    showAllEntries = true
                } label: {
                    HStack {
                        Text("すべての記録を見る")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                        Spacer()
                        Text("\(entries.count)件")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - エントリ行

    private func entryRow(entry: MoodEntry, colors: ThemeColors) -> some View {
        HStack {
            Text("\(entry.score)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: entry.score, maxScore: entry.maxScore))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                        .font(.system(.subheadline, design: .rounded))

                    // メディアインジケータ
                    if entry.photoPath != nil {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(colors.accent.opacity(0.5))
                    }
                    if entry.voiceMemoPath != nil {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundStyle(colors.accent.opacity(0.5))
                    }
                }

                if let memo = entry.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // タグチップ表示（最大3個 + "+N"）
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
                    .font(.body)
                    .foregroundStyle(colors.accent.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    // MARK: - 全件リスト画面

    @ViewBuilder
    private func allEntriesView(colors: ThemeColors) -> some View {
        let isSearching = !debouncedSearchText.isEmpty
        let searchResults = isSearching ? statsVM.searchEntries(query: debouncedSearchText, entries: entries) : []
        let displayEntries: [MoodEntry] = isSearching ? searchResults.map(\.entry) : entries
        let matchedTagsByEntry: [UUID: [String]] = {
            var dict: [UUID: [String]] = [:]
            for result in searchResults {
                dict[result.entry.id] = result.matchedTags
            }
            return dict
        }()

        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            if isSearching && displayEntries.isEmpty {
                ContentUnavailableView.search(text: debouncedSearchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayEntries, id: \.id) { entry in
                            searchableEntryRow(
                                entry: entry,
                                colors: colors,
                                query: isSearching ? debouncedSearchText : "",
                                matchedTags: matchedTagsByEntry[entry.id] ?? []
                            )

                            if entry.id != displayEntries.last?.id {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding()
                }
            }
        }
        .navigationTitle("すべての記録")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "メモやタグで検索")
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedSearchText = newValue
            }
        }
    }

    /// 検索ハイライト付きエントリ行
    private func searchableEntryRow(entry: MoodEntry, colors: ThemeColors, query: String, matchedTags: [String]) -> some View {
        HStack {
            Text("\(entry.score)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: entry.score, maxScore: entry.maxScore))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                        .font(.system(.subheadline, design: .rounded))

                    if entry.photoPath != nil {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(colors.accent.opacity(0.5))
                    }
                    if entry.voiceMemoPath != nil {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundStyle(colors.accent.opacity(0.5))
                    }
                }

                if let memo = entry.memo, !memo.isEmpty {
                    if !query.isEmpty {
                        highlightedText(memo, query: query, accentColor: colors.accent)
                            .lineLimit(2)
                    } else {
                        Text(memo)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                            let isMatched = matchedTags.contains(tag)
                            Text(tag)
                                .font(.system(.caption2, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(colors.accent.opacity(isMatched ? 0.25 : 0.1)))
                                .foregroundStyle(colors.accent)
                                .overlay(
                                    isMatched
                                        ? Capsule().stroke(colors.accent, lineWidth: 1.5)
                                        : nil
                                )
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

            Button {
                editingEntry = entry
            } label: {
                Image(systemName: entry.memo?.isEmpty == false ? "pencil.circle.fill" : "plus.circle")
                    .font(.body)
                    .foregroundStyle(colors.accent.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    /// メモ内の検索語をアクセントカラーでハイライトする
    private func highlightedText(_ text: String, query: String, accentColor: Color) -> Text {
        let lowered = text.lowercased()
        let queryLowered = query.lowercased()

        var attributed = AttributedString(text)
        attributed.font = .system(.caption, design: .rounded)
        attributed.foregroundColor = .secondary

        var searchStart = lowered.startIndex
        while searchStart < lowered.endIndex {
            if let range = lowered.range(of: queryLowered, range: searchStart ..< lowered.endIndex),
               let attrLower = AttributedString.Index(range.lowerBound, within: attributed),
               let attrUpper = AttributedString.Index(range.upperBound, within: attributed)
            {
                attributed[attrLower ..< attrUpper].font = .system(.caption, design: .rounded, weight: .bold)
                attributed[attrLower ..< attrUpper].foregroundColor = accentColor
                searchStart = range.upperBound
            } else {
                break
            }
        }

        return Text(attributed)
    }

    // MARK: - ヘルパービュー

    /// 統計カード
    private func statCard(title: String, value: String, subtitle: String, icon: String, colors: ThemeColors) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(colors.accent)

            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))

            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    /// 平均スコア行（今期/前期比較）
    private func averageRow(label: String, current: Double?, previous: Double?, previousLabel _: String, colors: ThemeColors) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            if let current {
                Text(String(format: "%.1f", current))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(colors.accent)

                // 前期との差分
                if let previous {
                    let diff = current - previous
                    HStack(spacing: 2) {
                        Image(systemName: abs(diff) < 0.05 ? "equal" : (diff > 0 ? "arrow.up.right" : "arrow.down.right"))
                            .font(.caption2)
                        Text(String(format: "%+.1f", diff))
                            .font(.system(.caption, design: .rounded))
                    }
                    .foregroundColor(abs(diff) < 0.05 ? Color.secondary : (diff > 0 ? Color.green : Color.orange))
                }
            } else {
                Text("-")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - PRO 今月のまとめレポート

    /// Main entry point for the PRO monthly report card (current month, independent of range picker)
    @ViewBuilder
    private func proMonthlyReportCard(colors: ThemeColors) -> some View {
        let calendar = Calendar.current
        let now = Date.now
        if let monthInterval = calendar.dateInterval(of: .month, for: now) {
            let monthEntries = entries.filter { $0.createdAt >= monthInterval.start && $0.createdAt < monthInterval.end }
            let count = monthEntries.count

            if count >= 10 {
                if premiumManager.isPremium {
                    // Full report
                    if let summary = statsVM.monthlySummary(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore, month: now) {
                        VStack(alignment: .leading, spacing: 14) {
                            proMonthlyReportHeader(colors: colors, isPremium: true) {
                                showPDFExportDialog = true
                            }
                            proMonthlyOverviewGrid(summary: summary, colors: colors)
                            proMonthlyComparisonSection(colors: colors)
                            proMonthlyStabilityRow(summary: summary, colors: colors)
                            monthlyReviewHighlights(summary: summary, colors: colors)
                            proMonthlyOutliersSection(colors: colors)
                            proMonthlyTagInsights(monthEntries: monthEntries, colors: colors)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colors.accent.opacity(0.04))
                        )
                        .confirmationDialog("PDFレポートをエクスポート", isPresented: $showPDFExportDialog, titleVisibility: .visible) {
                            Button("今月のレポート") {
                                exportMonthlyPDF(month: now, summary: summary, colors: colors)
                            }
                            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: now),
                               prevMonthEntryCount(prevMonth: prevMonth) >= 10
                            {
                                Button("先月のレポート") {
                                    exportPreviousMonthPDF(prevMonth: prevMonth, colors: colors)
                                }
                            }
                            Button("キャンセル", role: .cancel) {}
                        } message: {
                            if let prevMonth = calendar.date(byAdding: .month, value: -1, to: now),
                               prevMonthEntryCount(prevMonth: prevMonth) < 10
                            {
                                let prevCount = prevMonthEntryCount(prevMonth: prevMonth)
                                if prevCount == 0 {
                                    Text("先月の記録がないため、今月のみ選択できます")
                                } else {
                                    Text("先月の記録が\(prevCount)件のため、先月のレポートは生成できません（10件以上必要）")
                                }
                            }
                        }
                    }
                } else {
                    // Locked preview for free users
                    VStack(alignment: .leading, spacing: 14) {
                        proMonthlyReportHeader(colors: colors, isPremium: false)
                        proMonthlyLockedPreview(entryCount: count, colors: colors)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.accent.opacity(0.04))
                    )
                }
            } else if count > 0 {
                // Not enough data message
                VStack(alignment: .leading, spacing: 10) {
                    proMonthlyReportHeader(colors: colors, isPremium: premiumManager.isPremium)
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .foregroundStyle(.secondary)
                        Text("今月のデータが少ないため、まとめを表示できません（あと\(10 - count)件）")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colors.accent.opacity(0.04))
                )
            }
            // count == 0 → hidden
        }
    }

    /// Header with icon, title, month label, optional PRO badge, and optional export button
    private func proMonthlyReportHeader(colors: ThemeColors, isPremium: Bool, onExport: (() -> Void)? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.doc.horizontal")
                .foregroundStyle(isPremium ? colors.accent : .purple)
            Text(ReportFormat.titleMonthSummary)
                .font(.system(.headline, design: .rounded))
            Text(Date.now.formatted(.dateTime.year().month(.defaultDigits)) + "月")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            if isPremium, let export = onExport {
                Button {
                    export()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(colors.accent)
                }
                .buttonStyle(.plain)
            }
            if !isPremium {
                Text("PRO")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.purple))
                    .foregroundStyle(.white)
            }
        }
    }

    /// 2×2 overview grid: average, entry count, active days, best weekday
    private func proMonthlyOverviewGrid(summary: MonthlySummary, colors: ThemeColors) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        // Previous month comparison
        let prevDiff: Double? = summary.previousMonthAverage.map { summary.average - $0 }

        return LazyVGrid(columns: columns, spacing: 10) {
            proMetricCell(
                label: "平均スコア",
                value: ReportFormat.score(summary.average),
                valueColor: colors.color(for: Int(summary.average.rounded()), maxScore: currentMaxScore, minScore: currentMinScore),
                subValue: prevDiff.map { ReportFormat.prevMonthDiff($0) },
                subColor: prevDiff.map { $0 >= 0 ? .green : .orange },
                colors: colors
            )
            proMetricCell(
                label: "記録回数",
                value: "\(summary.entryCount)回",
                valueColor: colors.accent,
                colors: colors
            )
            proMetricCell(
                label: "記録日数",
                value: "\(summary.activeDays)日",
                valueColor: colors.accent,
                colors: colors
            )
            proMetricCell(
                label: "好調な曜日",
                value: summary.weekdayBest,
                valueColor: .green,
                colors: colors
            )
        }
    }

    /// Single metric cell for the overview grid
    private func proMetricCell(
        label: String, value: String, valueColor: Color,
        subValue: String? = nil, subColor: Color? = nil,
        colors: ThemeColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
            if let sub = subValue {
                Text(sub)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(subColor ?? .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(colors.accent.opacity(0.06)))
    }

    // MARK: - Phase 2: 先月比較セクション

    /// Month-over-month comparison rows
    @ViewBuilder
    private func proMonthlyComparisonSection(colors: ThemeColors) -> some View {
        if let comparison = statsVM.monthlyComparison(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore) {
            if comparison.previousAverage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption2)
                            .foregroundStyle(colors.accent)
                        Text(ReportFormat.titleComparison)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    proComparisonRow(
                        label: "平均スコア",
                        current: ReportFormat.score(comparison.currentAverage),
                        diff: comparison.averageDiff.map { (value: ReportFormat.signedDiff($0), isPositive: $0 >= 0) }
                    )
                    proComparisonRow(
                        label: "記録回数",
                        current: "\(comparison.currentEntryCount)回",
                        diff: comparison.entryCountDiff.map { (value: ReportFormat.signedInt($0), isPositive: $0 >= 0) }
                    )
                    proComparisonRow(
                        label: "記録日数",
                        current: "\(comparison.currentActiveDays)日",
                        diff: comparison.activeDaysDiff.map { (value: ReportFormat.signedInt($0), isPositive: $0 >= 0) }
                    )
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(colors.accent.opacity(0.04)))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("先月のデータがありません")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Single comparison row: label | current value | diff badge
    private func proComparisonRow(label: String, current: String, diff: (value: String, isPositive: Bool)?) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(current)
                .font(.system(.caption, design: .rounded, weight: .semibold))
            Spacer()
            if let d = diff {
                let color: Color = d.value == "+0" || d.value == "+0.0" ? .secondary : (d.isPositive ? .green : .orange)
                Text(d.value)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Phase 2: 外れ値ハイライト

    /// Outlier days section (±1.5σ)
    @ViewBuilder
    private func proMonthlyOutliersSection(colors: ThemeColors) -> some View {
        let outliers = statsVM.monthlyOutliers(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        if !outliers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                    Text(ReportFormat.titleSpecialDays)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(outliers, id: \.date) { outlier in
                    proOutlierRow(outlier: outlier, colors: colors)
                }
            }
        }
    }

    /// Single outlier row: date + score + diff + tags + entry count
    private func proOutlierRow(outlier: StatsViewModel.MonthlyOutlier, colors: ThemeColors) -> some View {
        let isHigh = outlier.diffFromMean > 0
        let iconColor: Color = isHigh ? .green : .orange
        let diffText = ReportFormat.meanDiff(outlier.diffFromMean)

        return HStack(spacing: 8) {
            Image(systemName: isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(iconColor)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(outlier.date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text(ReportFormat.score(outlier.dayAverage))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(colors.color(for: Int(outlier.dayAverage.rounded()), maxScore: currentMaxScore, minScore: currentMinScore))
                    Text(diffText)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(iconColor.opacity(0.8))
                    if outlier.entryCountThatDay > 1 {
                        Text(ReportFormat.entryCount(outlier.entryCountThatDay))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                if !outlier.topTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(outlier.topTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(.caption2, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(colors.accent.opacity(0.1)))
                                .foregroundStyle(colors.accent)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.04)))
    }

    /// Stability indicator based on volatility
    private func proMonthlyStabilityRow(summary: MonthlySummary, colors _: ThemeColors) -> some View {
        let v = summary.volatility
        let label: String
        let icon: String
        let color: Color
        if v < 1.5 {
            label = "安定"; icon = "checkmark.seal.fill"; color = .green
        } else if v < 2.5 {
            label = "やや波あり"; icon = "wave.3.right"; color = .orange
        } else {
            label = "波が大きい"; icon = "waveform.path.ecg"; color = .red
        }
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(ReportFormat.titleStability)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            Text(ReportFormat.score(v))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)))
    }

    /// Tag insights: frequent tags + score-up/down tags
    @ViewBuilder
    private func proMonthlyTagInsights(monthEntries: [MoodEntry], colors: ThemeColors) -> some View {
        let taggedEntries = monthEntries.filter { !$0.tags.isEmpty }
        if taggedEntries.count >= 3 {
            let freqTags = statsVM.tagFrequency(entries: monthEntries).prefix(3)
            let diffs = statsVM.tagScoreDifferences(
                entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore,
                month: .now, minSamples: 3, topN: 3
            )
            let hasPositive = !diffs.positive.isEmpty
            let hasNegative = !diffs.negative.isEmpty

            VStack(alignment: .leading, spacing: 10) {
                // Frequent tags
                if !freqTags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ReportFormat.titleFrequentTags)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            ForEach(Array(freqTags), id: \.tag) { item in
                                HStack(spacing: 3) {
                                    Text(item.tag)
                                        .font(.system(.caption, design: .rounded))
                                    Text("\(item.count)")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(colors.accent.opacity(0.1)))
                                .foregroundStyle(colors.accent)
                            }
                        }
                    }
                }

                // Score diffs
                if hasPositive || hasNegative {
                    if hasPositive {
                        proTagDiffList(
                            title: ReportFormat.titleTagUp,
                            icon: "arrow.up.right",
                            items: diffs.positive,
                            diffColor: .green
                        )
                    }
                    if hasNegative {
                        proTagDiffList(
                            title: ReportFormat.titleTagDown,
                            icon: "arrow.down.right",
                            items: diffs.negative,
                            diffColor: .orange
                        )
                    }
                } else if taggedEntries.count >= 3 {
                    Text("タグごとのスコア差が小さいため、傾向は見られません")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Helper list for tag score differences (positive or negative)
    private func proTagDiffList(title: String, icon: String, items: [StatsViewModel.TagScoreDiff], diffColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(diffColor)
                Text(title)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(items, id: \.tag) { item in
                HStack(spacing: 8) {
                    Text(item.tag)
                        .font(.system(.caption, design: .rounded))
                    Text(ReportFormat.signedDiff(item.diff))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(diffColor)
                    Text(ReportFormat.sampleCount(item.count))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    /// Locked preview for free users showing blurred metrics and PRO CTA
    private func proMonthlyLockedPreview(entryCount: Int, colors: ThemeColors) -> some View {
        VStack(spacing: 12) {
            // Blurred teaser metrics
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("平均スコア")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("?.?")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .blur(radius: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("記録回数")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(entryCount)回")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(colors.accent)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(colors.accent.opacity(0.06)))

            // PRO upgrade button
            Button {
                showPremiumSheet = true
                HapticManager.lightFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("PROの機能を詳しく見る")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            Text("月額・年額・買い切りから選べます")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
