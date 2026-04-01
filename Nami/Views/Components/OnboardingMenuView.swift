//
//  OnboardingMenuView.swift
//  Nami
//
//  Onboarding replay menu — jump to specific steps or start full flow
//

import SwiftUI

/// Menu shown when user taps "?" on the record tab
/// Allows replaying full onboarding or jumping to specific steps
struct OnboardingMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("hasCreatedCustomTag") private var hasCreatedCustomTag = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false

    /// Callback with optional starting step
    let onSelect: (Int?) -> Void

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "water.waves")
                                .font(.system(size: 36))
                                .foregroundStyle(colors.accent.gradient)
                                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.3))

                            Text(String(localized: "Namiの使い方"))
                                .font(.system(.title3, design: .rounded, weight: .bold))

                            Text(String(localized: "気になる項目をタップして設定できます"))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                        // Full onboarding
                        menuItem(
                            icon: "play.circle.fill",
                            title: String(localized: "フル・オンボーディングを開始"),
                            subtitle: String(localized: "最初から全ステップを体験"),
                            isCompleted: false,
                            colors: colors
                        ) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSelect(0)
                            }
                        }

                        Divider().padding(.horizontal)

                        // Individual steps
                        menuItem(
                            icon: "paintpalette.fill",
                            title: String(localized: "テーマを変更する"),
                            subtitle: String(localized: "Ocean, Lavender, Mono Gold, Forest"),
                            isCompleted: true,
                            colors: colors
                        ) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSelect(2)
                            }
                        }

                        menuItem(
                            icon: "tag.fill",
                            title: String(localized: "カスタムタグを作ってみる"),
                            subtitle: String(localized: "気分の理由をタグで記録"),
                            isCompleted: hasCreatedCustomTag,
                            colors: colors
                        ) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSelect(4)
                            }
                        }

                        menuItem(
                            icon: "bell.badge.fill",
                            title: String(localized: "通知を設定する"),
                            subtitle: String(localized: "毎日の記録を習慣にする"),
                            isCompleted: reminderEnabled,
                            colors: colors
                        ) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSelect(5)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(String(localized: "ガイド"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func menuItem(
        icon: String,
        title: String,
        subtitle: String,
        isCompleted: Bool,
        colors: ThemeColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(colors.accent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
