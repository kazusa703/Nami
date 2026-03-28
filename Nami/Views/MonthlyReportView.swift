//
//  MonthlyReportView.swift
//  Nami
//
//  In-app monthly summary — rich self-reflection view + share to SNS
//

import Charts
import SwiftData
import SwiftUI

/// Monthly summary screen for deep self-reflection
struct MonthlyReportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var allEntries: [MoodEntry]

    /// Optional initial month to display (nil = current month)
    var initialMonth: Date? = nil

    @State private var statsVM = StatsViewModel()
    @State private var displayMonth: Date = .now
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1
    @AppStorage("hasUnreadMonthlyReport") private var hasUnreadMonthlyReport = false

    private let calendar = Calendar.current

    /// Entries for the displayed month
    private var monthEntries: [MoodEntry] {
        guard let interval = calendar.dateInterval(of: .month, for: displayMonth) else { return [] }
        return allEntries.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
    }

    /// Monthly summary data
    private var summary: MonthlySummary? {
        statsVM.monthlySummary(entries: allEntries, currentMax: currentMaxScore, currentMin: currentMinScore, month: displayMonth)
    }

    /// Tag frequency for the month
    private var tagRanking: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in monthEntries {
            for tag in entry.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { (tag: $0.key, count: $0.value) }
    }

    /// Positive / Negative ratio
    private var sentimentRatio: (positive: Double, negative: Double) {
        guard let s = summary else { return (0.5, 0.5) }
        let total = s.positiveTagRate + s.negativeTagRate
        guard total > 0 else { return (0.5, 0.5) }
        return (s.positiveTagRate / total, s.negativeTagRate / total)
    }

    /// Best insight for the month
    private var heroInsight: InsightCard? {
        let insights = InsightEngine.generate(from: monthEntries, currentMax: currentMaxScore, currentMin: currentMinScore)
        return insights.first
    }

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Month navigation
                    monthNavigator(colors: colors)

                    if monthEntries.isEmpty {
                        emptyMonthView(colors: colors)
                    } else {
                        // Average score hero
                        averageScoreSection(colors: colors)

                        // Sentiment ring
                        sentimentRingSection(colors: colors)

                        // Monthly heatmap
                        heatmapSection(colors: colors)

                        // Hero insight
                        if let insight = heroInsight {
                            heroInsightSection(insight: insight, colors: colors)
                        }

                        // Top tags
                        if !tagRanking.isEmpty {
                            topTagsSection(colors: colors)
                        }

                        // Share button
                        shareButton(colors: colors)

                        Spacer(minLength: 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(colors.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle(String(localized: "月間まとめ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
            .onAppear {
                if let initial = initialMonth {
                    displayMonth = initial
                }
                hasUnreadMonthlyReport = false
            }
        }
    }

    // MARK: - Month Navigator

    private func monthNavigator(colors: ThemeColors) -> some View {
        HStack {
            Button {
                withAnimation { displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(colors.accent)
            }

            Spacer()

            let formatter: DateFormatter = {
                let f = DateFormatter()
                f.locale = .current
                f.dateFormat = "yyyy年M月"
                return f
            }()

            Text(formatter.string(from: displayMonth))
                .font(.system(.title3, design: .rounded, weight: .bold))

            Spacer()

            Button {
                withAnimation { displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(colors.accent)
            }
            .disabled(calendar.isDate(displayMonth, equalTo: .now, toGranularity: .month))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Average Score

    private func averageScoreSection(colors: ThemeColors) -> some View {
        let avg = summary?.average ?? 0

        return VStack(spacing: 8) {
            Text(String(localized: "心の波のスコア"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", avg))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.accent)

                Text("/ \(currentMaxScore)")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Trend vs previous month
            if let prev = summary?.previousMonthAverage {
                let delta = avg - prev
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(.caption, weight: .bold))
                    Text(String(format: "%+.1f", delta))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                    Text(String(localized: "先月比"))
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(delta >= 0 ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill((delta >= 0 ? Color.green : .red).opacity(0.12)))
            }

            // Active days
            if let s = summary {
                Text(String(localized: "\(s.activeDays)日記録 / \(s.entryCount)件のエントリ"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Sentiment Ring

    private func sentimentRingSection(colors: ThemeColors) -> some View {
        let pos = sentimentRatio.positive
        let neg = sentimentRatio.negative

        return VStack(spacing: 12) {
            Text(String(localized: "ポジティブ / ネガティブ"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)

                // Positive arc
                Circle()
                    .trim(from: 0, to: pos)
                    .stroke(colors.highScoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Negative arc
                Circle()
                    .trim(from: pos, to: 1.0)
                    .stroke(colors.lowScoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Center label
                VStack(spacing: 2) {
                    Text("\(Int(pos * 100))%")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(String(localized: "ポジティブ"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle().fill(colors.highScoreColor).frame(width: 8, height: 8)
                    Text(String(localized: "ポジティブ \(Int(pos * 100))%"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(colors.lowScoreColor).frame(width: 8, height: 8)
                    Text(String(localized: "ネガティブ \(Int(neg * 100))%"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    // MARK: - Heatmap

    private func heatmapSection(colors: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "日別スコア"))
                .font(.system(.headline, design: .rounded))

            MonthlyHeatmapView(
                entries: allEntries,
                currentMaxScore: currentMaxScore,
                currentMinScore: currentMinScore,
                colors: colors
            )
        }
    }

    // MARK: - Hero Insight

    private func heroInsightSection(insight: InsightCard, colors _: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(insight.tone.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: insight.icon)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(insight.tone.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "今月の気づき"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(insight.title)
                        .font(.system(.headline, design: .rounded))
                }
            }

            Text(insight.body)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(insight.tone.color.opacity(0.25), lineWidth: 1.5))
    }

    // MARK: - Top Tags

    private func topTagsSection(colors: ThemeColors) -> some View {
        let top = Array(tagRanking.prefix(10))
        let maxCount = top.first?.count ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "よく使ったタグ"))
                .font(.system(.headline, design: .rounded))

            VStack(spacing: 6) {
                ForEach(Array(top.enumerated()), id: \.offset) { index, item in
                    let isTop3 = index < 3
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: isTop3 ? 14 : 11, weight: isTop3 ? .bold : .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)

                        Text(item.tag)
                            .font(.system(size: isTop3 ? 14 : 11, weight: isTop3 ? .bold : .medium, design: .rounded))
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            let w = geo.size.width * CGFloat(item.count) / CGFloat(maxCount)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colors.accent.opacity(isTop3 ? 0.8 : 0.4))
                                .frame(width: max(w, 4), height: geo.size.height)
                        }
                        .frame(height: isTop3 ? 16 : 12)

                        Text("\(item.count)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        }
    }

    // MARK: - Share Button

    private func shareButton(colors: ThemeColors) -> some View {
        Button {
            generateShareImage(colors: colors)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text(String(localized: "シェアする"))
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colors.accent)
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Empty Month

    private func emptyMonthView(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 48))
                .foregroundStyle(colors.accent.opacity(0.3))
            Text(String(localized: "この月の記録はありません"))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Share Image Generation

    private func generateShareImage(colors: ThemeColors) {
        let avg = summary?.average ?? 0
        let topTags = Array(tagRanking.prefix(5))
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy年M月"
        let monthLabel = formatter.string(from: displayMonth)

        let imageView = ShareableReportImage(
            monthLabel: monthLabel,
            averageScore: avg,
            maxScore: currentMaxScore,
            minScore: currentMinScore,
            activeDays: summary?.activeDays ?? 0,
            entryCount: monthEntries.count,
            positiveRate: sentimentRatio.positive,
            topTags: topTags,
            insightTitle: heroInsight?.title,
            themeColors: colors
        )

        let renderer = ImageRenderer(content: imageView)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - SNS Shareable Report Image

/// Compact, beautiful summary card for SNS sharing (ImageRenderer)
struct ShareableReportImage: View {
    let monthLabel: String
    let averageScore: Double
    let maxScore: Int
    let minScore: Int
    let activeDays: Int
    let entryCount: Int
    let positiveRate: Double
    let topTags: [(tag: String, count: Int)]
    let insightTitle: String?
    let themeColors: ThemeColors

    private let cardWidth: CGFloat = 390
    private let cardHeight: CGFloat = 520

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "water.waves")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Nami")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(monthLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 32)

            // Average score hero
            VStack(spacing: 4) {
                Text(String(format: "%.1f", averageScore))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("/ \(maxScore)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 20)

            // Stats row
            HStack(spacing: 24) {
                statPill(value: "\(activeDays)", label: String(localized: "日"))
                statPill(value: "\(entryCount)", label: String(localized: "件"))
                statPill(value: "\(Int(positiveRate * 100))%", label: String(localized: "ポジティブ"))
            }
            .padding(.top, 16)

            // Insight (if available)
            if let insight = insightTitle {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text(insight)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.15)))
                .padding(.top, 16)
                .padding(.horizontal, 24)
            }

            // Top tags
            if !topTags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(topTags.prefix(5), id: \.tag) { item in
                        Text(item.tag)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 20)

            // Footer
            VStack(spacing: 4) {
                Text(String(localized: "気分の波を、数字にする"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))

                Text(Date.now, format: .dateTime.year().month().day())
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.bottom, 28)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [themeColors.accent, themeColors.accent.opacity(0.6)],
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

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.1)))
    }
}

#Preview {
    MonthlyReportView()
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
