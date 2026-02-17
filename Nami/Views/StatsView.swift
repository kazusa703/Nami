//
//  StatsView.swift
//  Nami
//
//  統計画面 - 平均スコア、連続日数、スコア分布等を表示する
//

import SwiftUI
import SwiftData
import Charts
import StoreKit

/// 統計画面
/// 週間/月間/年間の平均スコア、スコア分布、連続記録日数を表示する
struct StatsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
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

    /// プレミアム状態
    @Environment(\.premiumManager) private var premiumManager
    /// 月間サマリーの表示月
    @State private var summaryMonth: Date = Date.now
    /// プレミアム購入シート表示
    @State private var showPremiumSheet = false

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            if entries.isEmpty {
                                // データがない場合 — 何がわかるようになるかを案内
                                emptyStatsView(colors: colors)
                            } else {
                                // インサイトカルーセル（最上部）
                                insightCarousel(colors: colors)

                                // 週間レビュー（先週のふりかえり）
                                weeklyReviewSection(colors: colors)

                                // ムードリズム（インサイトの直下）
                                moodRhythmSection(colors: colors)

                                // サマリーカード（2×2グリッド）
                                summaryCards(colors: colors)

                                // スコア分布チャート
                                distributionSection(colors: colors)

                                // 平均スコアセクション
                                averageSection(colors: colors)

                                // あの頃の自分と比較セクション
                                pastComparisonSection(colors: colors)

                                // 曜日別平均セクション
                                weekdayAverageSection(colors: colors)

                                // 時間帯別平均セクション
                                timeOfDaySection(colors: colors)

                                // ストリーク比較セクション
                                streakSection(colors: colors)

                                // 月間カレンダーヒートマップ
                                calendarHeatmapSection(colors: colors)

                                // タグ分析セクション（タグ付きエントリがある場合のみ）
                                if entries.contains(where: { !$0.tags.isEmpty }) {
                                    tagAnalysisSection(colors: colors)
                                }

                                // 高度な分析（プレミアム）セクション
                                premiumAnalyticsSection(colors: colors)

                                // 発見セクション（隠れた相関）
                                discoverySection(colors: colors)

                                // アクティビティセクション
                                activitySection(colors: colors)
                            }
                        }
                        .padding()
                    }

                    // 広告バナー（画面最下部に固定）
                    BannerAdView()
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                PremiumPurchaseSheet(premiumManager: premiumManager)
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
        }
    }

    // MARK: - 空状態ビュー

    /// データ0件時に「記録すると何がわかるか」を案内するビュー
    @ViewBuilder
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

    // MARK: - インサイトカルーセル

    @ViewBuilder
    private func insightCarousel(colors: ThemeColors) -> some View {
        let insights = InsightEngine.generate(from: entries, currentMax: currentMaxScore)

        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("インサイト")
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
    @ViewBuilder
    private func insightCardView(card: InsightCard, colors: ThemeColors) -> some View {
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
    @ViewBuilder
    private func weeklyReviewAverageRow(review: WeeklyReview, colors: ThemeColors) -> some View {
        HStack {
            Text("平均スコア")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "%.1f", review.average))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(colors.color(for: Int(review.average.rounded()), maxScore: currentMaxScore))

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
    @ViewBuilder
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
    @ViewBuilder
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
                    .foregroundStyle(colors.color(for: point.score, maxScore: currentMaxScore))

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
    @ViewBuilder
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
        let hasRhythmData = rhythmData.contains { $0.average > 0 }

        if hasRhythmData {
            VStack(alignment: .leading, spacing: 16) {
                Text("あなたの1週間のリズム")
                    .font(.system(.headline, design: .rounded))
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
    @ViewBuilder
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
                        .foregroundStyle(colors.color(for: Int(item.average.rounded()), maxScore: currentMaxScore))
                        .symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f", item.average))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.color(for: Int(item.average.rounded()), maxScore: currentMaxScore))
                        }
                    }
                }
            }
            .chartYScale(domain: 1...Double(currentMaxScore))
            .chartYAxis {
                AxisMarks(values: [1, Double(currentMaxScore)]) { _ in
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
               best.label != worst.label {
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
    @ViewBuilder
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
        .chartYScale(domain: 0...yMax)
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

    @ViewBuilder
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
            let distribution = statsVM.scoreDistribution(entries: entries, maxScore: currentMaxScore)
            let maxCount = distribution.values.max() ?? 1

            // 分布が大きい場合はグルーピング表示
            if currentMaxScore > 30 {
                groupedDistributionChart(distribution: distribution, maxCount: maxCount, colors: colors)
            } else {
                Chart {
                    ForEach(1...currentMaxScore, id: \.self) { score in
                        let count = distribution[score] ?? 0
                        BarMark(
                            x: .value("回数", count),
                            y: .value("スコア", "\(score)")
                        )
                        .foregroundStyle(colors.color(for: score, maxScore: currentMaxScore).gradient)
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
                .chartXScale(domain: 0...(maxCount + 1))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                }
                .frame(height: CGFloat(currentMaxScore) * 28)
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
    private func groupedDistributionChart(distribution: [Int: Int], maxCount: Int, colors: ThemeColors) -> some View {
        let groupSize = 10
        let groups = stride(from: 1, through: currentMaxScore, by: groupSize).map { start -> (label: String, count: Int) in
            let end = min(start + groupSize - 1, currentMaxScore)
            let count = (start...end).reduce(0) { $0 + (distribution[$1] ?? 0) }
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
        .chartXScale(domain: 0...(groupMax + 1))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
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

    @ViewBuilder
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

    @ViewBuilder
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

    @ViewBuilder
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
                            ? colors.color(for: Int(avg.rounded()), maxScore: currentMaxScore).gradient
                            : Color.gray.opacity(0.3).gradient
                    )
                    .cornerRadius(6)
                }
            }
            .chartYScale(domain: 0...Double(currentMaxScore))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .rounded))
                }
            }
            .chartXAxis {
                AxisMarks { value in
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

    @ViewBuilder
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
                                .foregroundStyle(colors.color(for: Int(avg.rounded()), maxScore: currentMaxScore))
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

    @ViewBuilder
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

    @ViewBuilder
    private func calendarHeatmapSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月間カレンダー")
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 4)

            MonthlyHeatmapView(
                entries: entries,
                currentMaxScore: currentMaxScore,
                colors: colors
            )
        }
    }

    // MARK: - タグ分析セクション

    @ViewBuilder
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
                        .foregroundStyle(colors.color(for: Int(item.average.rounded()), maxScore: currentMaxScore).gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text(String(format: "%.1f", item.average))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXScale(domain: 0...Double(currentMaxScore))
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
    private func nextDayEffectList(colors: ThemeColors) -> some View {
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
                        valueColor: colors.color(for: Int(data.multiAvg.rounded()), maxScore: currentMaxScore)
                    )
                    discoveryStatColumn(
                        label: "1回/日",
                        value: String(format: "%.1f", data.singleAvg),
                        sub: "\(data.singleDays)日",
                        valueColor: colors.color(for: Int(data.singleAvg.rounded()), maxScore: currentMaxScore)
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
                        valueColor: colors.color(for: Int(data.taggedAvg.rounded()), maxScore: currentMaxScore)
                    )
                    discoveryStatColumn(
                        label: "タグなし",
                        value: String(format: "%.1f", data.untaggedAvg),
                        sub: "\(data.untaggedCount)件",
                        valueColor: colors.color(for: Int(data.untaggedAvg.rounded()), maxScore: currentMaxScore)
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
    @ViewBuilder
    private func discoveryCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        colors: ThemeColors,
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
    @ViewBuilder
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
    @ViewBuilder
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
    @ViewBuilder
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

    /// ロック表示（無料ユーザー向け）
    @ViewBuilder
    private func premiumLockedPreview(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            // プレビューカード3枚（ぼかし付き）
            lockedPreviewCard(
                icon: "brain.head.profile",
                title: "逆インサイト",
                preview: "好調時に多いタグ、不在タグを分析...",
                colors: colors
            )
            lockedPreviewCard(
                icon: "arrow.triangle.branch",
                title: "タグ連鎖パターン",
                preview: "タグの遷移パターンを可視化...",
                colors: colors
            )
            lockedPreviewCard(
                icon: "waveform.path.ecg",
                title: "残響効果",
                preview: "タグの影響が何日続くか計測...",
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
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// ロックプレビューカード1枚
    @ViewBuilder
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
                .blur(radius: 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.orange.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - プレミアムインサイトカルーセル

    @ViewBuilder
    private func premiumInsightCarousel(colors: ThemeColors) -> some View {
        let insights = InsightEngine.generatePremium(from: entries, currentMax: currentMaxScore)
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
    @ViewBuilder
    private func tagRateBadge(tag: String, rate: Int, color: Color, colors: ThemeColors) -> some View {
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

    @ViewBuilder
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
                                .foregroundStyle(colors.color(for: Int(summary.average.rounded()), maxScore: currentMaxScore))
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
    @ViewBuilder
    private func monthlySummaryRatioBar(posRate: Double, negRate: Double, colors: ThemeColors) -> some View {
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
    @ViewBuilder
    private func miniDayCard(label: String, score: Int, date: Date, memo: String?, iconColor: Color, colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(iconColor)
            HStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(colors.color(for: score, maxScore: currentMaxScore))
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
    private func echoMiniChart(effects: [Double], colors: ThemeColors) -> some View {
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
    private func divergenceAlertCard(colors: ThemeColors) -> some View {
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
    private func recoveryTriggerCard(colors: ThemeColors) -> some View {
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
    @ViewBuilder
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

    // MARK: - プレミアム購入シート

    /// プレミアム購入シート（StatsViewから呼び出し用）
    struct PremiumPurchaseSheet: View {
        let premiumManager: PremiumManager
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    Text("プレミアムで全機能を解放")
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    VStack(alignment: .leading, spacing: 10) {
                        premiumFeatureRow(icon: "brain.head.profile", text: "逆インサイト・回復トリガー分析")
                        premiumFeatureRow(icon: "calendar.badge.clock", text: "月間サマリーレポート")
                        premiumFeatureRow(icon: "arrow.triangle.branch", text: "タグ連鎖・残響効果分析")
                        premiumFeatureRow(icon: "arrow.triangle.merge", text: "タグシナジー・レッドゾーン検出")
                        premiumFeatureRow(icon: "xmark.circle", text: "広告の非表示")
                    }
                    .padding()

                    if let product = premiumManager.product {
                        Button {
                            Task { await premiumManager.purchase() }
                        } label: {
                            HStack {
                                if premiumManager.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("\(product.displayPrice)で購入")
                                        .font(.system(.headline, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                            )
                        }
                        .disabled(premiumManager.isPurchasing)
                    }

                    Button("復元") {
                        Task { await premiumManager.restore() }
                    }
                    .font(.system(.caption, design: .rounded))

                    if let error = premiumManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
            .onChange(of: premiumManager.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
        }

        @ViewBuilder
        private func premiumFeatureRow(icon: String, text: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                Text(text)
                    .font(.system(.subheadline, design: .rounded))
            }
        }
    }

    // MARK: - アクティビティセクション

    @ViewBuilder
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

    @ViewBuilder
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
    @ViewBuilder
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
    @ViewBuilder
    private func averageRow(label: String, current: Double?, previous: Double?, previousLabel: String, colors: ThemeColors) -> some View {
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
