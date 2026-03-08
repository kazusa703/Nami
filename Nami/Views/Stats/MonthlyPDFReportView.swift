//
//  MonthlyPDFReportView.swift
//  Nami
//
//  PDF export view for monthly summary report (PRO feature)
//

import SwiftUI

/// PDF report layout for monthly summary
/// Rendered via ImageRenderer → CGContext PDF
struct MonthlyPDFReportView: View {
    let summary: MonthlySummary
    let tagHighlights: [StatsViewModel.MonthlyTagHighlight]
    let currentMaxScore: Int
    let currentMinScore: Int
    let colors: ThemeColors

    // Phase 1-2 PRO data (optional — nil means skip section)
    var tagScoreDiffs: (positive: [StatsViewModel.TagScoreDiff], negative: [StatsViewModel.TagScoreDiff])?
    var comparison: StatsViewModel.MonthlyComparison?
    var outliers: [StatsViewModel.MonthlyOutlier]?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (E)"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header

            Divider().padding(.vertical, 16)

            // Overview grid
            overviewGrid

            Divider().padding(.vertical, 16)

            // Best / Worst day
            bestWorstSection

            // Tags
            if !summary.topTags.isEmpty {
                Divider().padding(.vertical, 16)
                tagSection
            }

            // Tag correlation
            if !tagHighlights.isEmpty {
                Divider().padding(.vertical, 16)
                tagCorrelationSection
            }

            // Tag score insights (Phase 1)
            if let diffs = tagScoreDiffs, !diffs.positive.isEmpty || !diffs.negative.isEmpty {
                Divider().padding(.vertical, 16)
                tagScoreInsightsSection(diffs)
            }

            // Month comparison (Phase 2)
            if let comp = comparison, comp.previousAverage != nil {
                Divider().padding(.vertical, 16)
                comparisonSection(comp)
            }

            // Outlier days (Phase 2)
            if let outlierList = outliers, !outlierList.isEmpty {
                Divider().padding(.vertical, 16)
                outlierSection(outlierList)
            }

            Divider().padding(.vertical, 16)

            // Footer
            footer
        }
        .padding(40)
        .background(Color.white)
        .foregroundStyle(.black)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nami 月間レポート")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(dateFormatter.string(from: summary.month))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Overview Grid

    private var overviewGrid: some View {
        HStack(spacing: 0) {
            overviewCell(title: "平均スコア", value: ReportFormat.score(summary.average), sub: previousDiffText)
            overviewCell(title: "記録日数", value: "\(summary.activeDays)日", sub: "\(summary.entryCount)回記録")
            overviewCell(title: "安定度", value: ReportFormat.score(summary.volatility), sub: stabilityLabel)
            overviewCell(title: "好調曜日", value: summary.weekdayBest, sub: nil)
        }
    }

    private var previousDiffText: String? {
        guard let prev = summary.previousMonthAverage else { return nil }
        return ReportFormat.prevMonthDiff(summary.average - prev)
    }

    private var stabilityLabel: String {
        if summary.volatility < 1.5 { return "安定" }
        if summary.volatility < 2.5 { return "やや変動" }
        return "変動大"
    }

    private func overviewCell(title: String, value: String, sub: String?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if let sub {
                Text(sub)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.96))
        )
        .padding(.horizontal, 4)
    }

    // MARK: - Best / Worst

    private var bestWorstSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ハイライト")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            HStack(spacing: 12) {
                if let best = summary.bestDay {
                    dayCard(label: "ベストの日", score: best.score, date: best.date, memo: best.memo, accent: Color.green)
                }
                if let worst = summary.worstDay, worst.date != summary.bestDay?.date {
                    dayCard(label: "ワーストの日", score: worst.score, date: worst.date, memo: worst.memo, accent: Color.orange)
                }
            }
        }
    }

    private func dayCard(label: String, score: Int, date: Date, memo: String?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(accent)
            HStack(spacing: 6) {
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if let memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.96)))
    }

    // MARK: - Tags

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("よく使ったタグ")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            HStack(spacing: 6) {
                ForEach(summary.topTags.prefix(5), id: \.tag) { item in
                    HStack(spacing: 3) {
                        Text(item.tag)
                            .font(.system(size: 11, design: .rounded))
                        Text("\(item.count)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(white: 0.93)))
                }
            }

            // Positive / Negative ratio bar
            HStack(spacing: 8) {
                Text("ポジティブ率")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.green.opacity(0.6))
                            .frame(width: geo.size.width * summary.positiveTagRate)
                        Rectangle()
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: geo.size.width * summary.negativeTagRate)
                        Rectangle()
                            .fill(Color(white: 0.9))
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 8)

                Text("\(Int(summary.positiveTagRate * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    // MARK: - Tag Correlation

    private var tagCorrelationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("タグ相関")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            ForEach(tagHighlights.prefix(5), id: \.tag) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.influence == "ポジティブ" ? "arrow.up.circle.fill" : (item.influence == "ネガティブ" ? "arrow.down.circle.fill" : "minus.circle.fill"))
                        .font(.system(size: 11))
                        .foregroundStyle(item.influence == "ポジティブ" ? .green : (item.influence == "ネガティブ" ? .orange : .gray))

                    Text(item.tag)
                        .font(.system(size: 11, design: .rounded))

                    Spacer()

                    Text(ReportFormat.score(item.averageScore))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))

                    Text("(\(item.count)回)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tag Score Insights (Phase 1)

    private func tagScoreInsightsSection(_ diffs: (positive: [StatsViewModel.TagScoreDiff], negative: [StatsViewModel.TagScoreDiff])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ReportFormat.titleTagTrend)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            if !diffs.positive.isEmpty {
                tagDiffGroup(title: ReportFormat.titleTagUp, items: diffs.positive, color: .green)
            }
            if !diffs.negative.isEmpty {
                tagDiffGroup(title: ReportFormat.titleTagDown, items: diffs.negative, color: .orange)
            }
        }
    }

    private func tagDiffGroup(title: String, items: [StatsViewModel.TagScoreDiff], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(color)

            ForEach(items, id: \.tag) { item in
                HStack(spacing: 8) {
                    Text(item.tag)
                        .font(.system(size: 11, design: .rounded))
                    Spacer()
                    Text(ReportFormat.signedDiff(item.diff))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                    Text(ReportFormat.sampleCount(item.count))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Month Comparison (Phase 2)

    private func comparisonSection(_ comp: StatsViewModel.MonthlyComparison) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ReportFormat.titleComparison)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            VStack(spacing: 6) {
                comparisonRow(label: "平均スコア",
                              current: ReportFormat.score(comp.currentAverage),
                              diff: comp.averageDiff.map { ReportFormat.signedDiff($0) })
                comparisonRow(label: "記録回数",
                              current: "\(comp.currentEntryCount)回",
                              diff: comp.entryCountDiff.map { ReportFormat.signedInt($0) })
                comparisonRow(label: "記録日数",
                              current: "\(comp.currentActiveDays)日",
                              diff: comp.activeDaysDiff.map { ReportFormat.signedInt($0) })
            }
        }
    }

    private func comparisonRow(label: String, current: String, diff: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(current)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Spacer()
            if let d = diff {
                Text(d)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(d.hasPrefix("+") ? .green : (d.hasPrefix("-") ? .orange : .secondary))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.96)))
    }

    // MARK: - Outlier Days (Phase 2)

    private func outlierSection(_ outlierList: [StatsViewModel.MonthlyOutlier]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ReportFormat.titleSpecialDays)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            ForEach(outlierList, id: \.date) { outlier in
                let isHigh = outlier.diffFromMean > 0
                HStack(spacing: 8) {
                    Image(systemName: isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(isHigh ? .green : .orange)

                    Text(dayFormatter.string(from: outlier.date))
                        .font(.system(size: 11, design: .rounded))

                    Text(ReportFormat.score(outlier.dayAverage))
                        .font(.system(size: 12, weight: .bold, design: .rounded))

                    Text(ReportFormat.meanDiff(outlier.diffFromMean))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)

                    if outlier.entryCountThatDay > 1 {
                        Text(ReportFormat.entryCount(outlier.entryCountThatDay))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Tag chips (max 2)
                    ForEach(outlier.topTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(white: 0.93)))
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Nami - Mood Tracker")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Generated \(Date.now.formatted(.dateTime.year().month().day()))")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Report Formatting

/// Shared formatting helpers for monthly report card and PDF
enum ReportFormat {
    /// Score to 1 decimal: "6.3"
    static func score(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Signed diff to 1 decimal: "+0.4" / "-1.2"
    static func signedDiff(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }

    /// "平均比 +2.1" — for outlier diff display
    static func meanDiff(_ value: Double) -> String {
        "平均比 \(signedDiff(value))"
    }

    /// Signed integer diff: "+3" / "-2"
    static func signedInt(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    /// "先月比 +0.4"
    static func prevMonthDiff(_ value: Double) -> String {
        "先月比 \(signedDiff(value))"
    }

    /// Sample count: "n=7"
    static func sampleCount(_ n: Int) -> String {
        "n=\(n)"
    }

    /// Entry count for a day: "3件"
    static func entryCount(_ n: Int) -> String {
        "\(n)件"
    }

    // Section titles (card and PDF use the same strings)
    static let titleMonthSummary = "今月のまとめ"
    static let titleComparison = "先月との比較"
    static let titleTagTrend = "タグとスコアの傾向"
    static let titleTagUp = "上がりやすいタグ"
    static let titleTagDown = "下がりやすいタグ"
    static let titleFrequentTags = "よく記録したタグ"
    static let titleSpecialDays = "特別な日"
    static let titleStability = "気分の安定度"
}
