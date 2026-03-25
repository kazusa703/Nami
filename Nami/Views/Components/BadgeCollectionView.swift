//
//  BadgeCollectionView.swift
//  Nami
//
//  Badge collection screen - gamification achievements
//

import SwiftData
import SwiftUI

/// Achievement badge definition
struct AchievementBadge: Identifiable {
    let id: String
    let icon: String
    let name: String
    let description: String
    let condition: ([MoodEntry]) -> Bool

    func isAchieved(entries: [MoodEntry]) -> Bool {
        condition(entries)
    }
}

/// Badge collection view showing all achievements
struct BadgeCollectionView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    private let badges: [AchievementBadge] = Self.allBadges

    private var achievedCount: Int {
        badges.filter { $0.isAchieved(entries: entries) }.count
    }

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Progress header
                    VStack(spacing: 8) {
                        Text("\(achievedCount)/\(badges.count)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(colors.accent)

                        Text(String(localized: "バッジ獲得"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colors.accent)
                                    .frame(width: geo.size.width * CGFloat(achievedCount) / CGFloat(max(badges.count, 1)))
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)

                    // Badge grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(badges) { badge in
                            badgeCell(badge: badge, achieved: badge.isAchieved(entries: entries), colors: colors)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(String(localized: "バッジ"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func badgeCell(badge: AchievementBadge, achieved: Bool, colors: ThemeColors) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achieved ? colors.accent.opacity(0.15) : Color(.systemGray6))
                    .frame(width: 64, height: 64)

                Image(systemName: badge.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(achieved ? colors.accent : .gray.opacity(0.3))
            }

            Text(badge.name)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(achieved ? .primary : .tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(badge.description)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(achieved ? .secondary : .quaternary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Badge Definitions

    private static var allBadges: [AchievementBadge] {
        [
            // Streak badges
            AchievementBadge(id: "streak_3", icon: "flame", name: String(localized: "スタート"), description: String(localized: "3日連続記録")) { entries in
                StatsViewModel().longestStreak(entries: entries) >= 3
            },
            AchievementBadge(id: "streak_7", icon: "flame.fill", name: String(localized: "1週間"), description: String(localized: "7日連続記録")) { entries in
                StatsViewModel().longestStreak(entries: entries) >= 7
            },
            AchievementBadge(id: "streak_14", icon: "star", name: String(localized: "2週間"), description: String(localized: "14日連続記録")) { entries in
                StatsViewModel().longestStreak(entries: entries) >= 14
            },
            AchievementBadge(id: "streak_30", icon: "star.fill", name: String(localized: "1ヶ月"), description: String(localized: "30日連続記録")) { entries in
                StatsViewModel().longestStreak(entries: entries) >= 30
            },
            AchievementBadge(id: "streak_100", icon: "trophy.fill", name: String(localized: "100日"), description: String(localized: "100日連続記録")) { entries in
                StatsViewModel().longestStreak(entries: entries) >= 100
            },
            AchievementBadge(id: "streak_365", icon: "crown.fill", name: String(localized: "1年"), description: String(localized: "365日連続記録")) { entries in
                StatsViewModel().longestStreak(entries: entries) >= 365
            },

            // Recording badges
            AchievementBadge(id: "perfect_week", icon: "checkmark.seal.fill", name: String(localized: "完璧な週"), description: String(localized: "7日間全て記録")) { entries in
                let cal = Calendar.current
                guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return false }
                let days = Set((0 ..< 7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }.map { cal.startOfDay(for: $0) })
                let recordedDays = Set(entries.filter { $0.createdAt >= weekStart }.map { cal.startOfDay(for: $0.createdAt) })
                return days.isSubset(of: recordedDays)
            },
            AchievementBadge(id: "multi_record", icon: "square.stack.fill", name: String(localized: "振り返り上手"), description: String(localized: "1日3回以上記録")) { entries in
                let cal = Calendar.current
                let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.createdAt) }
                return grouped.values.contains { $0.count >= 3 }
            },
            AchievementBadge(id: "night_owl", icon: "moon.fill", name: String(localized: "夜型"), description: String(localized: "22時以降に30回記録")) { entries in
                let cal = Calendar.current
                let lateEntries = entries.filter { cal.component(.hour, from: $0.createdAt) >= 22 }
                return lateEntries.count >= 30
            },
            AchievementBadge(id: "early_bird", icon: "sunrise.fill", name: String(localized: "朝型"), description: String(localized: "7時前に30回記録")) { entries in
                let cal = Calendar.current
                let earlyEntries = entries.filter { cal.component(.hour, from: $0.createdAt) < 7 }
                return earlyEntries.count >= 30
            },

            // Score badges
            AchievementBadge(id: "rising_5", icon: "chart.line.uptrend.xyaxis", name: String(localized: "上昇気流"), description: String(localized: "5日連続スコア上昇")) { entries in
                let sorted = entries.sorted { $0.createdAt < $1.createdAt }
                var rising = 0
                for i in 1 ..< sorted.count {
                    if sorted[i].normalizedScore > sorted[i - 1].normalizedScore {
                        rising += 1
                        if rising >= 5 { return true }
                    } else {
                        rising = 0
                    }
                }
                return false
            },
            AchievementBadge(id: "stable_week", icon: "waveform.path", name: String(localized: "安定した週"), description: String(localized: "1週間の変動幅が小さい")) { entries in
                let cal = Calendar.current
                guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return false }
                let weekEntries = entries.filter { $0.createdAt >= weekStart }
                guard weekEntries.count >= 5 else { return false }
                let scores = weekEntries.map(\.normalizedScore)
                let max = scores.max() ?? 0
                let min = scores.min() ?? 0
                return (max - min) < 0.2
            },

            // Content badges
            AchievementBadge(id: "tagger", icon: "tag.fill", name: String(localized: "タグマスター"), description: String(localized: "50回タグを使用")) { entries in
                entries.filter { !$0.tags.isEmpty }.count >= 50
            },
            AchievementBadge(id: "writer", icon: "pencil.line", name: String(localized: "ライター"), description: String(localized: "50回メモを書く")) { entries in
                entries.filter { $0.memo != nil }.count >= 50
            },
            AchievementBadge(id: "photographer", icon: "camera.fill", name: String(localized: "フォトグラファー"), description: String(localized: "10回写真を添付")) { entries in
                entries.filter { $0.photoPath != nil }.count >= 10
            },
        ]
    }
}

#Preview {
    NavigationStack {
        BadgeCollectionView()
    }
    .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
    .environment(\.themeManager, ThemeManager())
}
