//
//  ReportArchiveView.swift
//  Nami
//
//  Archive of past monthly reports — list of months with summary cards
//

import SwiftData
import SwiftUI

/// Past monthly reports archive
struct ReportArchiveView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var allEntries: [MoodEntry]

    @AppStorage(AppConstants.scoreRangeMaxKey) private var currentMaxScore: Int = 10
    @AppStorage(AppConstants.scoreRangeMinKey) private var currentMinScore: Int = 1

    @State private var selectedMonth: Date?

    private let calendar = Calendar.current

    /// Months that have at least 1 entry (newest first)
    private var availableMonths: [Date] {
        var monthSet: [String: Date] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for entry in allEntries {
            let key = formatter.string(from: entry.createdAt)
            if monthSet[key] == nil {
                let monthStart = calendar.dateInterval(of: .month, for: entry.createdAt)?.start ?? entry.createdAt
                monthSet[key] = monthStart
            }
        }

        return monthSet.values.sorted(by: >)
    }

    var body: some View {
        let colors = themeManager.colors

        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(availableMonths, id: \.self) { month in
                    monthCard(month: month, colors: colors)
                }

                if availableMonths.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 40)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(colors.accent.opacity(0.3))
                        Text(String(localized: "まだレポートがありません"))
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "記録を続けると、毎月のまとめが生成されます"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(colors.backgroundGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle(String(localized: "過去のレポート"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMonth) { month in
            MonthlyReportView(initialMonth: month)
        }
    }

    // MARK: - Month Card

    private func monthCard(month: Date, colors: ThemeColors) -> some View {
        let monthEntries = entriesForMonth(month)
        let avg = monthlyAverage(entries: monthEntries)
        let activeDays = uniqueDays(entries: monthEntries)

        return Button {
            selectedMonth = month
        } label: {
            HStack(spacing: 16) {
                // Month icon with score color
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colors.color(for: Int(avg), minScore: currentMinScore, maxScore: currentMaxScore).opacity(0.15))
                        .frame(width: 52, height: 52)

                    VStack(spacing: 1) {
                        Text(monthAbbreviation(month))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(colors.accent)
                        Text(yearString(month))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(monthFullLabel(month))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(colors.accent)
                            Text(String(format: "%.1f", avg))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "\(activeDays)日間"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "note.text")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "\(monthEntries.count)件"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func entriesForMonth(_ month: Date) -> [MoodEntry] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return allEntries.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
    }

    private func monthlyAverage(entries: [MoodEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let total = entries.map { $0.scaledScore(to: currentMaxScore, targetMin: currentMinScore) }.reduce(0, +)
        return total / Double(entries.count)
    }

    private func uniqueDays(entries: [MoodEntry]) -> Int {
        Set(entries.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    private func monthAbbreviation(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "M月"
        return f.string(from: date)
    }

    private func yearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }

    private func monthFullLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }
}

// MARK: - Date Identifiable conformance for sheet(item:)

extension Date: @retroactive Identifiable {
    public var id: TimeInterval {
        timeIntervalSince1970
    }
}

#Preview {
    NavigationStack {
        ReportArchiveView()
    }
    .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
    .environment(\.themeManager, ThemeManager())
}
