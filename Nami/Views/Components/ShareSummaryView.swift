//
//  ShareSummaryView.swift
//  Nami
//
//  シェア用サマリー画面 - 週間/月間/月間レポートを切り替えてプレビュー + 画像生成 + 共有
//

import SwiftUI
import SwiftData

/// シェア期間の選択肢
enum SharePeriod: String, CaseIterable, Identifiable {
    case weekly = "週間"
    case monthly = "月間"
    case monthlyReport = "月間レポート"

    var id: String { rawValue }
}

/// シェアサマリーシート
struct ShareSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let entries: [MoodEntry]
    let currentMaxScore: Int
    let currentMinScore: Int
    let themeColors: ThemeColors
    let statsVM: StatsViewModel

    @State private var selectedPeriod: SharePeriod = .weekly
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var shareText: String?

    init(entries: [MoodEntry], currentMaxScore: Int, currentMinScore: Int = 1, themeColors: ThemeColors, statsVM: StatsViewModel) {
        self.entries = entries
        self.currentMaxScore = currentMaxScore
        self.currentMinScore = currentMinScore
        self.themeColors = themeColors
        self.statsVM = statsVM
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeColors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Period picker
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(SharePeriod.allCases) { period in
                            Text(LocalizedStringKey(period.rawValue)).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Card preview
                    ScrollView {
                        if selectedPeriod == .monthlyReport {
                            monthlyReportCard
                                .padding()
                        } else {
                            summaryCard
                                .padding()
                        }
                    }

                    Spacer()

                    // Share button
                    Button {
                        generateAndShare()
                    } label: {
                        Label("シェアする", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeColors.accent)
                            )
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("サマリーをシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                } else if let text = shareText {
                    ShareSheet(items: [text])
                }
            }
        }
    }

    // MARK: - Summary Card (existing weekly/monthly)

    private var summaryCard: some View {
        let data = cardData
        return SummaryCardView(
            periodLabel: data.periodLabel,
            averageScore: data.averageScore,
            trend: data.trend,
            entryCount: data.entryCount,
            sparklineData: data.sparkline,
            maxScore: currentMaxScore,
            accentColor: themeColors.accent,
            graphLineColor: .white,
            graphFillColor: themeColors.graphFill,
            bgStart: themeColors.accent,
            bgEnd: themeColors.accent.opacity(0.7)
        )
    }

    // MARK: - Monthly Report Card

    private var monthlyReportCard: some View {
        let reportData = buildReportData()
        return MonthlyReportCardView(
            data: reportData,
            accentColor: themeColors.accent,
            bgStart: themeColors.accent,
            bgEnd: themeColors.accent.opacity(0.7),
            themeColors: themeColors
        )
    }

    private func buildReportData() -> MonthlyReportData {
        let calendar = Calendar.current
        let now = Date.now
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now

        let monthEntries = entries.filter { $0.createdAt >= startOfMonth }

        // Month/Year label
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年M月"
        let monthLabel = formatter.string(from: now)

        // Average
        let avg = statsVM.monthlyAverage(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore) ?? 0

        // Trend vs previous month
        let prevAvg = statsVM.lastMonthAverage(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let trend: Double? = prevAvg != nil ? avg - prevAvg! : nil

        // Monthly summary for best/worst day, topTags, activeDays
        let summary = statsVM.monthlySummary(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore, month: now)

        // Best day
        var bestDay: (date: Date, score: Int)?
        if let bd = summary?.bestDay {
            bestDay = (bd.date, bd.score)
        }

        // Worst day
        var worstDay: (date: Date, score: Int)?
        if let wd = summary?.worstDay {
            worstDay = (wd.date, wd.score)
        }

        // Top 3 tags
        let topTags = Array((summary?.topTags ?? []).prefix(3).map { $0.tag })

        // Current streak
        let streak = statsVM.currentStreak(entries: entries)

        // Weather summary - most common condition this month
        let weatherEntries = monthEntries.compactMap { $0.weatherCondition }
        var weatherCounts: [String: Int] = [:]
        for w in weatherEntries { weatherCounts[w, default: 0] += 1 }
        let topWeather = weatherCounts.max(by: { $0.value < $1.value })?.key

        // Daily scores for color bar (one per day of month)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        var dailyScores: [Double?] = Array(repeating: nil, count: daysInMonth)
        for entry in monthEntries {
            let day = calendar.component(.day, from: entry.createdAt) - 1
            if day >= 0 && day < daysInMonth {
                // Use normalizedScore (0.0-1.0)
                dailyScores[day] = entry.normalizedScore
            }
        }

        return MonthlyReportData(
            monthLabel: monthLabel,
            averageScore: avg,
            trend: trend,
            maxScore: currentMaxScore,
            minScore: currentMinScore,
            bestDay: bestDay,
            worstDay: worstDay,
            topTags: topTags,
            streak: streak,
            topWeather: topWeather,
            totalEntries: monthEntries.count,
            activeDays: summary?.activeDays ?? 0,
            dailyScores: dailyScores
        )
    }

    // MARK: - Data Calculation (existing)

    private var cardData: (periodLabel: String, averageScore: Double, trend: Double?, entryCount: Int, sparkline: [Double]) {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .weekly:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let weekEntries = entries.filter { $0.createdAt >= startOfWeek }
            let avg = statsVM.weeklyAverage(entries: entries, currentMax: currentMaxScore) ?? 0
            let trend = statsVM.weeklyTrend(entries: entries, currentMax: currentMaxScore)
            let sparkline = statsVM.sparklineData(entries: entries, since: startOfWeek)
            return (String(localized: "今週のまとめ"), avg, trend, weekEntries.count, sparkline)

        case .monthly, .monthlyReport:
            let startOfMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
            let monthEntries = entries.filter { $0.createdAt >= startOfMonth }
            let avg = statsVM.monthlyAverage(entries: entries, currentMax: currentMaxScore) ?? 0
            let currentAvg = statsVM.monthlyAverage(entries: entries, currentMax: currentMaxScore)
            let prevAvg = statsVM.lastMonthAverage(entries: entries, currentMax: currentMaxScore)
            let trend: Double? = (currentAvg != nil && prevAvg != nil) ? currentAvg! - prevAvg! : nil
            let sparkline = statsVM.sparklineData(entries: entries, since: startOfMonth)
            return (String(localized: "今月のまとめ"), avg, trend, monthEntries.count, sparkline)
        }
    }

    // MARK: - Image Generation + Share

    private func generateAndShare() {
        if selectedPeriod == .monthlyReport {
            generateReportAndShare()
        } else {
            generateSummaryAndShare()
        }
    }

    private func generateSummaryAndShare() {
        let data = cardData
        let cardView = SummaryCardView(
            periodLabel: data.periodLabel,
            averageScore: data.averageScore,
            trend: data.trend,
            entryCount: data.entryCount,
            sparklineData: data.sparkline,
            maxScore: currentMaxScore,
            accentColor: themeColors.accent,
            graphLineColor: .white,
            graphFillColor: themeColors.graphFill,
            bgStart: themeColors.accent,
            bgEnd: themeColors.accent.opacity(0.7)
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        } else {
            shareImage = nil
            shareText = "\(data.periodLabel) - 平均スコア: \(String(format: "%.1f", data.averageScore)) (\(data.entryCount)件記録) #Nami"
            showShareSheet = true
        }
    }

    private func generateReportAndShare() {
        let reportData = buildReportData()
        let cardView = MonthlyReportCardView(
            data: reportData,
            accentColor: themeColors.accent,
            bgStart: themeColors.accent,
            bgEnd: themeColors.accent.opacity(0.7),
            themeColors: themeColors
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        } else {
            shareImage = nil
            shareText = "\(reportData.monthLabel) - 平均スコア: \(String(format: "%.1f", reportData.averageScore)) (\(reportData.totalEntries)件記録) #Nami"
            showShareSheet = true
        }
    }
}

// MARK: - Monthly Report Data

struct MonthlyReportData {
    let monthLabel: String
    let averageScore: Double
    let trend: Double?
    let maxScore: Int
    let minScore: Int
    let bestDay: (date: Date, score: Int)?
    let worstDay: (date: Date, score: Int)?
    let topTags: [String]
    let streak: Int
    let topWeather: String?
    let totalEntries: Int
    let activeDays: Int
    let dailyScores: [Double?]  // normalizedScore per day-of-month (nil = no entry)
}

// MARK: - Monthly Report Card View (Instagram story aspect ratio)

/// Visually rich monthly report card for SNS sharing.
/// Designed for ~9:16 aspect ratio (Instagram stories).
/// All data passed as parameters (no @Environment) for ImageRenderer compatibility.
struct MonthlyReportCardView: View {
    let data: MonthlyReportData
    let accentColor: Color
    let bgStart: Color
    let bgEnd: Color
    let themeColors: ThemeColors

    private let cardWidth: CGFloat = 390
    private let cardHeight: CGFloat = 692

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.top, 32)
                .padding(.horizontal, 28)

            // Average Score (hero)
            averageScoreSection
                .padding(.top, 24)
                .padding(.horizontal, 28)

            // Stats grid
            statsGridSection
                .padding(.top, 24)
                .padding(.horizontal, 28)

            // Top tags
            if !data.topTags.isEmpty {
                topTagsSection
                    .padding(.top, 20)
                    .padding(.horizontal, 28)
            }

            // Daily color bar
            dailyColorBarSection
                .padding(.top, 20)
                .padding(.horizontal, 28)

            Spacer(minLength: 12)

            // Footer watermark
            footerSection
                .padding(.bottom, 24)
                .padding(.horizontal, 28)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [bgStart, bgEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(String(localized: "月間レポート"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(2)

            Text(data.monthLabel + String(localized: "のまとめ"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Average Score

    private var averageScoreSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", data.averageScore))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("/ \(data.maxScore)")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Trend badge
            if let trend = data.trend {
                HStack(spacing: 4) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(.caption, weight: .bold))
                    Text(String(format: "%+.1f", trend))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                    Text(String(localized: "先月比"))
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(trend >= 0 ? Color.green : Color.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((trend >= 0 ? Color.green : Color.red).opacity(0.2))
                )
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGridSection: some View {
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale.current
            f.dateFormat = "M/d"
            return f
        }()

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Best day
                statCell(
                    icon: "sun.max.fill",
                    iconColor: .yellow,
                    label: String(localized: "ベストデー"),
                    value: data.bestDay.map { "\(dateFormatter.string(from: $0.date)) (\($0.score))" } ?? "-"
                )

                // Worst day
                statCell(
                    icon: "cloud.rain.fill",
                    iconColor: .blue.opacity(0.7),
                    label: String(localized: "ワーストデー"),
                    value: data.worstDay.map { "\(dateFormatter.string(from: $0.date)) (\($0.score))" } ?? "-"
                )
            }

            HStack(spacing: 12) {
                // Streak
                statCell(
                    icon: "flame.fill",
                    iconColor: .orange,
                    label: String(localized: "連続記録"),
                    value: String(localized: "\(data.streak)日")
                )

                // Total entries
                statCell(
                    icon: "pencil.line",
                    iconColor: .white.opacity(0.8),
                    label: String(localized: "記録数"),
                    value: String(localized: "\(data.totalEntries)件 / \(data.activeDays)日")
                )
            }

            // Weather row (if available)
            if let weather = data.topWeather {
                HStack(spacing: 12) {
                    statCell(
                        icon: weatherIcon(for: weather),
                        iconColor: .white.opacity(0.8),
                        label: String(localized: "よくある天気"),
                        value: weatherDisplayName(for: weather)
                    )

                    // Empty cell for balance
                    Color.clear
                        .frame(height: 1)
                }
            }
        }
    }

    private func statCell(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.1))
        )
    }

    // MARK: - Top Tags

    private var topTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "よく使ったタグ"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 8) {
                ForEach(data.topTags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.15))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Daily Color Bar

    private var dailyColorBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "日別スコア"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            // Thin horizontal strip: each day = small colored segment
            HStack(spacing: 1) {
                ForEach(0..<data.dailyScores.count, id: \.self) { index in
                    if let score = data.dailyScores[index] {
                        let intScore = Int((score * Double(data.maxScore - data.minScore) + Double(data.minScore)).rounded())
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(themeColors.color(for: intScore, minScore: data.minScore, maxScore: data.maxScore))
                            .frame(height: 16)
                    } else {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.white.opacity(0.08))
                            .frame(height: 16)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text(Date.now, format: .dateTime.year().month().day())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))

            Spacer()

            Text("Nami")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Weather Helpers

    private func weatherIcon(for condition: String) -> String {
        switch condition {
        case "sunny": return "sun.max.fill"
        case "cloudy": return "cloud.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "stormy": return "cloud.bolt.fill"
        case "foggy": return "cloud.fog.fill"
        default: return "questionmark.circle"
        }
    }

    private func weatherDisplayName(for condition: String) -> String {
        switch condition {
        case "sunny": return String(localized: "晴れ")
        case "cloudy": return String(localized: "曇り")
        case "rainy": return String(localized: "雨")
        case "snowy": return String(localized: "雪")
        case "stormy": return String(localized: "嵐")
        case "foggy": return String(localized: "霧")
        default: return condition
        }
    }
}

#Preview {
    ShareSummaryView(
        entries: [],
        currentMaxScore: 10,
        currentMinScore: 1,
        themeColors: .ocean,
        statsVM: StatsViewModel()
    )
}
