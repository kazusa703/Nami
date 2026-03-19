//
//  StreakBadgeView.swift
//  Nami
//
//  Streak display with milestone badges and gamification
//

import SwiftUI

/// Milestone definitions for streak achievements
enum StreakMilestone: Int, CaseIterable {
    case three = 3
    case seven = 7
    case fourteen = 14
    case thirty = 30
    case fifty = 50
    case hundred = 100
    case twoHundred = 200
    case yearlong = 365

    var icon: String {
        switch self {
        case .three: return "flame"
        case .seven: return "flame.fill"
        case .fourteen: return "star"
        case .thirty: return "star.fill"
        case .fifty: return "trophy"
        case .hundred: return "trophy.fill"
        case .twoHundred: return "crown"
        case .yearlong: return "crown.fill"
        }
    }

    var label: String {
        switch self {
        case .three: return String(localized: "3日")
        case .seven: return String(localized: "1週間")
        case .fourteen: return String(localized: "2週間")
        case .thirty: return String(localized: "1ヶ月")
        case .fifty: return String(localized: "50日")
        case .hundred: return String(localized: "100日")
        case .twoHundred: return String(localized: "200日")
        case .yearlong: return String(localized: "1年")
        }
    }

    /// Next milestone after current streak, nil if beyond all
    static func next(after streak: Int) -> StreakMilestone? {
        allCases.first { $0.rawValue > streak }
    }

    /// Current achieved milestone for a streak
    static func current(for streak: Int) -> StreakMilestone? {
        allCases.last { $0.rawValue <= streak }
    }
}

/// Compact streak badge for MainView
struct StreakBadgeView: View {
    let currentStreak: Int
    let longestStreak: Int
    let colors: ThemeColors

    @State private var showDetail = false
    @State private var showCelebration = false
    @AppStorage("lastCelebratedMilestone") private var lastCelebratedMilestone: Int = 0

    var body: some View {
        if currentStreak > 0 {
            Button {
                showDetail = true
            } label: {
                HStack(spacing: 6) {
                    // Flame icon with milestone color
                    Image(systemName: milestoneIcon)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(milestoneColor)
                        .symbolEffect(.bounce, value: showCelebration)

                    Text("\(currentStreak)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(String(localized: "日連続"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(milestoneColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDetail) {
                streakDetailView
                    .presentationCompactAdaptation(.popover)
            }
            .onAppear { checkCelebration() }
        }
    }

    // MARK: - Detail Popover

    private var streakDetailView: some View {
        VStack(spacing: 16) {
            // Current streak
            VStack(spacing: 4) {
                Image(systemName: milestoneIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(milestoneColor)

                Text("\(currentStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(String(localized: "日連続記録中"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Stats
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(longestStreak)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(String(localized: "最長記録"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let next = StreakMilestone.next(after: currentStreak) {
                    VStack(spacing: 2) {
                        Text("\(next.rawValue - currentStreak)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(colors.accent)
                        Text(String(localized: "次の\(next.label)まで"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Milestone badges
            milestoneGrid
        }
        .padding()
        .frame(minWidth: 220)
    }

    private var milestoneGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
            ForEach(StreakMilestone.allCases, id: \.rawValue) { milestone in
                let achieved = currentStreak >= milestone.rawValue || longestStreak >= milestone.rawValue
                VStack(spacing: 2) {
                    Image(systemName: milestone.icon)
                        .font(.system(.body))
                        .foregroundStyle(achieved ? milestoneColor(for: milestone) : .gray.opacity(0.3))
                    Text(milestone.label)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(achieved ? .primary : .tertiary)
                }
            }
        }
    }

    // MARK: - Helpers

    private var milestoneIcon: String {
        StreakMilestone.current(for: currentStreak)?.icon ?? "flame"
    }

    private var milestoneColor: Color {
        guard let milestone = StreakMilestone.current(for: currentStreak) else {
            return colors.accent
        }
        return milestoneColor(for: milestone)
    }

    private func milestoneColor(for milestone: StreakMilestone) -> Color {
        switch milestone {
        case .three, .seven: return .orange
        case .fourteen, .thirty: return colors.accent
        case .fifty, .hundred: return .purple
        case .twoHundred, .yearlong: return .yellow
        }
    }

    private func checkCelebration() {
        guard let achieved = StreakMilestone.current(for: currentStreak) else { return }
        if achieved.rawValue > lastCelebratedMilestone {
            showCelebration = true
            lastCelebratedMilestone = achieved.rawValue
            HapticManager.successFeedback()
        }
    }
}
