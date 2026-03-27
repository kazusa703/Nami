//
//  ShareSummaryView.swift
//  Nami
//
//  シェア用サマリー画面 - 週間/月間/月間レポートを切り替えてプレビュー + 画像生成 + 共有
//

import SwiftData
import SwiftUI

/// シェア期間の選択肢
enum SharePeriod: String, CaseIterable, Identifiable {
    case weekly = "週間"
    case monthly = "月間"
    case monthlyReport = "月間レポート"
    case pdf = "PDF"

    var id: String {
        rawValue
    }
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
    @State private var sharePDFURL: URL?

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
                        switch selectedPeriod {
                        case .monthlyReport:
                            monthlyReportCard
                                .padding()
                        case .pdf:
                            pdfPreview
                                .padding()
                        default:
                            summaryCard
                                .padding()
                        }
                    }

                    Spacer()

                    // Share button
                    Button {
                        generateAndShare()
                    } label: {
                        Label(
                            selectedPeriod == .pdf ? String(localized: "PDFを書き出す") : String(localized: "シェアする"),
                            systemImage: selectedPeriod == .pdf ? "doc.text" : "square.and.arrow.up"
                        )
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
                if let pdfURL = sharePDFURL {
                    ShareSheet(items: [pdfURL])
                } else if let image = shareImage {
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
        for w in weatherEntries {
            weatherCounts[w, default: 0] += 1
        }
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

        case .monthly, .monthlyReport, .pdf:
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
        sharePDFURL = nil
        shareImage = nil
        switch selectedPeriod {
        case .monthlyReport:
            generateReportAndShare()
        case .pdf:
            generatePDFAndShare()
        default:
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

    // MARK: - PDF Preview

    private var pdfPreview: some View {
        let reportData = buildReportData()
        let weekdayAvg = statsVM.weekdayAverages(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let timeOfDayAvg = statsVM.timeOfDayAverages(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let tagFreq = statsVM.tagFrequency(entries: entries)

        return PDFReportPreview(
            reportData: reportData,
            weekdayAverages: weekdayAvg,
            timeOfDayAverages: timeOfDayAvg,
            topTags: Array(tagFreq.prefix(5)),
            currentMaxScore: currentMaxScore,
            currentMinScore: currentMinScore,
            themeColors: themeColors
        )
    }

    // MARK: - PDF Generation

    private func generatePDFAndShare() {
        let reportData = buildReportData()
        let weekdayAvg = statsVM.weekdayAverages(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let timeOfDayAvg = statsVM.timeOfDayAverages(entries: entries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let tagFreq = statsVM.tagFrequency(entries: entries)

        let pdfView = PDFReportPreview(
            reportData: reportData,
            weekdayAverages: weekdayAvg,
            timeOfDayAverages: timeOfDayAvg,
            topTags: Array(tagFreq.prefix(5)),
            currentMaxScore: currentMaxScore,
            currentMinScore: currentMinScore,
            themeColors: themeColors
        )

        // Render to PDF using ImageRenderer
        let renderer = ImageRenderer(content: pdfView.frame(width: 595)) // A4 width in points
        renderer.scale = 2.0

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Nami_Report_\(reportData.monthLabel).pdf")

        renderer.render { size, renderContext in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            renderContext(context)
            context.endPDFPage()
            context.closePDF()
        }

        sharePDFURL = tempURL
        showShareSheet = true
    }
}

// MARK: - PDF Report Preview View

/// Multi-section PDF report designed for therapists/doctors
struct PDFReportPreview: View {
    let reportData: MonthlyReportData
    let weekdayAverages: [Int: Double]
    let timeOfDayAverages: [TimeOfDay: Double]
    let topTags: [(tag: String, count: Int)]
    let currentMaxScore: Int
    let currentMinScore: Int
    let themeColors: ThemeColors

    private let weekdayNames = ["", "日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection

            Divider()

            // Overview stats
            overviewSection

            Divider()

            // Weekday breakdown
            weekdaySection

            Divider()

            // Time of day
            timeOfDaySection

            if !topTags.isEmpty {
                Divider()
                tagSection
            }

            // Daily scores bar
            if !reportData.dailyScores.isEmpty {
                Divider()
                dailySection
            }

            Divider()

            // Footer
            footerSection
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Nami")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(themeColors.accent)
                Spacer()
                Text(String(localized: "気分レポート"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(reportData.monthLabel)
                .font(.system(.title3, design: .rounded, weight: .semibold))
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "概要"))
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 24) {
                statBlock(title: String(localized: "平均スコア"), value: String(format: "%.1f", reportData.averageScore))
                statBlock(title: String(localized: "記録回数"), value: "\(reportData.totalEntries)")
                statBlock(title: String(localized: "記録日数"), value: "\(reportData.activeDays)")
                statBlock(title: String(localized: "ストリーク"), value: "\(reportData.streak)" + String(localized: "日"))
            }

            if let trend = reportData.trend {
                HStack(spacing: 4) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(trend >= 0 ? .green : .orange)
                    Text(String(localized: "前月比: \(trend >= 0 ? "+" : "")\(String(format: "%.1f", trend))"))
                        .font(.system(.subheadline, design: .rounded))
                }
            }

            if let best = reportData.bestDay, let worst = reportData.worstDay {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(String(localized: "ベスト: \(best.date, format: .dateTime.month(.defaultDigits).day(.defaultDigits)) (\(best.score))"))
                            .font(.system(.caption, design: .rounded))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text(String(localized: "ワースト: \(worst.date, format: .dateTime.month(.defaultDigits).day(.defaultDigits)) (\(worst.score))"))
                            .font(.system(.caption, design: .rounded))
                    }
                }
            }
        }
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "曜日別平均"))
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 0) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { wd in
                    VStack(spacing: 4) {
                        Text(weekdayNames[wd])
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let avg = weekdayAverages[wd] {
                            let height = max(4, CGFloat(avg - Double(currentMinScore)) / CGFloat(currentMaxScore - currentMinScore) * 40)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(themeColors.accent.opacity(0.7))
                                .frame(height: height)

                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 4)
                            Text("-")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "時間帯別平均"))
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 12) {
                ForEach(TimeOfDay.allCases) { tod in
                    VStack(spacing: 4) {
                        Image(systemName: tod.icon)
                            .font(.caption)
                            .foregroundStyle(themeColors.accent)
                        Text(tod.label)
                            .font(.system(.caption2, design: .rounded))

                        if let avg = timeOfDayAverages[tod] {
                            Text(String(format: "%.1f", avg))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        } else {
                            Text("-")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "よく使ったタグ"))
                .font(.system(.headline, design: .rounded))

            FlowLayout(spacing: 6) {
                ForEach(topTags, id: \.tag) { item in
                    HStack(spacing: 4) {
                        Text(item.tag)
                            .font(.system(.caption, design: .rounded))
                        Text("×\(item.count)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(themeColors.accent.opacity(0.1)))
                    .foregroundStyle(themeColors.accent)
                }
            }
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "日別スコア"))
                .font(.system(.headline, design: .rounded))

            HStack(spacing: 1) {
                ForEach(0 ..< reportData.dailyScores.count, id: \.self) { i in
                    if let score = reportData.dailyScores[i] {
                        let intScore = Int((score * Double(currentMaxScore - currentMinScore) + Double(currentMinScore)).rounded())
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(themeColors.color(for: intScore, minScore: currentMinScore, maxScore: currentMaxScore))
                            .frame(height: 16)
                    } else {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 16)
                    }
                }
            }

            // Day labels
            HStack {
                Text("1")
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(reportData.dailyScores.count)")
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Text(String(localized: "このレポートはNamiアプリで生成されました"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
            Text(Date.now, format: .dateTime.year().month().day())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
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
    let dailyScores: [Double?] // normalizedScore per day-of-month (nil = no entry)
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

            // Week-aligned grid (7 columns: Mon-Sun)
            let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

            VStack(spacing: 3) {
                // Weekday header
                HStack(spacing: 3) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Day cells in week rows
                let weeks = buildWeekRows()
                ForEach(0 ..< weeks.count, id: \.self) { weekIdx in
                    HStack(spacing: 3) {
                        ForEach(0 ..< 7, id: \.self) { dayIdx in
                            let cell = weeks[weekIdx][dayIdx]
                            if let dayNumber = cell.dayNumber {
                                let scoreIndex = dayNumber - 1
                                if scoreIndex < data.dailyScores.count, let score = data.dailyScores[scoreIndex] {
                                    let intScore = Int((score * Double(data.maxScore - data.minScore) + Double(data.minScore)).rounded())
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(themeColors.color(for: intScore, minScore: data.minScore, maxScore: data.maxScore))
                                        .frame(height: 20)
                                        .overlay(
                                            Text("\(dayNumber)")
                                                .font(.system(size: 7, weight: .medium, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.8))
                                        )
                                } else {
                                    // No entry for this day
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(.white.opacity(0.08))
                                        .frame(height: 20)
                                        .overlay(
                                            Text("\(dayNumber)")
                                                .font(.system(size: 7, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.2))
                                        )
                                }
                            } else {
                                // Empty cell (padding)
                                Color.clear.frame(height: 20)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Build week rows for the month grid (Monday-start)
    private func buildWeekRows() -> [[DayCell]] {
        // Parse month/year from monthLabel (format: "2026年3月")
        let calendar = Calendar(identifier: .iso8601)
        let daysInMonth = data.dailyScores.count

        // Determine first day of month's weekday (1=Sun...7=Sat → convert to Mon=0)
        // Use the report data's month - approximate from monthLabel
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy年M月"
        let monthDate = dateFormatter.date(from: data.monthLabel) ?? .now
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? .now

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        // Convert to Monday=0 index
        let leadingBlanks = (firstWeekday + 5) % 7

        var allCells: [DayCell] = Array(repeating: DayCell(dayNumber: nil), count: leadingBlanks)
        for d in 1 ... daysInMonth {
            allCells.append(DayCell(dayNumber: d))
        }
        while allCells.count % 7 != 0 {
            allCells.append(DayCell(dayNumber: nil))
        }

        return stride(from: 0, to: allCells.count, by: 7).map { Array(allCells[$0 ..< $0 + 7]) }
    }

    private struct DayCell {
        let dayNumber: Int?
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
