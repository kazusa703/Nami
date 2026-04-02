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
    @Environment(\.premiumManager) private var premiumManager
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

    /// Daily average scores for wave shape (0 = no record)
    private var dailyAverageScores: [Double] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: displayMonth)
        else { return [] }

        return (0 ..< monthRange.count).map { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) else { return 0 }
            let dayEntries = monthEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { return 0 }
            return dayEntries.map { $0.scaledScore(to: currentMaxScore, targetMin: currentMinScore) }.reduce(0, +) / Double(dayEntries.count)
        }
    }

    /// Days in the displayed month
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30
    }

    /// Month name for narrative
    private var monthName: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "M月"
        return f.string(from: displayMonth)
    }

    /// Top rescue action for narrative highlight
    private var topRescueAction: (name: String, multiplier: Double)? {
        let boosters = statsVM.recoveryBoosters(entries: monthEntries)
        guard let top = boosters.first else { return nil }
        return (name: TagDisplayHelper.displayName(for: top.tagName), multiplier: top.lift)
    }

    /// Challenge day (worst day of the month)
    private var challengeDay: (date: Date, score: Double, memo: String?, tags: [String], weather: String?, temperature: Double?, nextDayScore: Double?)? {
        guard let s = summary, let worst = s.worstDay, let best = s.bestDay else { return nil }
        // Skip if same as best day
        guard !calendar.isDate(worst.date, inSameDayAs: best.date) else { return nil }

        let worstEntries = monthEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: worst.date) }
        let tags = Array(Set(worstEntries.flatMap(\.tags))).prefix(3).map { String($0) }
        let weather = worstEntries.compactMap(\.weatherCondition).first
        let temp = worstEntries.compactMap(\.weatherTemperature).first

        // Next day recovery score
        let nextDay = calendar.date(byAdding: .day, value: 1, to: worst.date)
        let nextDayScore: Double? = nextDay.flatMap { nd in
            let nextEntries = monthEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: nd) }
            guard !nextEntries.isEmpty else { return nil }
            return nextEntries.map { $0.scaledScore(to: currentMaxScore, targetMin: currentMinScore) }.reduce(0, +) / Double(nextEntries.count)
        }

        let scaledScore = worstEntries.map { $0.scaledScore(to: currentMaxScore, targetMin: currentMinScore) }.reduce(0, +) / max(Double(worstEntries.count), 1)

        return (date: worst.date, score: scaledScore, memo: worst.memo, tags: tags, weather: weather, temperature: temp, nextDayScore: nextDayScore)
    }

    /// Best day recipe (conditions that led to the best day)
    private var bestDayRecipe: String? {
        guard let best = summary?.bestDay else { return nil }
        let bestEntries = monthEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: best.date) }
        var conditions: [String] = []

        // Weather
        if let weather = bestEntries.compactMap(\.weatherCondition).first {
            let name: String = switch weather {
            case "sunny", "clear": String(localized: "晴天")
            case "cloudy": String(localized: "曇り")
            case "rainy": String(localized: "雨")
            case "snowy": String(localized: "雪")
            default: weather
            }
            conditions.append(name)
        }

        // Exercise tags
        let exerciseTags = Set(["tag_running", "tag_yoga", "tag_gym", "tag_walk", "ランニング", "ヨガ/ストレッチ", "筋トレ", "散歩", "運動"])
        let allTags = Set(bestEntries.flatMap(\.tags))
        if !allTags.isDisjoint(with: exerciseTags) {
            conditions.append(String(localized: "運動"))
        }

        // Social tags
        let socialTags = Set(["tag_friends", "tag_family", "tag_lover", "tag_colleagues", "友人", "家族", "パートナー", "同僚"])
        if !allTags.isDisjoint(with: socialTags) {
            conditions.append(String(localized: "人とのつながり"))
        }

        guard !conditions.isEmpty else { return nil }
        return conditions.joined(separator: " ・ ")
    }

    /// Resolve tag IDs in text to display names
    private func resolveTagIDs(_ text: String) -> String {
        var resolved = text
        let tagPattern = /tag_[a-z_]+/
        for match in text.matches(of: tagPattern) {
            let tagID = String(match.output)
            let displayName = TagDisplayHelper.displayName(for: tagID)
            if displayName != tagID {
                resolved = resolved.replacingOccurrences(of: tagID, with: displayName)
            }
        }
        return resolved
    }

    // Animation states
    @State private var displayedScore: Double = 0
    @State private var waveOpacity: Double = 0

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
                        // Wave header + score
                        scoreHeaderWithWave(colors: colors)

                        // Narrative
                        narrativeSection(colors: colors)

                        // Best day (with recipe) — free
                        bestDayCard(colors: colors)

                        // Challenge day — Pro only
                        if premiumManager.isPremium {
                            challengeDayCard(colors: colors)
                        }

                        // Sentiment ring — free
                        sentimentRingSection(colors: colors)

                        // Monthly heatmap — free
                        heatmapSection(colors: colors)

                        // Insights — 1 free, 3 Pro
                        insightCardsSection(colors: colors)

                        // Recovery booster — TOP1 free, rest Pro (handled inside)
                        recoveryBoosterSection(colors: colors)

                        // Monthly proposal — Pro only
                        if premiumManager.isPremium {
                            monthlyProposalSection(colors: colors)
                        } else {
                            proGateCard(
                                title: String(localized: "来月のチャレンジ"),
                                description: String(localized: "あなたのデータに基づいた行動提案"),
                                colors: colors
                            )
                        }

                        // Top tags with impact — free (impact hidden for non-Pro handled inside)
                        if !tagRanking.isEmpty {
                            topTagsWithImpactSection(colors: colors)
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
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
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

    // MARK: - Wave Header + Score

    private func scoreHeaderWithWave(colors: ThemeColors) -> some View {
        let avg = summary?.average ?? 0

        return VStack(spacing: 8) {
            // Wave background
            ZStack {
                ScoreWaveShape(dailyScores: dailyAverageScores)
                    .fill(
                        LinearGradient(
                            colors: [colors.accent.opacity(0.2), colors.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)

                ScoreWaveShape(dailyScores: dailyAverageScores)
                    .stroke(colors.accent.opacity(0.4), lineWidth: 1.5)
                    .frame(height: 80)
            }
            .drawingGroup()
            .opacity(waveOpacity)
            .padding(.horizontal, -20)

            Text(String(localized: "心の波のスコア"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", displayedScore))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.accent)
                    .contentTransition(.numericText(value: displayedScore))

                Text("/\(currentMaxScore)")
                    .font(.system(size: 22, weight: .light, design: .rounded))
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                displayedScore = avg
            }
            withAnimation(.easeIn(duration: 0.6)) {
                waveOpacity = 1.0
            }
        }
        .onChange(of: displayMonth) { _, _ in
            displayedScore = 0
            waveOpacity = 0
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                displayedScore = summary?.average ?? 0
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.1)) {
                waveOpacity = 1.0
            }
        }
    }

    // MARK: - Narrative

    private func narrativeSection(colors: ThemeColors) -> some View {
        let narrative = NarrativeGenerator.generate(
            activeDays: summary?.activeDays ?? 0,
            daysInMonth: daysInMonth,
            monthName: monthName,
            average: summary?.average ?? 0,
            previousAverage: summary?.previousMonthAverage,
            topRescueAction: topRescueAction
        )

        return Text(NarrativeGenerator.attributedText(from: narrative, accentColor: colors.accent))
            .font(.system(.body, design: .serif))
            .lineSpacing(6)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
    }

    // MARK: - Challenge Day Card

    @ViewBuilder
    private func challengeDayCard(colors _: ThemeColors) -> some View {
        if let challenge = challengeDay {
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "チャレンジデイ"), systemImage: "cloud.rain.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack {
                    Text(challenge.date.formatted(.dateTime.month().day().weekday(.wide)))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(String(format: "%.0f", challenge.score))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("/\(currentMaxScore)")
                            .font(.system(size: 14, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if let memo = challenge.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Weather + tags
                HStack(spacing: 6) {
                    if let weather = challenge.weather {
                        let icon = switch weather {
                        case "sunny", "clear": "sun.max.fill"
                        case "cloudy": "cloud.fill"
                        case "rainy": "cloud.rain.fill"
                        case "snowy": "cloud.snow.fill"
                        case "stormy": "cloud.bolt.fill"
                        default: "cloud.fill"
                        }
                        Label(
                            challenge.temperature.map { "\(Int($0))°C" } ?? "",
                            systemImage: icon
                        )
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                    }
                    ForEach(challenge.tags, id: \.self) { tag in
                        Text(TagDisplayHelper.displayName(for: tag))
                            .font(.system(.caption2, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.08)))
                    }
                }

                // Next day recovery
                if let nextScore = challenge.nextDayScore, nextScore > challenge.score {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(String(localized: "翌日は \(String(format: "%.1f", nextScore)) に回復"))
                            .font(.system(.callout, design: .rounded))
                        Image(systemName: "sparkles")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.08 : 0.04))
            )
        }
    }

    // MARK: - Average Score (legacy, kept for reference)

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

    private func sentimentRingSection(colors _: ThemeColors) -> some View {
        let categoryData = buildCategoryData()
        let totalEntries = monthEntries.count
        let pos = sentimentRatio.positive

        return VStack(spacing: 16) {
            Text(String(localized: "感情のスペクトラム"))
                .font(.system(.subheadline, design: .rounded, weight: .bold))

            if pos == 1.0 {
                // All positive achievement
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                    Text(String(localized: "オールポジティブ!"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(String(localized: "今月はネガティブタグが0でした"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else if !categoryData.isEmpty {
                // Donut chart
                ZStack {
                    Chart(categoryData, id: \.name) { cat in
                        SectorMark(
                            angle: .value("Count", cat.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(cat.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)

                    // Center label
                    VStack(spacing: 2) {
                        Text("\(totalEntries)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(String(localized: "エントリ"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                // Legend (top categories)
                FlowLayout(spacing: 8) {
                    ForEach(categoryData.prefix(6), id: \.name) { cat in
                        HStack(spacing: 4) {
                            Circle().fill(cat.color).frame(width: 6, height: 6)
                            Text("\(cat.emoji) \(cat.percentage)%")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    /// Build category distribution data for donut chart
    private func buildCategoryData() -> [(name: String, emoji: String, count: Int, percentage: Int, color: Color)] {
        let catMap: [String: (name: String, emoji: String, color: Color)] = [
            "positive": (String(localized: "ポジティブ"), "😊", .green),
            "negative": (String(localized: "ネガティブ"), "😢", .red),
            "factor": (String(localized: "要因"), "💪", .blue),
            "diet": (String(localized: "食事"), "🍽", .orange),
            "exercise": (String(localized: "運動"), "🏃", .cyan),
            "location": (String(localized: "場所"), "📍", .purple),
            "activity": (String(localized: "活動"), "🎯", .indigo),
            "social": (String(localized: "人"), "👥", .pink),
            "communication": (String(localized: "会話"), "💬", .teal),
            "mind": (String(localized: "頭"), "🧠", .brown),
            "morning": (String(localized: "朝"), "🌅", .yellow),
            "custom": (String(localized: "カスタム"), "✨", .gray),
        ]

        // Count tags by category
        var categoryCounts: [String: Int] = [:]
        for entry in monthEntries {
            for tag in entry.tags {
                // Determine category from EmotionTagCategory
                let catKey: String
                if tag.hasPrefix("tag_happy") || tag.hasPrefix("tag_fun") || tag.hasPrefix("tag_calm") || tag.hasPrefix("tag_grateful") || tag.hasPrefix("tag_energetic") || tag.hasPrefix("tag_refreshed") {
                    catKey = "positive"
                } else if tag.hasPrefix("tag_sad") || tag.hasPrefix("tag_anxious") || tag.hasPrefix("tag_stressed") || tag.hasPrefix("tag_tired") || tag.hasPrefix("tag_irritated") {
                    catKey = "negative"
                } else if tag.hasPrefix("tag_running") || tag.hasPrefix("tag_yoga") || tag.hasPrefix("tag_gym") || tag.hasPrefix("tag_walk") {
                    catKey = "exercise"
                } else if tag.hasPrefix("tag_friends") || tag.hasPrefix("tag_family") || tag.hasPrefix("tag_lover") || tag.hasPrefix("tag_colleagues") {
                    catKey = "social"
                } else if tag.hasPrefix("tag_caffeine") || tag.hasPrefix("tag_cooking") || tag.hasPrefix("tag_alcohol") {
                    catKey = "diet"
                } else if tag.hasPrefix("tag_home") || tag.hasPrefix("tag_work") || tag.hasPrefix("tag_outside") {
                    catKey = "location"
                } else if tag.hasPrefix("tag_meditation") || tag.hasPrefix("tag_reading") || tag.hasPrefix("tag_clear_mind") || tag.hasPrefix("tag_focused") {
                    catKey = "mind"
                } else if tag.hasPrefix("tag_fresh_wakeup") || tag.hasPrefix("tag_heavy_wakeup") {
                    catKey = "morning"
                } else {
                    catKey = "custom"
                }
                categoryCounts[catKey, default: 0] += 1
            }
        }

        let totalTags = categoryCounts.values.reduce(0, +)
        guard totalTags > 0 else { return [] }

        return categoryCounts
            .sorted { $0.value > $1.value }
            .compactMap { key, count in
                guard let info = catMap[key] else { return nil }
                let pct = Int(Double(count) / Double(totalTags) * 100)
                return (name: info.name, emoji: info.emoji, count: count, percentage: pct, color: info.color)
            }
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

            Text(resolveTagIDs(insight.body))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(insight.tone.color.opacity(0.25), lineWidth: 1.5))
    }

    // MARK: - Insight Cards (3 swipeable)

    private func insightCardsSection(colors: ThemeColors) -> some View {
        let insights = InsightEngine.generate(from: monthEntries, currentMax: currentMaxScore, currentMin: currentMinScore)
        let maxCards = premiumManager.isPremium ? 3 : 1
        let displayInsights = Array(insights.prefix(maxCards))

        return VStack(spacing: 8) {
            if !displayInsights.isEmpty {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(String(localized: "今月の気づき"))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    // Page dots
                    HStack(spacing: 4) {
                        ForEach(0 ..< displayInsights.count, id: \.self) { i in
                            Circle()
                                .fill(i == 0 ? colors.accent : colors.accent.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                TabView {
                    ForEach(displayInsights) { insight in
                        insightCardContent(insight: insight, colors: colors)
                            .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 140)
            }
        }
    }

    private func insightCardContent(insight: InsightCard, colors _: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: insight.icon)
                    .font(.system(.body))
                    .foregroundStyle(insight.tone.color)
                Text(resolveTagIDs(insight.title))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }

            Text(resolveTagIDs(insight.body))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(insight.tone.color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(insight.tone.color.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Monthly Proposal

    @ViewBuilder
    private func monthlyProposalSection(colors: ThemeColors) -> some View {
        let impacts = statsVM.habitImpactScores(entries: monthEntries, targetMax: currentMaxScore, targetMin: currentMinScore)
        let proposal = generateProposal(impacts: impacts)

        if let proposal {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .foregroundStyle(.white)
                    Text(String(localized: "来月のチャレンジ"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(proposal.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(proposal.reason)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text(proposal.expectedImpact)
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [colors.accent, colors.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }

    private struct MonthlyProposal {
        let title: String
        let reason: String
        let expectedImpact: String
    }

    private func generateProposal(impacts: [StatsViewModel.HabitImpact]) -> MonthlyProposal? {
        guard !impacts.isEmpty else { return nil }

        // Priority 1: High impact + low frequency tag
        let avgCount = tagRanking.map(\.count).reduce(0, +) / max(tagRanking.count, 1)
        if let candidate = impacts
            .filter({ $0.impact > 0.5 && $0.sampleCount < avgCount })
            .first
        {
            let name = TagDisplayHelper.displayName(for: candidate.tagName)
            return MonthlyProposal(
                title: "「\(name)」を増やしてみよう",
                reason: "\(name)のある日はスコアが\(String(format: "+%.1f", candidate.impact))高いのに、月\(candidate.sampleCount)回しか記録していません",
                expectedImpact: String(localized: "月間平均が+0.3〜0.5改善する可能性")
            )
        }

        // Priority 2: Most impactful tag
        if let top = impacts.first, top.impact > 0.3 {
            let name = TagDisplayHelper.displayName(for: top.tagName)
            return MonthlyProposal(
                title: "「\(name)」を意識してみよう",
                reason: "\(name)はあなたの気分に最もプラスの影響を与えています（\(String(format: "+%.1f", top.impact))）",
                expectedImpact: String(localized: "この習慣を維持するだけでスコアの安定に繋がります")
            )
        }

        return nil
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

                        Text(TagDisplayHelper.displayName(for: item.tag))
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

    // MARK: - Best Day Card

    @ViewBuilder
    private func bestDayCard(colors: ThemeColors) -> some View {
        if let best = summary?.bestDay {
            let scaled = Double(best.score)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(localized: "今月のベストデイ"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }

                HStack(spacing: 16) {
                    Text(String(format: "%.0f", scaled))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(colors.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(best.date.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))

                        if let memo = best.memo, !memo.isEmpty {
                            Text(memo)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        // Tags for best day
                        let bestDayEntries = monthEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: best.date) }
                        let bestDayTags = Array(Set(bestDayEntries.flatMap(\.tags))).prefix(3)
                        if !bestDayTags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(Array(bestDayTags), id: \.self) { tag in
                                    Text(TagDisplayHelper.displayName(for: tag))
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(colors.accent.opacity(0.1)))
                                        .foregroundStyle(colors.accent)
                                }
                            }
                        }

                        // Weather if available
                        if let weather = bestDayEntries.compactMap(\.weatherCondition).first {
                            let weatherIcon = switch weather {
                            case "sunny", "clear": "sun.max.fill"
                            case "cloudy": "cloud.fill"
                            case "rainy": "cloud.rain.fill"
                            case "snowy": "cloud.snow.fill"
                            default: "cloud.fill"
                            }
                            HStack(spacing: 4) {
                                Image(systemName: weatherIcon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                if let temp = bestDayEntries.compactMap(\.weatherTemperature).first {
                                    Text(String(format: "%.0f°C", temp))
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Recipe for best day
                if let recipe = bestDayRecipe {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "再現レシピ"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Text(recipe)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.yellow.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Recovery Booster Section

    @ViewBuilder
    private func recoveryBoosterSection(colors _: ThemeColors) -> some View {
        let boosters = statsVM.recoveryBoosters(entries: monthEntries)
        if !boosters.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.heart.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "今月あなたを救ったアクション"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }

                ForEach(boosters.prefix(3)) { booster in
                    let displayName = TagDisplayHelper.displayName(for: booster.tagName)
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text(displayName)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                        Spacer()
                        Text(String(format: "×%.1f", booster.lift))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.green.opacity(0.06)))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        }
    }

    // MARK: - Top Tags with Impact

    @State private var tagSortByImpact = true

    private func topTagsWithImpactSection(colors: ThemeColors) -> some View {
        let impacts = statsVM.habitImpactScores(entries: monthEntries, targetMax: currentMaxScore, targetMin: currentMinScore)
        let impactMap = Dictionary(uniqueKeysWithValues: impacts.map { ($0.tagName, $0.impact) })
        let maxImpact = impacts.map { abs($0.impact) }.max() ?? 1.0

        // Sort tags by impact or frequency
        let sortedTags: [(tag: String, count: Int, impact: Double)] = {
            let tagged = tagRanking.map { item in
                (tag: item.tag, count: item.count, impact: impactMap[item.tag] ?? 0)
            }
            if tagSortByImpact {
                return tagged.sorted { $0.impact > $1.impact }
            }
            return tagged
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(colors.accent)
                    Text(String(localized: "よく使ったタグ"))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }

                Spacer()

                // Sort toggle
                if !impacts.isEmpty {
                    HStack(spacing: 2) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { tagSortByImpact = true }
                        } label: {
                            Text(String(localized: "インパクト順"))
                                .font(.system(.caption2, design: .rounded, weight: tagSortByImpact ? .bold : .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(tagSortByImpact ? colors.accent : .clear)
                                )
                                .foregroundStyle(tagSortByImpact ? .white : .secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { tagSortByImpact = false }
                        } label: {
                            Text(String(localized: "頻度順"))
                                .font(.system(.caption2, design: .rounded, weight: !tagSortByImpact ? .bold : .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(!tagSortByImpact ? colors.accent : .clear)
                                )
                                .foregroundStyle(!tagSortByImpact ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5).opacity(0.6)))
                }
            }

            // Center-axis impact bars
            ForEach(sortedTags.prefix(10), id: \.tag) { item in
                let displayName = TagDisplayHelper.displayName(for: item.tag)

                HStack(spacing: 4) {
                    // Tag name
                    Text(displayName)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .frame(width: 76, alignment: .trailing)
                        .lineLimit(1)

                    // Center-axis bar
                    GeometryReader { geo in
                        let center = geo.size.width / 2
                        let barWidth = maxImpact > 0 ? abs(item.impact) / maxImpact * center * 0.85 : 0

                        ZStack {
                            // Center line
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 1)
                                .position(x: center, y: geo.size.height / 2)

                            // Impact bar
                            if barWidth > 2 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(item.impact >= 0 ? Color.green.opacity(0.6) : Color.red.opacity(0.5))
                                    .frame(width: barWidth, height: 16)
                                    .position(
                                        x: item.impact >= 0 ? center + barWidth / 2 + 1 : center - barWidth / 2 - 1,
                                        y: geo.size.height / 2
                                    )
                            }
                        }
                    }
                    .frame(height: 22)

                    // Count
                    Text("\(item.count)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }

            // Axis labels
            HStack {
                Spacer()
                Text(String(localized: "◀ マイナス"))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(String(localized: "プラス ▶"))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    @State private var showProView = false

    private func shareButton(colors: ThemeColors) -> some View {
        VStack(spacing: 12) {
            // Closing message
            VStack(spacing: 6) {
                Text(String(localized: "すべての波は、あなたの大切な記録です。"))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Small wave decoration
                Image(systemName: "water.waves")
                    .font(.system(size: 16))
                    .foregroundStyle(colors.accent.opacity(0.3))
            }
            .padding(.top, 8)

            // Share menu
            Menu {
                Button {
                    generateShareImage(colors: colors, template: .compact)
                } label: {
                    Label(String(localized: "コンパクト（3:4）"), systemImage: "rectangle.portrait")
                }
                Button {
                    generateShareImage(colors: colors, template: .stories)
                } label: {
                    Label(String(localized: "ストーリーズ（9:16）"), systemImage: "rectangle")
                }
                if premiumManager.isPremium {
                    Button {
                        generateShareImage(colors: colors, template: .square)
                    } label: {
                        Label(String(localized: "スクエア（1:1）"), systemImage: "square")
                    }
                    Button {
                        generateShareImage(colors: colors, template: .wide)
                    } label: {
                        Label(String(localized: "ワイド（16:9）"), systemImage: "rectangle.landscape")
                    }
                } else {
                    Button {
                        showProView = true
                    } label: {
                        Label(String(localized: "スクエア・ワイド（Pro）"), systemImage: "lock.fill")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "シェアする"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(colors.accent))
            }
        }
        .padding(.top, 8)
        .sheet(isPresented: $showProView) {
            NavigationStack { ProView() }
        }
    }

    private enum ShareTemplate {
        case compact, stories, square, wide
    }

    // MARK: - Pro Gate Card

    private func proGateCard(title: String, description: String, colors _: ThemeColors) -> some View {
        Button {
            showProView = true
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.orange)

                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(String(localized: "Proで解放"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.orange))
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.orange.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.orange.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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

    private func generateShareImage(colors: ThemeColors, template: ShareTemplate) {
        let avg = summary?.average ?? 0
        let topTags = Array(tagRanking.prefix(5))
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "yyyy年M月"
        let monthLabel = formatter.string(from: displayMonth)
        let dailyScores = buildDailyScoreArray()
        let impacts = statsVM.habitImpactScores(entries: monthEntries, targetMax: currentMaxScore, targetMin: currentMinScore)
        let topImpactTags = impacts.prefix(5).map { (tag: TagDisplayHelper.displayName(for: $0.tagName), impact: $0.impact) }

        let imageView: AnyView
        switch template {
        case .compact:
            imageView = AnyView(ShareableReportImage(
                monthLabel: monthLabel, averageScore: avg, maxScore: currentMaxScore,
                minScore: currentMinScore, activeDays: summary?.activeDays ?? 0,
                entryCount: monthEntries.count, positiveRate: sentimentRatio.positive,
                topTags: topTags, insightTitle: heroInsight?.title,
                themeColors: colors, storyFormat: false, dailyScores: []
            ))
        case .stories:
            imageView = AnyView(ShareableReportImage(
                monthLabel: monthLabel, averageScore: avg, maxScore: currentMaxScore,
                minScore: currentMinScore, activeDays: summary?.activeDays ?? 0,
                entryCount: monthEntries.count, positiveRate: sentimentRatio.positive,
                topTags: topTags, insightTitle: heroInsight?.title,
                themeColors: colors, storyFormat: true, dailyScores: dailyScores
            ))
        case .square:
            imageView = AnyView(SquareShareTemplate(
                monthLabel: monthLabel, averageScore: avg, maxScore: currentMaxScore,
                delta: (summary?.average ?? 0) - (summary?.previousMonthAverage ?? 0),
                narrative: NarrativeGenerator.generate(
                    activeDays: summary?.activeDays ?? 0, daysInMonth: daysInMonth,
                    monthName: monthName, average: avg,
                    previousAverage: summary?.previousMonthAverage, topRescueAction: topRescueAction
                ).plainText,
                themeColors: colors
            ))
        case .wide:
            imageView = AnyView(WideShareTemplate(
                monthLabel: monthLabel, averageScore: avg, maxScore: currentMaxScore,
                delta: (summary?.average ?? 0) - (summary?.previousMonthAverage ?? 0),
                activeDays: summary?.activeDays ?? 0, entryCount: monthEntries.count,
                topImpactTags: topImpactTags, themeColors: colors
            ))
        }

        let renderer = ImageRenderer(content: imageView)
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }

    /// Build daily average score array for the month (for wave background)
    private func buildDailyScoreArray() -> [Double] {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)),
              let monthRange = calendar.range(of: .day, in: .month, for: displayMonth)
        else { return [] }

        var scores: [Double] = []
        for dayOffset in 0 ..< monthRange.count {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monthStart) else { continue }
            let dayEntries = monthEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            if dayEntries.isEmpty {
                scores.append(0)
            } else {
                let avg = dayEntries.map { $0.scaledScore(to: currentMaxScore, targetMin: currentMinScore) }.reduce(0, +) / Double(dayEntries.count)
                scores.append(avg)
            }
        }
        return scores
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
    var storyFormat: Bool = false
    var dailyScores: [Double] = []

    private var cardWidth: CGFloat {
        storyFormat ? 360 : 390
    }

    private var cardHeight: CGFloat {
        storyFormat ? 640 : 520
    }

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
                        Text(TagDisplayHelper.displayName(for: item.tag))
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
        .overlay {
            if storyFormat && !dailyScores.isEmpty {
                // Wave line background for story format
                WaveLineOverlay(scores: dailyScores, maxScore: Double(maxScore), minScore: Double(minScore))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
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

// MARK: - Wave Line Overlay (Story Format Background)

private struct WaveLineOverlay: View {
    let scores: [Double]
    let maxScore: Double
    let minScore: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let nonZeroScores = scores.filter { $0 > 0 }
            if !nonZeroScores.isEmpty {
                // Draw wave in bottom third of the image
                let baseY = height * 0.65
                let amplitude = height * 0.08
                let scoreRange = max(maxScore - minScore, 1)

                Path { path in
                    var started = false
                    for (i, score) in scores.enumerated() {
                        guard score > 0 else { continue }
                        let x = width * CGFloat(i) / CGFloat(max(scores.count - 1, 1))
                        let normalized = (score - minScore) / scoreRange
                        let y = baseY - amplitude * normalized * 2

                        if !started {
                            path.move(to: CGPoint(x: x, y: y))
                            started = true
                        } else {
                            // Smooth curve
                            let prevI = max(0, i - 1)
                            let prevX = width * CGFloat(prevI) / CGFloat(max(scores.count - 1, 1))
                            let cpX = (prevX + x) / 2
                            path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cpX, y: y))
                        }
                    }
                }
                .stroke(.white.opacity(0.15), lineWidth: 3)

                // Second wave offset
                Path { path in
                    var started = false
                    for (i, score) in scores.enumerated() {
                        guard score > 0 else { continue }
                        let x = width * CGFloat(i) / CGFloat(max(scores.count - 1, 1))
                        let normalized = (score - minScore) / scoreRange
                        let y = baseY + amplitude * 0.5 - amplitude * normalized * 1.5

                        if !started {
                            path.move(to: CGPoint(x: x, y: y))
                            started = true
                        } else {
                            let prevI = max(0, i - 1)
                            let prevX = width * CGFloat(prevI) / CGFloat(max(scores.count - 1, 1))
                            let cpX = (prevX + x) / 2
                            path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cpX, y: y))
                        }
                    }
                }
                .stroke(.white.opacity(0.08), lineWidth: 2)
            } // end if nonZeroScores
        }
    }
}

// MARK: - Square Share Template (1080×1080)

struct SquareShareTemplate: View {
    let monthLabel: String
    let averageScore: Double
    let maxScore: Int
    let delta: Double
    let narrative: String
    let themeColors: ThemeColors

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Score
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", averageScore))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/\(maxScore)")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Delta
            HStack(spacing: 4) {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                Text(String(format: "%+.1f", delta))
                    .font(.system(.callout, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 4)

            // Narrative
            Text(narrative)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 32)
                .padding(.top, 16)

            Spacer()

            // Footer
            HStack(spacing: 6) {
                Image(systemName: "water.waves")
                    .font(.system(size: 14))
                Text("Nami")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("— \(monthLabel)")
                    .font(.system(size: 12, design: .rounded))
                    .opacity(0.6)
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 24)
        }
        .frame(width: 360, height: 360)
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
    }
}

// MARK: - Wide Share Template (1200×675 → 400×225 @3x)

struct WideShareTemplate: View {
    let monthLabel: String
    let averageScore: Double
    let maxScore: Int
    let delta: Double
    let activeDays: Int
    let entryCount: Int
    let topImpactTags: [(tag: String, impact: Double)]
    let themeColors: ThemeColors

    var body: some View {
        HStack(spacing: 0) {
            // Left: Score + stats
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 12))
                    Text("Nami")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.6))

                Text(monthLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", averageScore))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("/\(maxScore)")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Text("\(activeDays)日")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                    Text("\(entryCount)件")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                    HStack(spacing: 2) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%+.1f", delta))
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                    }
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Tag impact bars
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "習慣インパクト"))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                let maxImpact = topImpactTags.map { abs($0.impact) }.max() ?? 1
                ForEach(topImpactTags.prefix(5), id: \.tag) { item in
                    HStack(spacing: 6) {
                        Text(item.tag)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 60, alignment: .trailing)
                            .lineLimit(1)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.15))
                                .frame(width: 80, height: 8)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.impact >= 0 ? .green.opacity(0.8) : .red.opacity(0.7))
                                .frame(width: 80 * abs(item.impact) / maxImpact, height: 8)
                        }

                        Text(String(format: "%+.1f", item.impact))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(item.impact >= 0 ? .green : .red)
                            .frame(width: 28, alignment: .trailing)
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 400, height: 225)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [themeColors.accent.opacity(0.9), themeColors.accent.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

#Preview {
    MonthlyReportView()
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
