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

/// 統計画面のセクション識別子（ForEachで個別にレンダリングするため）
enum StatsSection: Int, CaseIterable, Identifiable {
    case insight = 0
    case weeklyReview
    case moodRhythm
    case summaryCards
    case distribution
    case average
    case pastComparison
    case weekday
    case timeOfDay
    case streak
    case calendar
    case tagAnalysis
    case memoKeyword
    case sourceBreakdown
    case recordTiming
    case stability
    case weatherMood
    case energyMood
    case locationMood
    case recovery
    case healthKit
    case premium
    case prediction
    case tagFlow
    case discovery
    case activity

    var id: Int {
        rawValue
    }

    /// Section display name for table of contents
    var displayName: String {
        switch self {
        case .insight: return String(localized: "インサイト")
        case .weeklyReview: return String(localized: "週間レビュー")
        case .moodRhythm: return String(localized: "ムードリズム")
        case .summaryCards: return String(localized: "サマリー")
        case .distribution: return String(localized: "スコア分布")
        case .average: return String(localized: "平均スコア")
        case .pastComparison: return String(localized: "過去比較")
        case .weekday: return String(localized: "曜日別")
        case .timeOfDay: return String(localized: "時間帯別")
        case .streak: return String(localized: "ストリーク")
        case .calendar: return String(localized: "カレンダー")
        case .tagAnalysis: return String(localized: "タグ分析")
        case .memoKeyword: return String(localized: "キーワード分析")
        case .sourceBreakdown: return String(localized: "記録元別")
        case .recordTiming: return String(localized: "記録タイミング")
        case .stability: return String(localized: "安定度")
        case .weatherMood: return String(localized: "天気×気分")
        case .energyMood: return String(localized: "エネルギー×気分")
        case .locationMood: return String(localized: "場所×気分")
        case .recovery: return String(localized: "回復パターン")
        case .healthKit: return String(localized: "ヘルスケア相関")
        case .premium: return String(localized: "プレミアム分析")
        case .prediction: return String(localized: "スコア予測")
        case .tagFlow: return String(localized: "タグ遷移マップ")
        case .discovery: return String(localized: "発見")
        case .activity: return String(localized: "アクティビティ")
        }
    }

    /// Section icon
    var icon: String {
        switch self {
        case .insight: return "lightbulb.fill"
        case .weeklyReview: return "text.badge.checkmark"
        case .moodRhythm: return "waveform.path"
        case .summaryCards: return "square.grid.2x2"
        case .distribution: return "chart.bar.fill"
        case .average: return "number"
        case .pastComparison: return "clock.arrow.circlepath"
        case .weekday: return "calendar"
        case .timeOfDay: return "sun.and.horizon.fill"
        case .streak: return "flame.fill"
        case .calendar: return "calendar.badge.clock"
        case .tagAnalysis: return "tag.fill"
        case .memoKeyword: return "text.magnifyingglass"
        case .sourceBreakdown: return "apps.iphone"
        case .recordTiming: return "clock.fill"
        case .stability: return "waveform.path.ecg"
        case .weatherMood: return "cloud.sun.fill"
        case .energyMood: return "battery.75percent"
        case .locationMood: return "mappin.and.ellipse"
        case .recovery: return "arrow.up.heart.fill"
        case .healthKit: return "heart.fill"
        case .premium: return "sparkles"
        case .prediction: return "crystal.ball"
        case .tagFlow: return "arrow.triangle.branch"
        case .discovery: return "magnifyingglass"
        case .activity: return "list.bullet"
        }
    }

    /// Section description for guide
    var guide: String {
        switch self {
        case .insight: return String(localized: "あなたのデータから見つけた気づきをカード形式で表示。天気・睡眠・運動との相関、タグパターン、ストレス検出など。毎日入れ替わり、データが増えるほど精度が上がります")
        case .weeklyReview: return String(localized: "今週の記録をまとめて振り返り。ハイライトとローポイント、よく使ったタグを表示")
        case .moodRhythm: return String(localized: "月〜日の曜日別平均スコアを波線チャートで表示。週のリズムが見えます")
        case .summaryCards: return String(localized: "週間・月間・年間の平均スコアとストリークを4枚のカードで一覧表示")
        case .distribution: return String(localized: "各スコアが何回記録されたかの分布。自分がよく記録するスコア帯がわかります")
        case .average: return String(localized: "週間・月間・年間の平均スコアと先週比のトレンドを数値で表示")
        case .pastComparison: return String(localized: "昨年の同時期と今のスコアを比較。長期的な変化を実感できます")
        case .weekday: return String(localized: "曜日ごとの平均スコアを棒グラフで表示。特定の曜日の傾向を発見")
        case .timeOfDay: return String(localized: "朝・昼・夕・夜の4つの時間帯ごとの平均スコア。記録する時間帯の傾向がわかります")
        case .streak: return String(localized: "連続記録日数と過去最長記録。毎日の習慣化のモチベーションに")
        case .calendar: return String(localized: "月間カレンダーに日ごとのスコアを色で表示。タップで詳細を確認できます")
        case .tagAnalysis: return String(localized: "タグの使用頻度、タグ別の平均スコア、タグの共起パターンなどを分析")
        case .memoKeyword: return String(localized: "メモに頻出するキーワードとスコアの関係を分析。無意識の言葉の傾向に気づけます")
        case .sourceBreakdown: return String(localized: "アプリ・ウィジェット・Apple Watchのどこから記録したかで平均スコアを比較")
        case .recordTiming: return String(localized: "何時に記録することが多いかを時間帯別に表示。深夜の記録が増えた週はスコアが不安定になる傾向があります")
        case .stability: return String(localized: "直近7日間のスコアの安定度を0〜100で数値化。変動が大きいほど低くなります")
        case .weatherMood: return String(localized: "天気・気温を自動記録し、天気ごとの平均スコアを比較。設定でONにするだけで入力不要です")
        case .energyMood: return String(localized: "気分スコアとエネルギーレベルの一致/乖離を分析。無理していないかチェック")
        case .locationMood: return String(localized: "場所タグ（自宅・職場など）ごとの平均スコアを比較。環境と気分の関係を可視化")
        case .recovery: return String(localized: "スコアが低い期間から回復するまでの日数と、回復時によく使われるタグを表示")
        case .healthKit: return String(localized: "歩数・睡眠・心拍・HRV・イヤホン使用時間・運動時間・ワークアウト種類の7項目と気分の相関を自動分析。運動の分岐点やストレス乖離も検出します")
        case .premium: return String(localized: "高度な分析：タグチェーン、エコー効果、回復トリガー、タグシナジー、月次ゴールドインサイトなど。PRO限定")
        case .prediction: return String(localized: "過去のパターンから明日の気分スコアを予測。曜日・トレンド・タグの3要素で計算。予測と実際のズレが大きい日は「予想外の出来事」として通知します")
        case .tagFlow: return String(localized: "タグの遷移パターンをフロー図で可視化。どのタグの後にどのタグが続くかを表示")
        case .discovery: return String(localized: "記録回数やタグ使用頻度とスコアの関係など、意外なパターンを発見")
        case .activity: return String(localized: "最近の記録を時系列で一覧表示。タップしてメモを編集できます")
        }
    }
}

/// 統計画面
/// 週間/月間/年間の平均スコア、スコア分布、連続記録日数を表示する
struct StatsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.healthKitManager) private var healthKitManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    @State private var statsVM = StatsViewModel()
    /// 全件リスト表示フラグ
    @State private var showAllEntries = false
    /// セクション折りたたみ状態
    @State private var expandedSections: Set<String> = ["summary", "rhythm", "distribution"]
    /// メモ編集シートの対象エントリ
    @State private var editingEntry: MoodEntry?
    /// シェアサマリーシート表示フラグ
    @State private var showShareSummary = false
    /// タグ影響分析シート表示フラグ
    @State private var showTagImpactSheet = false

    /// 現在のスコア範囲上限
    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10
    /// 現在のスコア範囲下限
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1

    /// プレミアム状態
    @Environment(\.premiumManager) private var premiumManager
    /// 月間サマリーの表示月
    @State private var summaryMonth: Date = .now
    /// プレミアム購入シート表示
    @State private var showProView = false
    /// キャッシュ：インサイトカード（entries変更時のみ再計算）
    @State private var cachedInsights: [InsightCard] = []
    /// キャッシュ：プレミアムインサイトカード
    @State private var cachedPremiumInsights: [InsightCard] = []
    /// HealthKit相関データ
    @State private var healthCorrelations: (steps: Double?, sleep: Double?, heartRate: Double?, headphone: Double?, hrv: Double?, exercise: Double?) = (nil, nil, nil, nil, nil, nil)
    @State private var isLoadingHealthData = false
    /// Cached workout/headphone/exercise/HRV analysis results
    @State private var cachedWorkoutResults: [StatsViewModel.WorkoutMoodResult] = []
    @State private var cachedHeadphoneResults: [StatsViewModel.HeadphoneMoodResult] = []
    @State private var cachedExerciseThreshold: StatsViewModel.ExerciseThresholdResult?
    @State private var cachedHRVResult: StatsViewModel.HRVMoodResult?
    /// Monthly discovery report
    @State private var monthlyGoldCard: InsightCard?
    @State private var monthlyDiscoveries: [InsightEngine.CorrelationDiscovery] = []
    /// 解説・目次シート表示フラグ
    @State private var showGuideSheet = false
    /// 全インサイトリスト表示フラグ
    @State private var showAllInsights = false
    /// 月間まとめ画面表示フラグ
    @State private var showMonthlyReport = false
    /// レポートアーカイブ表示フラグ
    @State private var showReportArchive = false
    /// Contextual help sheet
    @State private var showContextHelp = false
    @State private var contextHelpTitle = ""
    @State private var contextHelpItems: [HelpItem] = []
    /// セクションジャンプ用のScrollViewProxy
    @State private var scrollProxy: ScrollViewProxy?
    /// Collapsible category group expansion state (all collapsed by default)
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if entries.isEmpty {
                        ScrollView {
                            emptyStatsView(colors: colors)
                                .padding()
                        }
                    } else {
                        // Grouped layout: highlight sections always visible, rest in collapsible categories
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 20) {
                                    // Always visible highlight sections
                                    ForEach(highlightSections) { section in
                                        sectionContent(section, colors: colors)
                                            .id(section)
                                    }

                                    // Collapsible category groups
                                    categoryGroupView(
                                        title: String(localized: "トレンド分析"),
                                        icon: "chart.line.uptrend.xyaxis",
                                        sections: trendSections,
                                        colors: colors
                                    )
                                    categoryGroupView(
                                        title: String(localized: "タグ・キーワード"),
                                        icon: "tag.fill",
                                        sections: tagSections,
                                        colors: colors
                                    )
                                    categoryGroupView(
                                        title: String(localized: "コンテキスト分析"),
                                        icon: "cloud.sun.fill",
                                        sections: contextSections,
                                        colors: colors
                                    )
                                    categoryGroupView(
                                        title: String(localized: "深い分析"),
                                        icon: "brain.head.profile",
                                        sections: deepSections,
                                        colors: colors
                                    )
                                    categoryGroupView(
                                        title: String(localized: "PRO 高度分析"),
                                        icon: "sparkles",
                                        sections: proSections,
                                        colors: colors,
                                        isPro: true
                                    )
                                }
                                .padding()
                            }
                            .onAppear { scrollProxy = proxy }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showGuideSheet = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(.body, design: .rounded))
                        }

                        Button {
                            showShareSummary = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(.body, design: .rounded))
                        }
                        .disabled(entries.isEmpty)
                    }
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
                    currentMinScore: currentMinScore,
                    themeColors: themeManager.colors,
                    statsVM: statsVM
                )
            }
            .sheet(isPresented: $showProView) {
                NavigationStack {
                    ProView()
                }
            }
            .sheet(isPresented: $showMonthlyReport) {
                MonthlyReportView()
            }
            .sheet(isPresented: $showReportArchive) {
                NavigationStack {
                    ReportArchiveView()
                }
            }
            .sheet(isPresented: $showContextHelp) {
                FeatureHelpSheet(
                    title: contextHelpTitle,
                    items: contextHelpItems,
                    accentColor: themeManager.colors.accent
                )
            }
            .sheet(isPresented: $showGuideSheet) {
                statsGuideSheet
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
                    onSkip: {
                        editingEntry = nil
                    }
                )
            }
            .onAppear { rebuildInsightCaches() }
            .onChange(of: entries.count) { _, _ in rebuildInsightCaches() }
        }
    }

    // MARK: - 解説・目次シート

    private var statsGuideSheet: some View {
        NavigationStack {
            List {
                Section(String(localized: "ハイライト")) {
                    ForEach(highlightSections) { section in
                        guideRow(for: section)
                    }
                }
                Section(String(localized: "トレンド分析")) {
                    ForEach(trendSections) { section in
                        guideRow(for: section)
                    }
                }
                Section(String(localized: "タグ・キーワード")) {
                    ForEach(tagSections) { section in
                        guideRow(for: section)
                    }
                }
                Section(String(localized: "コンテキスト分析")) {
                    ForEach(contextSections) { section in
                        guideRow(for: section)
                    }
                }
                Section(String(localized: "深い分析")) {
                    ForEach(deepSections) { section in
                        guideRow(for: section)
                    }
                }
                Section(String(localized: "PRO 高度分析")) {
                    ForEach(proSections) { section in
                        guideRow(for: section)
                    }
                }
            }
            .navigationTitle(String(localized: "統計ガイド"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる")) {
                        showGuideSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Guide sheet row for a single section
    private func guideRow(for section: StatsSection) -> some View {
        Button {
            showGuideSheet = false
            // Ensure the category group is expanded so scrollTo works
            let groupTitle = categoryGroupTitle(for: section)
            if let title = groupTitle, !expandedCategories.contains(title) {
                expandedCategories.insert(title)
            }
            // Delay to let sheet dismiss before scrolling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(section, anchor: .top)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(.body))
                    .foregroundStyle(themeManager.colors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.displayName)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(section.guide)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Returns the category group title a section belongs to (nil for highlight sections)
    private func categoryGroupTitle(for section: StatsSection) -> String? {
        let trendCases: Set<StatsSection> = [.moodRhythm, .distribution, .average, .pastComparison, .weekday, .timeOfDay, .streak]
        let tagCases: Set<StatsSection> = [.tagAnalysis, .memoKeyword]
        let contextCases: Set<StatsSection> = [.weatherMood, .energyMood, .locationMood, .sourceBreakdown, .recordTiming, .healthKit]
        let deepCases: Set<StatsSection> = [.stability, .recovery, .discovery, .activity]
        let proCases: Set<StatsSection> = [.prediction, .tagFlow, .premium]

        if trendCases.contains(section) { return String(localized: "トレンド分析") }
        if tagCases.contains(section) { return String(localized: "タグ・キーワード") }
        if contextCases.contains(section) { return String(localized: "コンテキスト分析") }
        if deepCases.contains(section) { return String(localized: "深い分析") }
        if proCases.contains(section) { return String(localized: "PRO 高度分析") }
        return nil
    }

    /// インサイトキャッシュを再構築する
    private func rebuildInsightCaches() {
        var insights = InsightEngine.generate(from: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        // Add HealthKit correlation insights with personal thresholds
        if healthKitManager.isEnabled {
            let cachedMetricsArray = Array(healthKitManager.cachedMetrics.values)
            if !cachedMetricsArray.isEmpty {
                let hkInsights = InsightEngine.healthKitInsights(
                    entries: entries,
                    metrics: cachedMetricsArray,
                    currentMax: currentMaxScore,
                    currentMin: currentMinScore
                )
                insights.append(contentsOf: hkInsights)
            } else {
                // Fallback to legacy correlation-based insights
                let hkInsights = InsightEngine.healthKitInsights(
                    stepsCorrelation: healthCorrelations.steps,
                    sleepCorrelation: healthCorrelations.sleep,
                    heartRateCorrelation: healthCorrelations.heartRate
                )
                insights.append(contentsOf: hkInsights)
            }
            // Tag × HealthKit cross analysis (the key differentiator)
            if !cachedMetricsArray.isEmpty {
                let crossInsights = InsightEngine.tagHealthKitCrossInsights(
                    entries: entries,
                    metrics: cachedMetricsArray,
                    currentMax: currentMaxScore,
                    currentMin: currentMinScore
                )
                insights.append(contentsOf: crossInsights)

                // Headphone × Mood analysis (unique to Nami)
                let headphoneInsights = InsightEngine.headphoneMoodInsights(
                    entries: entries,
                    metrics: cachedMetricsArray,
                    currentMax: currentMaxScore,
                    currentMin: currentMinScore
                )
                insights.append(contentsOf: headphoneInsights)

                // HRV × Mood analysis
                let hrvInsights = InsightEngine.hrvMoodInsights(
                    entries: entries,
                    metrics: cachedMetricsArray,
                    currentMax: currentMaxScore,
                    currentMin: currentMinScore
                )
                insights.append(contentsOf: hrvInsights)

                // Exercise & Workout × Mood analysis
                let exerciseInsights = InsightEngine.exerciseMoodInsights(
                    entries: entries,
                    metrics: cachedMetricsArray,
                    currentMax: currentMaxScore,
                    currentMin: currentMinScore
                )
                insights.append(contentsOf: exerciseInsights)
            }

            insights.sort { $0.priority > $1.priority }
            insights = Array(insights.prefix(InsightEngine.maxDisplayCards))
        }
        // Nemuri sleep insights (returns [] if no Nemuri data — no cross-sell UI)
        let sleepInsights = InsightEngine.nemuriSleepInsights(
            entries: entries,
            currentMax: currentMaxScore,
            currentMin: currentMinScore
        )
        if !sleepInsights.isEmpty {
            insights.append(contentsOf: sleepInsights)
            insights.sort { $0.priority > $1.priority }
            insights = Array(insights.prefix(InsightEngine.maxDisplayCards))
        }
        cachedInsights = insights
        // Mark as viewed for evolving text
        InsightEngine.markInsightsAsViewed(insights)
        cachedPremiumInsights = InsightEngine.generatePremium(from: entries, currentMax: currentMaxScore, currentMin: currentMinScore)

        // Monthly discovery report (gold card + correlations)
        let metricsArray = Array(healthKitManager.cachedMetrics.values)
        let report = InsightEngine.monthlyDiscoveryReport(
            from: entries,
            metrics: metricsArray,
            currentMax: currentMaxScore,
            currentMin: currentMinScore,
            isPremium: premiumManager.isPremium
        )
        monthlyGoldCard = report.gold
        monthlyDiscoveries = report.discoveries
    }

    // MARK: - セクション管理（グループ化レイアウト）

    /// All active sections combined (used by guide sheet)
    private var activeSections: [StatsSection] {
        highlightSections + trendSections + tagSections + contextSections + deepSections + proSections
    }

    /// Always-visible highlight sections
    private var highlightSections: [StatsSection] {
        [.insight, .weeklyReview, .summaryCards, .calendar]
    }

    /// Group A: Trend analysis sections
    private var trendSections: [StatsSection] {
        [.moodRhythm, .distribution, .average, .pastComparison, .weekday, .timeOfDay, .streak]
    }

    /// Group B: Tag & keyword sections (conditionally included)
    private var tagSections: [StatsSection] {
        var sections: [StatsSection] = []
        if entries.contains(where: { !$0.tags.isEmpty }) {
            sections.append(.tagAnalysis)
        }
        if entries.contains(where: { $0.memo != nil }) {
            sections.append(.memoKeyword)
        }
        return sections
    }

    /// Group C: Context analysis sections (conditionally included)
    private var contextSections: [StatsSection] {
        var sections: [StatsSection] = []
        if entries.contains(where: { $0.weatherCondition != nil }) {
            sections.append(.weatherMood)
        }
        if entries.contains(where: { $0.energyLevel != nil }) {
            sections.append(.energyMood)
        }
        let locationTags: Set<String> = ["自宅", "職場/学校", "外出先", "移動中", "Home", "Work/School", "Outside", "Commuting"]
        if entries.contains(where: { !Set($0.tags).isDisjoint(with: locationTags) }) {
            sections.append(.locationMood)
        }
        if Set(entries.map(\.source)).count >= 2 {
            sections.append(.sourceBreakdown)
        }
        if entries.count >= 30 {
            sections.append(.recordTiming)
        }
        if healthKitManager.isEnabled, healthKitManager.isAuthorized {
            sections.append(.healthKit)
        }
        return sections
    }

    /// Group D: Deep analysis sections (conditionally included)
    private var deepSections: [StatsSection] {
        var sections: [StatsSection] = [.stability]
        if entries.count >= 10 {
            sections.append(.recovery)
        }
        sections.append(contentsOf: [.discovery, .activity])
        return sections
    }

    /// Group E: PRO advanced analysis sections
    private var proSections: [StatsSection] {
        [.prediction, .tagFlow, .premium]
    }

    /// Toggle a category group's expansion state
    private func toggleCategoryGroup(_ title: String) {
        if expandedCategories.contains(title) {
            expandedCategories.remove(title)
        } else {
            expandedCategories.insert(title)
        }
    }

    /// Collapsible category group wrapper
    @ViewBuilder
    private func categoryGroupView(
        title: String,
        icon: String,
        sections: [StatsSection],
        colors: ThemeColors,
        isPro: Bool = false
    ) -> some View {
        if !sections.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Collapsible header with chevron
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleCategoryGroup(title)
                    }
                } label: {
                    HStack {
                        Image(systemName: icon)
                            .foregroundStyle(colors.accent)
                        Text(title)
                            .font(.system(.headline, design: .rounded))
                        if isPro && !premiumManager.isPremium {
                            Text("PRO")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.orange))
                        }
                        Spacer()
                        Image(systemName: expandedCategories.contains(title) ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if expandedCategories.contains(title) {
                    ForEach(sections) { section in
                        sectionContent(section, colors: colors)
                            .id(section)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    /// セクションごとのコンテンツを返す（各caseが独立した型として評価される）
    @ViewBuilder
    private func sectionContent(_ section: StatsSection, colors: ThemeColors) -> some View {
        switch section {
        case .insight: insightCarousel(colors: colors)
        case .weeklyReview: weeklyReviewSection(colors: colors)
        case .moodRhythm: moodRhythmSection(colors: colors)
        case .summaryCards: summaryCards(colors: colors)
        case .distribution: distributionSection(colors: colors)
        case .average: averageSection(colors: colors)
        case .pastComparison: pastComparisonSection(colors: colors)
        case .weekday: weekdayAverageSection(colors: colors)
        case .timeOfDay: timeOfDaySection(colors: colors)
        case .streak: streakSection(colors: colors)
        case .calendar: calendarHeatmapSection(colors: colors)
        case .tagAnalysis: tagAnalysisSection(colors: colors)
        case .memoKeyword: memoKeywordSection(colors: colors)
        case .sourceBreakdown: sourceBreakdownSection(colors: colors)
        case .recordTiming: recordTimingSection(colors: colors)
        case .stability: stabilitySection(colors: colors)
        case .weatherMood: weatherMoodSection(colors: colors)
        case .energyMood: energyMoodSection(colors: colors)
        case .locationMood: locationMoodSection(colors: colors)
        case .recovery: recoverySection(colors: colors)
        case .healthKit: healthKitCorrelationSection(colors: colors)
        case .premium: premiumAnalyticsSection(colors: colors)
        case .prediction: predictionSection(colors: colors)
        case .tagFlow: tagFlowSection(colors: colors)
        case .discovery: discoverySection(colors: colors)
        case .activity: activitySection(colors: colors)
        }
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

    // MARK: - インサイトセクション（ヒーローカード + アンロック予告）

    @ViewBuilder
    private func insightCarousel(colors: ThemeColors) -> some View {
        let insights = cachedInsights
        let entryCount = entries.count
        let threshold = InsightEngine.minimumTotalEntries // 20

        VStack(alignment: .leading, spacing: 16) {
            // Monthly Discovery Report (gold card + correlations)
            if monthlyGoldCard != nil || !monthlyDiscoveries.isEmpty {
                monthlyDiscoverySection(colors: colors)
            }

            if !insights.isEmpty {
                // --- Hero Card: most important insight ---
                let hero = insights[0]
                insightHeroCard(card: hero, colors: colors)

                // "See all insights" button (if more than 1)
                if insights.count > 1 {
                    Button {
                        showAllInsights = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.max.fill")
                                .font(.caption)
                            Text(String(localized: "他のインサイトを見る（\(insights.count - 1)件）"))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(colors.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colors.accent.opacity(0.08))
                        )
                    }
                    .sheet(isPresented: $showAllInsights) {
                        allInsightsSheet(insights: insights, colors: colors)
                    }
                }
            } else if entryCount > 0 && entryCount < threshold {
                // --- Unlock Preview: intermediate empty state ---
                insightUnlockPreview(entryCount: entryCount, threshold: threshold, colors: colors)
            }
        }
    }

    // MARK: - Monthly Discovery (preserved)

    private func monthlyDiscoverySection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                Text(String(localized: "今月の発見"))
                    .font(.system(.headline, design: .rounded))
                Spacer()
                if !premiumManager.isPremium && monthlyDiscoveries.count <= 1 {
                    Text("PRO")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(colors.accent.opacity(0.1)))
                }
            }
            .padding(.horizontal, 4)

            if let gold = monthlyGoldCard {
                insightCardView(card: gold, colors: colors)
            }

            ForEach(monthlyDiscoveries) { discovery in
                HStack(spacing: 12) {
                    Image(systemName: discovery.icon)
                        .font(.body)
                        .foregroundStyle(colors.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(discovery.dimensionA)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(discovery.dimensionB)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        Text(discovery.direction)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.yellow.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            if !premiumManager.isPremium {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(colors.accent)
                    Text(String(localized: "PROで最大5つの関連性を発見"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(colors.accent)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Hero Card

    private func insightHeroCard(card: InsightCard, colors _: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(card.tone.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: card.icon)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(card.tone.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "今日のインサイト"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(card.title)
                        .font(.system(.headline, design: .rounded))
                }
            }

            Text(card.body)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(card.tone.color.opacity(0.25), lineWidth: 1.5)
        )
    }

    // MARK: - All Insights Sheet

    private func allInsightsSheet(insights: [InsightCard], colors: ThemeColors) -> some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(insights) { card in
                        insightCardView(card: card, colors: colors)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "すべてのインサイト"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "閉じる")) { showAllInsights = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Unlock Preview (Intermediate Empty State)

    private func insightUnlockPreview(entryCount: Int, threshold: Int, colors: ThemeColors) -> some View {
        let remaining = threshold - entryCount
        let progress = Double(entryCount) / Double(threshold)

        // Upcoming insight milestones
        let milestones: [(count: Int, icon: String, title: String)] = [
            (7, "calendar", String(localized: "曜日ごとの傾向")),
            (10, "tag", String(localized: "タグの影響分析")),
            (14, "chart.bar", String(localized: "スコア分布")),
            (20, "lightbulb.fill", String(localized: "AIインサイト")),
        ]

        return VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(colors.accent)
                Text(String(localized: "インサイトの準備中"))
                    .font(.system(.headline, design: .rounded))
            }

            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(colors.accent)

                Text(String(localized: "あと\(remaining)日の記録で最初のインサイトが解放されます"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Milestone list
            VStack(spacing: 0) {
                ForEach(milestones, id: \.count) { milestone in
                    let isUnlocked = entryCount >= milestone.count
                    let isNext = !isUnlocked && (milestones.first { entryCount < $0.count }?.count == milestone.count)

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isUnlocked ? colors.accent : (isNext ? colors.accent.opacity(0.15) : Color(.systemGray5)))
                                .frame(width: 32, height: 32)
                            Image(systemName: isUnlocked ? "checkmark" : milestone.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isUnlocked ? .white : (isNext ? colors.accent : .secondary))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(milestone.title)
                                .font(.system(.subheadline, design: .rounded, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isUnlocked ? .primary : (isNext ? .primary : .secondary))
                            Text(String(localized: "\(milestone.count)件の記録で解放"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        if isUnlocked {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else if isNext {
                            Text(String(localized: "あと\(milestone.count - entryCount)件"))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(colors.accent)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)

                    if milestone.count != milestones.last?.count {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(colors.accent.opacity(0.15), lineWidth: 1)
        )
    }

    /// インサイトカード1枚のビュー（リスト表示用、フル幅）
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        if let review = statsVM.weeklyReview(entries: entries, currentMax: currentMaxScore) {
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
            Text("先週のふりかえり")
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
                .foregroundStyle(colors.color(for: Int(review.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))

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
            Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%+.1f", diff))
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(diff >= 0 ? .green : .orange)
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
                    .foregroundStyle(colors.color(for: point.score, minScore: currentMinScore, maxScore: currentMaxScore))

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

    // MARK: - ムードリズムセクション

    @ViewBuilder
    private func moodRhythmSection(colors: ThemeColors) -> some View {
        let rhythmData = statsVM.weeklyRhythmData(entries: entries, currentMax: currentMaxScore)
        let hasRhythmData = rhythmData.contains { $0.average != 0 }

        if hasRhythmData {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("あなたの1週間のリズム")
                        .font(.system(.headline, design: .rounded))
                    infoButton(title: String(localized: "安定度とリズム"), items: HelpContent.stabilityExplanation)
                }
                .padding(.horizontal, 4)

                // 週間リズム波線チャート
                weeklyRhythmChart(rhythmData: rhythmData, colors: colors)

                // ボラティリティ推移
                let volData = statsVM.volatilityTrend(entries: entries, currentMax: currentMaxScore)
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
                    if item.average != 0 {
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
                        .foregroundStyle(colors.color(for: Int(item.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))
                        .symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f", item.average))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.color(for: Int(item.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))
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
            let validData = rhythmData.filter { $0.average != 0 }
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
            if let highest = statsVM.highestScore(entries: entries, currentMax: currentMaxScore) {
                statCard(
                    title: "最高スコア",
                    value: "\(highest.score)",
                    subtitle: highest.date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)),
                    icon: "arrow.up.circle",
                    colors: colors
                )
            }

            // 最低スコア
            if let lowest = statsVM.lowestScore(entries: entries, currentMax: currentMaxScore) {
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

    private func distributionSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("スコア分布")
                    .font(.system(.headline, design: .rounded))

                Spacer()

                // モード値の表示
                if let mode = statsVM.mostCommonScore(entries: entries, currentMax: currentMaxScore) {
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
            let distribution = statsVM.scoreDistribution(entries: entries, minScore: currentMinScore, maxScore: currentMaxScore)
            let maxCount = distribution.values.max() ?? 1

            // 分布が大きい場合はグルーピング表示
            let totalRange = currentMaxScore - currentMinScore + 1
            if totalRange > 30 {
                groupedDistributionChart(distribution: distribution, maxCount: maxCount, colors: colors)
            } else {
                Chart {
                    ForEach(Array(currentMinScore ... currentMaxScore), id: \.self) { score in
                        let count = distribution[score] ?? 0
                        BarMark(
                            x: .value("回数", count),
                            y: .value("スコア", "\(score)")
                        )
                        .foregroundStyle(colors.color(for: score, minScore: currentMinScore, maxScore: currentMaxScore).gradient)
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
                .frame(height: CGFloat(totalRange) * 28)
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
        let groupMax = groups.map(\.count).max() ?? 1

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

    // MARK: - 平均スコアセクション

    private func averageSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("平均スコア")
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 4)

            // 週間平均
            averageRow(
                label: "今週",
                current: statsVM.weeklyAverage(entries: entries, currentMax: currentMaxScore),
                previous: statsVM.lastWeekAverage(entries: entries, currentMax: currentMaxScore),
                previousLabel: "先週",
                colors: colors
            )

            // 月間平均
            averageRow(
                label: "今月",
                current: statsVM.monthlyAverage(entries: entries, currentMax: currentMaxScore),
                previous: statsVM.lastMonthAverage(entries: entries, currentMax: currentMaxScore),
                previousLabel: "先月",
                colors: colors
            )

            // 年間平均
            if let yearAvg = statsVM.yearlyAverage(entries: entries, currentMax: currentMaxScore) {
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
        let comparison = statsVM.pastComparison(entries: entries, currentMax: currentMaxScore)

        if comparison.hasLastYearData {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader("あの頃の自分と比較", sectionKey: "pastComparison", icon: "calendar.badge.clock")

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
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9))
                    Text(String(format: "%+.1f", diff))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(diff >= 0 ? .green : .orange)
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

    /// Contextual info button that opens a help sheet
    private func infoButton(title: String, items: [HelpItem]) -> some View {
        Button {
            contextHelpTitle = title
            contextHelpItems = items
            showContextHelp = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
    }

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
            collapsibleHeader("曜日別平均", sectionKey: "weekday")

            if expandedSections.contains("weekday") {
                let averages = statsVM.weekdayAverages(entries: entries, currentMax: currentMaxScore)
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
                                ? colors.color(for: Int(avg.rounded()), minScore: currentMinScore, maxScore: currentMaxScore).gradient
                                : Color.gray.opacity(0.3).gradient
                        )
                        .cornerRadius(6)
                    }
                }
                .chartYScale(domain: Double(currentMinScore) ... Double(currentMaxScore))
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
            collapsibleHeader("時間帯別平均", sectionKey: "timeOfDay")

            if expandedSections.contains("timeOfDay") {
                let averages = statsVM.timeOfDayAverages(entries: entries, currentMax: currentMaxScore)
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
                                    .foregroundStyle(colors.color(for: Int(avg.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))
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
            collapsibleHeader("ストリーク", sectionKey: "streak")

            if expandedSections.contains("streak") {
                let current = statsVM.currentStreak(entries: entries)
                let longest = statsVM.longestStreak(entries: entries)

                HStack(spacing: 12) {
                    // 現在のストリーク
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(.orange)

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

    // MARK: - カレンダーヒートマップセクション

    private func calendarHeatmapSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("月間カレンダー")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    showReportArchive = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 10))
                        Text(String(localized: "アーカイブ"))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                Button {
                    showMonthlyReport = true
                } label: {
                    HStack(spacing: 4) {
                        Text(String(localized: "月間まとめ"))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(colors.accent)
                }
            }
            .padding(.horizontal, 4)

            MonthlyHeatmapView(
                entries: entries,
                currentMaxScore: currentMaxScore,
                currentMinScore: currentMinScore,
                colors: colors
            )
        }
    }

    // MARK: - HealthKit相関セクション

    private func healthKitCorrelationSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                collapsibleHeader(String(localized: "ヘルスケア相関"), sectionKey: "healthKit")
                infoButton(title: String(localized: "HRV（心拍変動）"), items: HelpContent.hrvExplanation)
            }

            if expandedSections.contains("healthKit") {
                if isLoadingHealthData {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else {
                    VStack(spacing: 10) {
                        // Basic correlations
                        correlationRow(icon: "figure.walk", label: String(localized: "歩数"), correlation: healthCorrelations.steps, colors: colors)
                        correlationRow(icon: "bed.double.fill", label: String(localized: "睡眠時間"), correlation: healthCorrelations.sleep, colors: colors)
                        correlationRow(icon: "heart.fill", label: String(localized: "安静時心拍数"), correlation: healthCorrelations.heartRate, colors: colors)
                        correlationRow(icon: "headphones", label: String(localized: "イヤホン使用"), correlation: healthCorrelations.headphone, colors: colors)
                        correlationRow(icon: "waveform.path.ecg", label: String(localized: "HRV（自律神経）"), correlation: healthCorrelations.hrv, colors: colors)
                        correlationRow(icon: "figure.run", label: String(localized: "運動時間"), correlation: healthCorrelations.exercise, colors: colors)
                    }

                    // Workout type breakdown
                    if !cachedWorkoutResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "運動の種類別"))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.accent)
                            ForEach(cachedWorkoutResults.prefix(4), id: \.workoutType) { result in
                                HStack(spacing: 10) {
                                    Text(result.workoutType)
                                        .font(.system(.subheadline, design: .rounded))
                                    Spacer()
                                    Text(String(format: "%.1f", result.averageScore))
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(colors.accent)
                                    if let next = result.nextDayAverageScore {
                                        Text(String(localized: "→翌日\(String(format: "%.1f", next))"))
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
                            }
                        }
                    }

                    // Headphone duration buckets
                    if !cachedHeadphoneResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "イヤホン使用時間別"))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.accent)
                            HStack(spacing: 6) {
                                ForEach(cachedHeadphoneResults, id: \.bucket) { result in
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.1f", result.averageScore))
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundStyle(colors.accent)
                                        Text(result.bucket)
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text("\(result.count)" + String(localized: "日"))
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
                                }
                            }
                        }
                    }

                    // Exercise threshold
                    if let threshold = cachedExerciseThreshold {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .font(.title3)
                                .foregroundStyle(colors.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "あなたの運動の分岐点: \(threshold.thresholdMinutes)分"))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                Text(String(localized: "\(threshold.thresholdMinutes)分以上: \(String(format: "%.1f", threshold.aboveAverage)) / 未満: \(String(format: "%.1f", threshold.belowAverage))"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    }

                    // HRV divergence alert
                    if let hrv = cachedHRVResult {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.title3)
                                    .foregroundStyle(hrv.divergenceDetected ? .orange : colors.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "HRV高い日: \(String(format: "%.1f", hrv.highHRVScore)) / 低い日: \(String(format: "%.1f", hrv.lowHRVScore))"))
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    if hrv.divergenceDetected {
                                        Text(String(localized: "体はストレスを感じているのに気分が高い日が\(hrv.divergenceCount)日。無理してるサインかも"))
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    }

                    Text(String(localized: "過去30日間のデータに基づく相関分析"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
        .task {
            await loadHealthCorrelations()
        }
    }

    /// Single correlation row display
    private func correlationRow(icon: String, label: String, correlation: Double?, colors: ThemeColors) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(colors.accent)
                .frame(width: 24)

            Text(label)
                .font(.system(.body, design: .rounded))

            Spacer()

            if let r = correlation {
                HStack(spacing: 4) {
                    // Correlation strength indicator
                    Image(systemName: r > 0 ? "arrow.up.right" : r < 0 ? "arrow.down.right" : "minus")
                        .font(.caption)
                        .foregroundStyle(correlationColor(r))

                    Text(correlationLabel(r))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(correlationColor(r))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(correlationColor(r).opacity(0.1))
                )
            } else {
                Text(String(localized: "データ不足"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func correlationColor(_ r: Double) -> Color {
        let abs = abs(r)
        if abs < 0.2 { return .gray }
        if r > 0 { return .green }
        return .orange
    }

    private func correlationLabel(_ r: Double) -> String {
        let abs = abs(r)
        if abs < 0.2 { return String(localized: "相関なし") }
        if abs < 0.4 { return r > 0 ? String(localized: "弱い正の相関") : String(localized: "弱い負の相関") }
        if abs < 0.6 { return r > 0 ? String(localized: "中程度の正の相関") : String(localized: "中程度の負の相関") }
        return r > 0 ? String(localized: "強い正の相関") : String(localized: "強い負の相関")
    }

    /// Load HealthKit data and compute correlations with mood
    private func loadHealthCorrelations() async {
        guard healthKitManager.isEnabled, !isLoadingHealthData else { return }
        isLoadingHealthData = true
        defer { isLoadingHealthData = false }

        let calendar = Calendar.current
        let endDate = Date.now
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else { return }

        let metrics = await healthKitManager.fetchDailyMetrics(from: startDate, to: endDate)

        // Build mood scores by date
        let moodByDate: [(date: Date, normalizedScore: Double)] = entries
            .filter { $0.createdAt >= startDate }
            .map { (calendar.startOfDay(for: $0.createdAt), $0.normalizedScore) }

        /// Compute all 7 correlations
        func values(for keyPath: KeyPath<DailyHealthMetric, Double?>) -> [(date: Date, value: Double)] {
            metrics.compactMap { m in
                guard let v = m[keyPath: keyPath] else { return nil }
                return (m.date, v)
            }
        }

        healthCorrelations = (
            steps: HealthKitManager.correlation(moodScores: moodByDate, healthValues: values(for: \.steps)),
            sleep: HealthKitManager.correlation(moodScores: moodByDate, healthValues: values(for: \.sleepHours)),
            heartRate: HealthKitManager.correlation(moodScores: moodByDate, healthValues: values(for: \.restingHeartRate)),
            headphone: HealthKitManager.correlation(moodScores: moodByDate, healthValues: values(for: \.headphoneMinutes)),
            hrv: HealthKitManager.correlation(moodScores: moodByDate, healthValues: values(for: \.hrvSDNN)),
            exercise: HealthKitManager.correlation(moodScores: moodByDate, healthValues: values(for: \.exerciseMinutes))
        )

        // Compute detailed analyses
        let recentEntries = entries.filter { $0.createdAt >= startDate }
        cachedWorkoutResults = statsVM.workoutMoodAnalysis(entries: recentEntries, metrics: metrics, currentMax: currentMaxScore, currentMin: currentMinScore)
        cachedHeadphoneResults = statsVM.headphoneMoodAnalysis(entries: recentEntries, metrics: metrics, currentMax: currentMaxScore, currentMin: currentMinScore)
        cachedExerciseThreshold = statsVM.exerciseThresholdAnalysis(entries: recentEntries, metrics: metrics, currentMax: currentMaxScore, currentMin: currentMinScore)
        cachedHRVResult = statsVM.hrvMoodAnalysis(entries: recentEntries, metrics: metrics, currentMax: currentMaxScore, currentMin: currentMinScore)
    }

    // MARK: - タグ分析セクション

    private func tagAnalysisSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("タグ分析")
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
        let frequency = statsVM.tagFrequency(entries: entries)
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
        let averages = statsVM.tagAverageScores(entries: entries, currentMax: currentMaxScore)
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
                        .foregroundStyle(colors.color(for: Int(item.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore).gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text(String(format: "%.1f", item.average))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXScale(domain: Double(currentMinScore) ... Double(currentMaxScore))
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
        let effects = statsVM.nextDayEffect(entries: entries, currentMax: currentMaxScore)

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
                            .foregroundStyle(item.delta >= 0 ? .green : .red)

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
        let coOccurrence = statsVM.tagCoOccurrence(entries: entries)
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

    // MARK: - メモキーワード分析セクション

    @ViewBuilder
    private func memoKeywordSection(colors: ThemeColors) -> some View {
        let keywords = statsVM.memoKeywordAnalysis(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let top10 = Array(keywords.prefix(10))

        if !top10.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "メモキーワード分析"), sectionKey: "memoKeyword", icon: "text.magnifyingglass")

                if expandedSections.contains("memoKeyword") {
                    VStack(spacing: 0) {
                        ForEach(top10, id: \.keyword) { item in
                            HStack {
                                Text(item.keyword)
                                    .font(.system(.subheadline, design: .rounded))

                                Spacer()

                                Text(String(format: "%.1f", item.avgScore))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.color(for: Int(item.avgScore.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))

                                Text("(\(item.count)\(String(localized: "回")))")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)

                            if item.keyword != top10.last?.keyword {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )

                    Text(String(localized: "メモに含まれるキーワードと平均スコアの関係"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - 記録元分析セクション

    @ViewBuilder
    private func sourceBreakdownSection(colors: ThemeColors) -> some View {
        let sources = statsVM.sourceAnalysis(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)

        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "記録元別分析"), sectionKey: "sourceBreakdown", icon: "square.stack.3d.up")

                if expandedSections.contains("sourceBreakdown") {
                    let sourceLabels: [String: (label: String, icon: String)] = [
                        "app": (String(localized: "アプリ"), "iphone"),
                        "widget": (String(localized: "ウィジェット"), "square.grid.2x2"),
                        "watch": (String(localized: "Apple Watch"), "applewatch"),
                    ]

                    HStack(spacing: 10) {
                        ForEach(sources, id: \.source) { item in
                            let info = sourceLabels[item.source] ?? (item.source, "questionmark.circle")
                            VStack(spacing: 8) {
                                Image(systemName: info.icon)
                                    .font(.title2)
                                    .foregroundStyle(colors.accent)

                                Text(info.label)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))

                                Text(String(format: "%.1f", item.avgScore))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.color(for: Int(item.avgScore.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))

                                Text("\(item.count)\(String(localized: "件"))")
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
                }
            }
        }
    }

    // MARK: - 記録タイミングセクション

    @ViewBuilder
    private func recordTimingSection(colors: ThemeColors) -> some View {
        let timing = statsVM.recordingTimingAnalysis(entries: entries)

        if !timing.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "記録タイミング"), sectionKey: "recordTiming", icon: "clock")

                if expandedSections.contains("recordTiming") {
                    Chart {
                        ForEach(timing, id: \.hour) { item in
                            BarMark(
                                x: .value(String(localized: "時間"), "\(item.hour)"),
                                y: .value(String(localized: "件数"), item.count)
                            )
                            .foregroundStyle(colors.accent.gradient)
                            .cornerRadius(3)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: ["0", "6", "12", "18", "23"]) { _ in
                            AxisValueLabel()
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel()
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                    .frame(height: 150)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )

                    // Peak hour
                    if let peak = timing.max(by: { $0.count < $1.count }) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(localized: "最も記録が多い時間帯: \(peak.hour)時台（\(peak.count)件）"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    // MARK: - 安定度スコアセクション

    @ViewBuilder
    private func stabilitySection(colors: ThemeColors) -> some View {
        let weekStability = statsVM.stabilityScore(entries: entries, days: 7)
        let monthStability = statsVM.stabilityScore(entries: entries, days: 30)

        if weekStability != nil || monthStability != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    collapsibleHeader(String(localized: "安定度スコア"), sectionKey: "stability", icon: "waveform.path")
                    infoButton(title: String(localized: "安定度スコア"), items: HelpContent.stabilityExplanation)
                }

                if expandedSections.contains("stability") {
                    HStack(spacing: 12) {
                        if let week = weekStability {
                            stabilityCard(
                                label: String(localized: "今週"),
                                score: week,
                                colors: colors
                            )
                        }
                        if let month = monthStability {
                            stabilityCard(
                                label: String(localized: "今月"),
                                score: month,
                                colors: colors
                            )
                        }
                    }

                    Text(String(localized: "100に近いほど気分が安定しています"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    /// Stability score card
    private func stabilityCard(label: String, score: Double, colors _: ThemeColors) -> some View {
        VStack(spacing: 8) {
            Text(String(format: "%.0f", score))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(score >= 70 ? .green : (score >= 40 ? .orange : .red))

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Text(score >= 70 ? String(localized: "安定") : (score >= 40 ? String(localized: "やや不安定") : String(localized: "不安定")))
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(score >= 70 ? .green : (score >= 40 ? .orange : .red))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - 天気×気分セクション

    @ViewBuilder
    private func weatherMoodSection(colors: ThemeColors) -> some View {
        let weatherData = statsVM.weatherMoodCorrelation(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)

        if !weatherData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "天気×気分"), sectionKey: "weatherMood", icon: "cloud.sun.fill")

                if expandedSections.contains("weatherMood") {
                    let weatherIcons: [String: String] = [
                        "sunny": "sun.max.fill",
                        "cloudy": "cloud.fill",
                        "rainy": "cloud.rain.fill",
                        "snowy": "cloud.snow.fill",
                        "stormy": "cloud.bolt.fill",
                        "foggy": "cloud.fog.fill",
                    ]
                    let weatherLabels: [String: String] = [
                        "sunny": String(localized: "晴れ"),
                        "cloudy": String(localized: "曇り"),
                        "rainy": String(localized: "雨"),
                        "snowy": String(localized: "雪"),
                        "stormy": String(localized: "嵐"),
                        "foggy": String(localized: "霧"),
                    ]

                    HStack(spacing: 10) {
                        ForEach(weatherData, id: \.condition) { item in
                            VStack(spacing: 8) {
                                Image(systemName: weatherIcons[item.condition] ?? "questionmark.circle")
                                    .font(.title2)
                                    .foregroundStyle(colors.accent)

                                Text(weatherLabels[item.condition] ?? item.condition)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))

                                Text(String(format: "%.1f", item.avgScore))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.color(for: Int(item.avgScore.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))

                                Text("\(item.count)\(String(localized: "件"))")
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
                }
            }
        }
    }

    // MARK: - エネルギー×気分セクション

    @ViewBuilder
    private func energyMoodSection(colors: ThemeColors) -> some View {
        let data = statsVM.energyMoodDivergence(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let total = data.aligned + data.divergent

        if total >= 5 {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "エネルギー×気分"), sectionKey: "energyMood", icon: "bolt.fill")

                if expandedSections.contains("energyMood") {
                    // Alignment ratio
                    let alignRate = total > 0 ? Int(Double(data.aligned) / Double(total) * 100) : 0
                    let divergeRate = total > 0 ? Int(Double(data.divergent) / Double(total) * 100) : 0

                    HStack(spacing: 12) {
                        VStack(spacing: 6) {
                            Text("\(alignRate)%")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.green)
                            Text(String(localized: "一致"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("\(data.aligned)\(String(localized: "件"))")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )

                        VStack(spacing: 6) {
                            Text("\(divergeRate)%")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.orange)
                            Text(String(localized: "乖離"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("\(data.divergent)\(String(localized: "件"))")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }

                    // Recent divergent entries
                    if !data.divergentEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "最近の乖離"))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(data.divergentEntries, id: \.date) { item in
                                let energyIcons = [1: "battery.25percent", 2: "battery.50percent", 3: "battery.100percent"]
                                let energyLabels = [1: String(localized: "低"), 2: String(localized: "普通"), 3: String(localized: "高")]

                                HStack {
                                    Text(item.date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 50, alignment: .leading)

                                    HStack(spacing: 4) {
                                        Text(String(localized: "スコア"))
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.tertiary)
                                        Text("\(item.score)")
                                            .font(.system(.caption, design: .rounded, weight: .bold))
                                            .foregroundStyle(colors.color(for: item.score, minScore: currentMinScore, maxScore: currentMaxScore))
                                    }

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Image(systemName: energyIcons[item.energy] ?? "battery.50percent")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                        Text(energyLabels[item.energy] ?? "-")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }

                    Text(String(localized: "気分とエネルギーが一致しているかの分析"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - 場所×気分セクション

    @ViewBuilder
    private func locationMoodSection(colors: ThemeColors) -> some View {
        let locationData = statsVM.locationMoodAnalysis(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)

        if !locationData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "場所×気分"), sectionKey: "locationMood", icon: "mappin.and.ellipse")

                if expandedSections.contains("locationMood") {
                    let locationIcons: [String: String] = [
                        "自宅": "house.fill", "Home": "house.fill",
                        "職場/学校": "building.2.fill", "Work/School": "building.2.fill",
                        "外出先": "figure.walk", "Outside": "figure.walk",
                        "移動中": "car.fill", "Commuting": "car.fill",
                    ]

                    VStack(spacing: 0) {
                        ForEach(locationData, id: \.location) { item in
                            HStack(spacing: 12) {
                                Image(systemName: locationIcons[item.location] ?? "mappin.circle")
                                    .font(.body)
                                    .foregroundStyle(colors.accent)
                                    .frame(width: 24)

                                Text(item.location)
                                    .font(.system(.subheadline, design: .rounded))

                                Spacer()

                                Text(String(format: "%.1f", item.avgScore))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.color(for: Int(item.avgScore.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))

                                Text("(\(item.count)\(String(localized: "件")))")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)

                            if item.location != locationData.last?.location {
                                Divider().padding(.leading, 48)
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
    }

    // MARK: - 回復パターンセクション

    @ViewBuilder
    private func recoverySection(colors: ThemeColors) -> some View {
        let patterns = statsVM.recoveryPatterns(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)

        if !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                collapsibleHeader(String(localized: "回復パターン"), sectionKey: "recovery", icon: "arrow.up.heart")

                if expandedSections.contains("recovery") {
                    ForEach(Array(patterns.prefix(5).enumerated()), id: \.offset) { _, event in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(event.lowPeriodStart.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)

                                Text(event.recoveryDate.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits)))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(String(localized: "\(event.daysToRecover)日で回復"))
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.green)
                            }

                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Text(String(localized: "低"))
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                    Text(String(format: "%.1f", event.lowScore))
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(.orange)
                                }

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)

                                HStack(spacing: 4) {
                                    Text(String(localized: "回復"))
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                    Text(String(format: "%.1f", event.recoveryScore))
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(.green)
                                }

                                if !event.recoveryTags.isEmpty {
                                    Spacer()
                                    HStack(spacing: 3) {
                                        ForEach(event.recoveryTags.prefix(2), id: \.self) { tag in
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
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }

                    if patterns.count > 1 {
                        let avgRecovery = patterns.reduce(0) { $0 + $1.daysToRecover } / patterns.count
                        Text(String(localized: "平均回復期間: \(avgRecovery)日"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    // MARK: - スコア予測セクション（プレミアム）

    @ViewBuilder
    private func predictionSection(colors: ThemeColors) -> some View {
        if entries.count >= PredictionEngine.minimumEntries {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(premiumManager.isPremium ? colors.accent : .orange)
                    Text(String(localized: "明日の予測"))
                        .font(.system(.headline, design: .rounded))
                    if !premiumManager.isPremium {
                        Text("PRO")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 4)

                if premiumManager.isPremium {
                    if let prediction = PredictionEngine.predictTomorrow(from: entries, currentMax: currentMaxScore, currentMin: currentMinScore) {
                        let range = Double(currentMaxScore - currentMinScore)
                        let low = prediction.rangeLow * range + Double(currentMinScore)
                        let high = prediction.rangeHigh * range + Double(currentMinScore)
                        let predicted = prediction.predictedScore * range + Double(currentMinScore)

                        VStack(alignment: .leading, spacing: 10) {
                            // Predicted score
                            HStack {
                                Text(String(localized: "予測スコア"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f", predicted))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.color(for: Int(predicted.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))
                            }

                            // Range
                            HStack {
                                Text(String(localized: "予測範囲"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f〜%.1f", low, high))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                            // Confidence
                            HStack {
                                Text(String(localized: "信頼度"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", prediction.confidence * 100))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(prediction.confidence >= 0.5 ? .green : .orange)
                            }

                            // Factors
                            if !prediction.factors.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "要因"))
                                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    ForEach(prediction.factors, id: \.self) { factor in
                                        HStack(spacing: 6) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.tertiary)
                                            Text(factor)
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundStyle(.secondary)
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
                    } else {
                        Text(String(localized: "予測データを準備中です"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                    }
                } else {
                    // Locked preview — direct ProView CTA
                    proLockedCard(
                        message: String(localized: "明日のスコアをAIが予測します"),
                        colors: colors
                    )
                }
            }
        }
    }

    // MARK: - タグ遷移マップセクション（プレミアム）

    @ViewBuilder
    private func tagFlowSection(colors: ThemeColors) -> some View {
        let chains = statsVM.tagChainPatterns(entries: entries, currentMax: currentMaxScore)

        if !chains.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(premiumManager.isPremium ? colors.accent : .orange)
                    Text(String(localized: "タグ遷移マップ"))
                        .font(.system(.headline, design: .rounded))
                    if !premiumManager.isPremium {
                        Text("PRO")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 4)

                if premiumManager.isPremium {
                    TagFlowView(transitions: chains, colors: colors)
                } else {
                    proLockedCard(
                        message: String(localized: "タグの流れと遷移パターンを可視化します"),
                        colors: colors
                    )
                }
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
                    Text("発見")
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
        if let data = statsVM.recordCountVsScore(entries: entries, currentMax: currentMaxScore) {
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
                        valueColor: colors.color(for: Int(data.multiAvg.rounded()), minScore: currentMinScore, maxScore: currentMaxScore)
                    )
                    discoveryStatColumn(
                        label: "1回/日",
                        value: String(format: "%.1f", data.singleAvg),
                        sub: "\(data.singleDays)日",
                        valueColor: colors.color(for: Int(data.singleAvg.rounded()), minScore: currentMinScore, maxScore: currentMaxScore)
                    )
                    discoveryDeltaColumn(delta: delta)
                }
            }
        }
    }

    /// タグ使用とスコアの関係
    @ViewBuilder
    private func tagUsageDiscovery(colors: ThemeColors) -> some View {
        if let data = statsVM.tagUsageVsScore(entries: entries, currentMax: currentMaxScore) {
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
                        valueColor: colors.color(for: Int(data.taggedAvg.rounded()), minScore: currentMinScore, maxScore: currentMaxScore)
                    )
                    discoveryStatColumn(
                        label: "タグなし",
                        value: String(format: "%.1f", data.untaggedAvg),
                        sub: "\(data.untaggedCount)件",
                        valueColor: colors.color(for: Int(data.untaggedAvg.rounded()), minScore: currentMinScore, maxScore: currentMaxScore)
                    )
                    discoveryDeltaColumn(delta: delta)
                }
            }
        }
    }

    /// 詳細な共起パターン
    @ViewBuilder
    private func detailedCoOccurrenceDiscovery(colors: ThemeColors) -> some View {
        let pairs = statsVM.detailedCoOccurrence(entries: entries)

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
                    // --- フル表示（Groupで分割し型推論の深さを制限） ---
                    Group {
                        premiumInsightCarousel(colors: colors)
                        reverseInsightsCard(colors: colors)
                        monthlySummaryCard(colors: colors)
                        tagChainCard(colors: colors)
                    }
                    Group {
                        tagEchoCard(colors: colors)
                        divergenceAlertCard(colors: colors)
                        recoveryTriggerCard(colors: colors)
                        synergyCard(colors: colors)
                    }
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
                .foregroundStyle(premiumManager.isPremium ? colors.accent : .orange)
            Text("高度な分析")
                .font(.system(.headline, design: .rounded))
            if !premiumManager.isPremium {
                Text("PRO")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.orange))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 4)
    }

    /// ロック表示（無料ユーザー向け — グラデーションマスク + CTAボタン）
    private func premiumLockedPreview(colors: ThemeColors) -> some View {
        VStack(spacing: 0) {
            // Preview cards with gradient fade-out mask
            VStack(spacing: 12) {
                lockedPreviewCard(
                    icon: "brain.head.profile",
                    title: String(localized: "逆インサイト"),
                    preview: String(localized: "好調時に多いタグ、不在タグを分析して改善ヒントを提案"),
                    colors: colors
                )
                lockedPreviewCard(
                    icon: "arrow.triangle.branch",
                    title: String(localized: "タグ連鎖パターン"),
                    preview: String(localized: "ストレス → 甘いもの → 体調不良 のような遷移を可視化"),
                    colors: colors
                )
                lockedPreviewCard(
                    icon: "waveform.path.ecg",
                    title: String(localized: "残響効果"),
                    preview: String(localized: "運動した翌日、2日後、3日後…の気分変化を追跡"),
                    colors: colors
                )
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.4),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // CTA button overlapping the fade zone
            Button {
                showProView = true
                HapticManager.lightFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(String(localized: "プレミアムで全機能を解放"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, -20) // Overlap with fade zone
        }
    }

    /// ロックプレビューカード1枚（blurなし、テキスト readable）
    private func lockedPreviewCard(icon: String, title: String, preview: String, colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(colors.accent)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(preview)
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
                .stroke(.orange.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - プレミアムインサイトカルーセル

    @ViewBuilder
    private func premiumInsightCarousel(colors: ThemeColors) -> some View {
        let insights = cachedPremiumInsights
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

    // MARK: - A. 逆インサイトカード

    @ViewBuilder
    private func reverseInsightsCard(colors: ThemeColors) -> some View {
        let data = statsVM.reverseInsights(entries: entries, currentMax: currentMaxScore)
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

            if let summary = statsVM.monthlySummary(entries: entries, currentMax: currentMaxScore, month: summaryMonth) {
                // 平均 + 前月比
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("平均スコア")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f", summary.average))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(colors.color(for: Int(summary.average.rounded()), minScore: currentMinScore, maxScore: currentMaxScore))
                            if let prev = summary.previousMonthAverage {
                                let diff = summary.average - prev
                                HStack(spacing: 2) {
                                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption2)
                                    Text(String(format: "%+.1f", diff))
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                }
                                .foregroundStyle(diff >= 0 ? .green : .orange)
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

                // ベスト/ワースト
                HStack(spacing: 10) {
                    if let best = summary.bestDay {
                        miniDayCard(label: "ベストの日", score: best.score, date: best.date, memo: best.memo, iconColor: .green, colors: colors)
                    }
                    if let worst = summary.worstDay {
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

    /// ポジ/ネガ比率バー
    private func monthlySummaryRatioBar(posRate: Double, negRate: Double, colors _: ThemeColors) -> some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: geo.size.width * max(posRate, 0.05))
                Rectangle()
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: geo.size.width * max(negRate, 0.05))
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
                    .foregroundStyle(colors.color(for: score, minScore: currentMinScore, maxScore: currentMaxScore))
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
        let chains = statsVM.tagChainPatterns(entries: entries, currentMax: currentMaxScore)
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
        let echoes = statsVM.tagEchoEffect(entries: entries, currentMax: currentMaxScore)
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
                .foregroundStyle(value < 0 ? .red : .green)
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
        let divergences = statsVM.actionScoreDivergence(entries: entries, currentMax: currentMaxScore)
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
                                .foregroundStyle(.red)
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
        let triggers = statsVM.recoveryTriggers(entries: entries, currentMax: currentMaxScore)
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
        let synergies = statsVM.tagSynergyAnalysis(entries: entries, currentMax: currentMaxScore)
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

    // MARK: - Premium Info Sheet

    /// Simplified premium info sheet — directs user to PRO tab for full purchase flow
    /// Compact locked card for individual PRO sections (prediction, tagFlow)
    private func proLockedCard(message: String, colors _: ThemeColors) -> some View {
        Button {
            showProView = true
            HapticManager.lightFeedback()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Text(String(localized: "PRO"))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.orange.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - アクティビティセクション

    private func activitySection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("アクティビティ")
                .font(.system(.headline, design: .rounded))
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
                .foregroundStyle(colors.color(for: entry.score, minScore: entry.scoreRangeMin, maxScore: entry.maxScore))
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

    private func allEntriesView(colors: ThemeColors) -> some View {
        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries, id: \.id) { entry in
                        entryRow(entry: entry, colors: colors)

                        if entry.id != entries.last?.id {
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
        .navigationTitle("すべての記録")
        .navigationBarTitleDisplayMode(.inline)
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
                        Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(String(format: "%+.1f", diff))
                            .font(.system(.caption, design: .rounded))
                    }
                    .foregroundStyle(diff >= 0 ? .green : .red)
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
}

#Preview {
    StatsView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
