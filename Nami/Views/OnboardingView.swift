//
//  OnboardingView.swift
//  Nami
//
//  Onboarding flow: Welcome (value) → Theme → First Record → Notification
//

import SwiftData
import SwiftUI
import UIKit

/// Onboarding: 5 steps — Language → Welcome → Theme → First Record → Notification
struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.languageManager) private var languageManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When true, onboarding is shown as a replay (does not reset hasCompletedOnboarding)
    var isReplay: Bool = false
    /// Starting step (for jumping to specific steps from menu)
    var startingStep: Int = 0

    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0

    @State private var currentStep: Int
    @State private var enableReminder = false
    @State private var showPermissionDeniedAlert = false
    /// First record score (nil = not yet selected)
    @State private var firstRecordScore: Int? = nil
    /// Show RecordingSheet after score selection
    @State private var showRecordingSheet = false
    /// Onboarding tooltip visibility
    @State private var showTooltip = true
    /// Whether first record has been saved (to avoid double-save)
    @State private var firstRecordSaved = false
    /// Custom tag name for step 4
    @State private var customTagName = ""
    @State private var customTagSaved = false

    private let totalSteps = 6

    init(isReplay: Bool = false, startingStep: Int = 0) {
        self.isReplay = isReplay
        self.startingStep = startingStep
        _currentStep = State(initialValue: startingStep)
    }

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button (top right, not on last step)
                if currentStep < totalSteps - 1 {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Button {
                                HapticManager.lightFeedback()
                                completeOnboarding()
                            } label: {
                                Text(String(localized: "あとで設定する"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Text(String(localized: "記録画面の ? からいつでも再開できます"))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 8)
                    }
                } else {
                    Spacer().frame(height: 28)
                }

                TabView(selection: $currentStep) {
                    languageStep(colors: colors).tag(0)
                    welcomeStep(colors: colors).tag(1)
                    themeStep(colors: colors).tag(2)
                    firstRecordStep(colors: colors).tag(3)
                    customTagStep(colors: colors).tag(4)
                    notificationStep(colors: colors).tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                bottomBar(colors: colors)
            }
        }
        .alert("通知が許可されていません", isPresented: $showPermissionDeniedAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("リマインダーを受け取るには、設定アプリで通知を許可してください。")
        }
    }

    // MARK: - Bottom Bar

    private func bottomBar(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0 ..< totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? colors.accent : colors.accent.opacity(0.25))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }

            if currentStep == 3 || currentStep == 4 {
                // Step 3 (first record) / Step 4 (custom tag): only back button
                // User action auto-advances
                HStack(spacing: 12) {
                    Button {
                        HapticManager.lightFeedback()
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(colors.accent)
                            .frame(width: 52, height: 52)
                            .background(colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else if currentStep < totalSteps - 1 {
                // Other steps: back + next
                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button {
                            HapticManager.lightFeedback()
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.accent)
                                .frame(width: 52, height: 52)
                                .background(colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    Button {
                        HapticManager.lightFeedback()
                        withAnimation { currentStep += 1 }
                    } label: {
                        Text(String(localized: "次へ"))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(colors.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
            } else {
                // Final step: "はじめる"
                HStack(spacing: 12) {
                    Button {
                        HapticManager.lightFeedback()
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(colors.accent)
                            .frame(width: 52, height: 52)
                            .background(colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        HapticManager.successFeedback()
                        completeOnboarding()
                    } label: {
                        Text(String(localized: "はじめる"))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(colors.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 32)
        .padding(.top, 8)
    }

    // MARK: - Step 0: Language Selection

    private func languageStep(colors: ThemeColors) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundStyle(colors.accent.gradient)

            VStack(spacing: 8) {
                Text("Choose Language")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.accent)

                Text("言語を選んでください")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                    let isSelected = languageManager.currentLanguage == language ||
                        (languageManager.currentLanguage == .system && Locale.current.language.languageCode?.identifier == language.rawValue)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            languageManager.currentLanguage = language
                        }
                        HapticManager.lightFeedback()
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.system(size: 28))

                            Text(language.nativeName)
                                .font(.system(.title3, design: .rounded, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(.primary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(colors.accent)
                                    .font(.title3)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(isSelected ? colors.accent.opacity(0.5) : .clear, lineWidth: 1.5))
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 1: Welcome (Value Proposition)

    private func welcomeStep(colors: ThemeColors) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "water.waves")
                .font(.system(size: 80))
                .foregroundStyle(colors.accent.gradient)
                .symbolEffect(.variableColor.iterative, options: .repeating)

            VStack(spacing: 12) {
                Text("Nami")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.accent)

                Text(String(localized: "気分の波を、数字にする"))
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Value props: quantification + HealthKit + privacy
            VStack(alignment: .leading, spacing: 20) {
                valueRow(
                    icon: "chart.bar.xaxis.ascending",
                    color: colors.accent,
                    text: String(localized: "あなたの気分スコアから、隠れたパターンを発見")
                )
                valueRow(
                    icon: "heart.text.clipboard",
                    color: .red,
                    text: String(localized: "HealthKitと連携して、睡眠・運動の影響も分析")
                )
                valueRow(
                    icon: "lock.shield.fill",
                    color: .green,
                    text: String(localized: "プライバシーファースト。データは外に出ません")
                )
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func valueRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Step 2: Theme

    private func themeStep(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(colors.accent.gradient)

                Text(String(localized: "テーマを選ぶ"))
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(String(localized: "お好みの色合いを選んでください"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme
                    let tc = theme.colors

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            themeManager.currentTheme = theme
                        }
                        HapticManager.lightFeedback()
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(
                                    colors: [
                                        colorScheme == .dark ? tc.backgroundStartDark : tc.backgroundStartLight,
                                        colorScheme == .dark ? tc.backgroundEndDark : tc.backgroundEndLight,
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 48, height: 48)
                                .overlay(Circle().fill(tc.accent).frame(width: 16, height: 16))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? tc.accent : .clear, lineWidth: 2.5))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.displayName)
                                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                Text(theme.themeDescription)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(tc.accent)
                                    .font(.title3)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? tc.accent.opacity(0.5) : .clear, lineWidth: 1))
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 3: First Record (Aha Moment)

    private func firstRecordStep(colors: ThemeColors) -> some View {
        ZStack {
            // Tap anywhere outside buttons to dismiss tooltips
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showTooltip = false }
                }

            VStack(spacing: 20) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text(String(localized: "今の気分は？"))
                        .font(.system(.title, design: .rounded, weight: .bold))
                }

                // Tooltip: Large speech bubble with all info
                if showTooltip {
                    VStack(spacing: 0) {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(colors.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "数字をタップしてみましょう"))
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text(String(localized: "今の気分に近い数字を選んでください"))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Text("1")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.red)
                                    Text(String(localized: "= とても低い"))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("10")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.green)
                                    Text(String(localized: "= とても高い"))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Text(String(localized: "このまま右上の ✓ でも保存できます"))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.regularMaterial)
                                .shadow(color: colors.accent.opacity(0.2), radius: 12, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(colors.accent.opacity(0.3), lineWidth: 1.5)
                        )

                        // Arrow pointing down
                        Triangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 18, height: 10)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .padding(.horizontal, 24)
                }

                // Score display
                if let score = firstRecordScore {
                    Text("\(score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(colors.color(for: score, minScore: 1, maxScore: 10))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("?")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                // Score buttons (1-10 in 2 rows)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(1 ... 10, id: \.self) { score in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                firstRecordScore = score
                                showTooltip = false
                            }
                            HapticManager.lightFeedback()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showRecordingSheet = true
                            }
                        } label: {
                            Text("\(score)")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(firstRecordScore == score
                                            ? colors.color(for: score, minScore: 1, maxScore: 10)
                                            : colors.accent.opacity(0.08))
                                )
                                .foregroundStyle(firstRecordScore == score ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                // Scale hint (only when tooltip dismissed)
                if !showTooltip {
                    Text(String(localized: "1 = とても低い　10 = とても高い"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
                Spacer()
            }
        }
        .animation(.spring(response: 0.3), value: firstRecordScore)
        .animation(.easeInOut(duration: 0.25), value: showTooltip)
        .sheet(isPresented: $showRecordingSheet) {
            if let score = firstRecordScore {
                RecordingSheet(
                    score: score,
                    maxScore: 10,
                    scoreRangeMin: 1,
                    themeColors: themeManager.colors,
                    isOnboarding: true,
                    onSave: { memo, photo, voiceMemoURL, tags, energyLevel in
                        saveFirstRecordWithDetails(
                            score: score,
                            memo: memo,
                            photo: photo,
                            voiceMemoURL: voiceMemoURL,
                            tags: tags,
                            energyLevel: energyLevel
                        )
                        // Auto-advance to next step after saving
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { currentStep += 1 }
                        }
                    },
                    onSkip: {
                        // Save score only, then advance
                        saveFirstRecord(score: score)
                        showRecordingSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { currentStep += 1 }
                        }
                    }
                )
            }
        }
    }

    // MARK: - Step 4: Custom Tag Creation (Deepen)

    private func customTagStep(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(colors.accent.gradient)

                Text(String(localized: "気分の理由をタグにしよう"))
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(String(localized: "「コーヒー」「散歩」「残業」など\n日常の行動をタグにして、気分との関係を発見できます"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Tag name input
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(colors.accent)

                    TextField(String(localized: "タグ名を入力（例: コーヒー）"), text: $customTagName)
                        .font(.system(.body, design: .rounded))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )

                // Suggestion chips
                HStack(spacing: 8) {
                    ForEach(["散歩", "読書", "運動", "コーヒー"], id: \.self) { suggestion in
                        Button {
                            customTagName = suggestion
                            HapticManager.lightFeedback()
                        } label: {
                            Text(suggestion)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(customTagName == suggestion ? colors.accent : colors.accent.opacity(0.08))
                                )
                                .foregroundStyle(customTagName == suggestion ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Save button
                Button {
                    saveCustomTag()
                    HapticManager.successFeedback()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { currentStep += 1 }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text(String(localized: "このタグを作成"))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(customTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : colors.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(customTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if customTagSaved {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(localized: "タグを作成しました！"))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.horizontal, 24)

            // Skip hint
            Button {
                withAnimation { currentStep += 1 }
            } label: {
                Text(String(localized: "スキップして次へ"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Spacer()
        }
        .animation(.spring(response: 0.3), value: customTagSaved)
    }

    // MARK: - Step 5: Notification + Start

    private func notificationStep(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.gradient)

                Text(String(localized: "毎日の習慣にする"))
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(String(localized: "リマインダーで記録を忘れずに"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 20) {
                HStack {
                    Label(String(localized: "リマインダーを設定"), systemImage: "bell")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    Toggle("", isOn: $enableReminder)
                        .labelsHidden()
                        .tint(colors.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))

                if enableReminder {
                    DatePicker(
                        "通知時刻",
                        selection: Binding(
                            get: {
                                var c = DateComponents()
                                c.hour = reminderHour
                                c.minute = reminderMinute
                                return Calendar.current.date(from: c) ?? .now
                            },
                            set: { d in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                                reminderHour = c.hour ?? 21
                                reminderMinute = c.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 120)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.3), value: enableReminder)

            // Social proof
            Text(String(localized: "毎日記録するユーザーは、4倍多くのパターンを発見しています"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Actions

    private func saveFirstRecord(score: Int) {
        guard !firstRecordSaved else { return }
        let entry = MoodEntry(
            score: score,
            maxScore: 10,
            scoreRangeMin: 1,
            source: "app"
        )
        modelContext.insert(entry)
        firstRecordSaved = true
        HapticManager.recordFeedback()

        // Track recording time for smart reminder
        NotificationManager.trackRecordingTime()
        NotificationManager.updateLastRecordDate()
        NotificationManager.cancelWinback()
    }

    private func saveFirstRecordWithDetails(
        score: Int,
        memo: String,
        photo: UIImage?,
        voiceMemoURL: URL?,
        tags: [String],
        energyLevel: Int?
    ) {
        guard !firstRecordSaved else { return }
        let entry = MoodEntry(
            score: score,
            maxScore: 10,
            scoreRangeMin: 1,
            source: "app"
        )

        if !memo.isEmpty {
            entry.memo = String(memo.prefix(100))
        }
        if let photo {
            entry.photoPath = MediaManager.savePhoto(photo)
        }
        if let voiceMemoURL {
            entry.voiceMemoPath = MediaManager.saveVoiceMemo(from: voiceMemoURL)
        }
        entry.tags = tags
        entry.energyLevel = energyLevel

        modelContext.insert(entry)
        firstRecordSaved = true
        showRecordingSheet = false
        HapticManager.recordFeedback()

        NotificationManager.trackRecordingTime()
        NotificationManager.updateLastRecordDate()
        NotificationManager.cancelWinback()
    }

    private func saveCustomTag() {
        let trimmed = customTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customTagSaved else { return }
        let tag = EmotionTag(
            name: trimmed,
            category: .custom,
            icon: "star.fill",
            isDefault: false,
            sortOrder: 9999
        )
        modelContext.insert(tag)
        customTagSaved = true
        UserDefaults.standard.set(true, forKey: "hasCreatedCustomTag")
    }

    private func completeOnboarding() {
        // Save first record if selected but not yet saved via RecordingSheet
        if let score = firstRecordScore, !firstRecordSaved {
            saveFirstRecord(score: score)
        }

        // Apply notification settings
        if enableReminder {
            reminderEnabled = true
            Task {
                let granted = await NotificationManager.requestPermission()
                if granted {
                    NotificationManager.scheduleReminder(hour: reminderHour, minute: reminderMinute)
                } else {
                    await MainActor.run {
                        reminderEnabled = false
                        showPermissionDeniedAlert = true
                    }
                }
            }
        }

        if isReplay {
            dismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.4)) {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
