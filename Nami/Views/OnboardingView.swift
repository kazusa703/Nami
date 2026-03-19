//
//  OnboardingView.swift
//  Nami
//
//  初回起動時のオンボーディングフロー
//  Welcome → テーマ選択 → スコアレンジ → 通知設定 → 完了
//

import SwiftUI

/// オンボーディング画面
/// 初回起動時にアプリの紹介、テーマ選択、スコア範囲、通知設定を案内する
struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager

    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(AppConstants.scoreRangeKey) private var scoreRangeRaw: String = ScoreRange.pos10.rawValue
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0

    /// 現在のステップ（0〜4）
    @State private var currentStep = 0
    /// 通知のON/OFF（ローカルState → 完了時にAppStorageへ反映）
    @State private var enableReminder = false
    /// 通知権限が拒否された場合
    @State private var showPermissionDeniedAlert = false

    /// ステップ数（Welcome, Theme, ScoreRange, Notification, Done）
    private let totalSteps = 5

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            // 背景グラデーション
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // コンテンツ
                TabView(selection: $currentStep) {
                    welcomeStep(colors: colors)
                        .tag(0)
                    themeStep(colors: colors)
                        .tag(1)
                    scoreRangeStep(colors: colors)
                        .tag(2)
                    notificationStep(colors: colors)
                        .tag(3)
                    doneStep(colors: colors)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                // ページインジケーター + ボタン
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

    // MARK: - 下部バー（インジケーター + ボタン）

    @ViewBuilder
    private func bottomBar(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            // ページインジケーター
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? colors.accent : colors.accent.opacity(0.25))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }

            // ボタン
            if currentStep < totalSteps - 1 {
                HStack(spacing: 12) {
                    // 「戻る」ボタン（ステップ1以降で表示）
                    if currentStep > 0 {
                        Button {
                            HapticManager.lightFeedback()
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(colors.accent)
                                .frame(width: 52, height: 52)
                                .background(colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // 「次へ」ボタン
                    Button {
                        HapticManager.lightFeedback()
                        withAnimation {
                            currentStep += 1
                        }
                    } label: {
                        Text("次へ")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(colors.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
            } else {
                // 「はじめる」ボタン（最終ステップ）
                HStack(spacing: 12) {
                    // 戻るボタン
                    Button {
                        HapticManager.lightFeedback()
                        withAnimation {
                            currentStep -= 1
                        }
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
                        Text("はじめる")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(colors.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
            }

            // スキップ（最終ステップ以外）
            if currentStep < totalSteps - 1 && currentStep > 0 {
                Button {
                    HapticManager.lightFeedback()
                    withAnimation {
                        currentStep = totalSteps - 1
                    }
                } label: {
                    Text("スキップ")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 32)
        .padding(.top, 8)
    }

    // MARK: - Step 1: Welcome

    @ViewBuilder
    private func welcomeStep(colors: ThemeColors) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // 波アイコン
            Image(systemName: "water.waves")
                .font(.system(size: 80))
                .foregroundStyle(colors.accent.gradient)
                .symbolEffect(.variableColor.iterative, options: .repeating)

            VStack(spacing: 12) {
                Text("Nami")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.accent)

                Text("気分の波を、やさしく記録")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // 機能紹介
            VStack(alignment: .leading, spacing: 20) {
                featureRow(
                    icon: "pencil.circle.fill",
                    color: colors.accent,
                    text: "毎日の気分をスコアで記録"
                )
                featureRow(
                    icon: "chart.xyaxis.line",
                    color: colors.graphLine,
                    text: "グラフや統計で振り返る"
                )
                featureRow(
                    icon: "bell.fill",
                    color: .orange,
                    text: "リマインダーで習慣化"
                )
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    /// 機能紹介行
    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Step 2: テーマ選択

    @ViewBuilder
    private func themeStep(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(colors.accent.gradient)

                Text("テーマを選ぶ")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("お好みの色合いを選んでください")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // テーマカード
            VStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme
                    let themeColors = theme.colors

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            themeManager.currentTheme = theme
                        }
                        HapticManager.lightFeedback()
                    } label: {
                        HStack(spacing: 14) {
                            // テーマプレビューカード
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            colorScheme == .dark ? themeColors.backgroundStartDark : themeColors.backgroundStartLight,
                                            colorScheme == .dark ? themeColors.backgroundEndDark : themeColors.backgroundEndLight
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .fill(themeColors.accent)
                                        .frame(width: 16, height: 16)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? themeColors.accent : .clear, lineWidth: 2.5)
                                )

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
                                    .foregroundStyle(themeColors.accent)
                                    .font(.title3)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isSelected ? themeColors.accent.opacity(0.5) : .clear, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 3: スコアレンジ

    /// 現在のスコアレンジ
    private var currentScoreRange: ScoreRange {
        ScoreRange(rawValue: scoreRangeRaw) ?? .pos10
    }

    @ViewBuilder
    private func scoreRangeStep(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 44))
                    .foregroundStyle(colors.accent.gradient)

                Text("スコアの範囲")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("記録に使うスコアの範囲を選んでください")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // スコアレンジ選択（ScrollViewで8パターン表示）
            ScrollView {
                VStack(spacing: 8) {
                    // 正のみセクション
                    Text("正のみ")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)

                    ForEach(ScoreRange.positiveRanges) { range in
                        scoreRangeButton(range: range, colors: colors)
                    }

                    // 負ありセクション
                    Text("負あり")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.top, 8)

                    ForEach(ScoreRange.negativeRanges) { range in
                        scoreRangeButton(range: range, colors: colors)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    /// スコアレンジ選択ボタン
    @ViewBuilder
    private func scoreRangeButton(range: ScoreRange, colors: ThemeColors) -> some View {
        let isSelected = scoreRangeRaw == range.rawValue

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scoreRangeRaw = range.rawValue
            }
            range.save()
            HapticManager.lightFeedback()
        } label: {
            HStack(spacing: 16) {
                Text(range.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(isSelected ? .white : colors.accent)
                    .frame(width: 80, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? colors.accent : colors.accent.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(range.description)
                        .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(colors.accent)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? colors.accent.opacity(0.5) : .clear, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Step 4: 通知設定

    @ViewBuilder
    private func notificationStep(colors: ThemeColors) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.gradient)

                Text("通知リマインダー")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("毎日決まった時間にお知らせします")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 20) {
                // リマインダートグル
                HStack {
                    Label("リマインダーを設定", systemImage: "bell")
                        .font(.system(.body, design: .rounded))

                    Spacer()

                    Toggle("", isOn: $enableReminder)
                        .labelsHidden()
                        .tint(colors.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )

                // 時刻ピッカー（ONの場合）
                if enableReminder {
                    DatePicker(
                        "通知時刻",
                        selection: Binding(
                            get: {
                                var components = DateComponents()
                                components.hour = reminderHour
                                components.minute = reminderMinute
                                return Calendar.current.date(from: components) ?? .now
                            },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                reminderHour = components.hour ?? 21
                                reminderMinute = components.minute ?? 0
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

            Text("あとで設定する")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 5: 完了

    @ViewBuilder
    private func doneStep(colors: ThemeColors) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(colors.accent.gradient)

            VStack(spacing: 12) {
                Text("準備完了！")
                    .font(.system(.title, design: .rounded, weight: .bold))

                Text("さっそく記録してみましょう")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - 完了処理

    /// オンボーディングを完了する
    private func completeOnboarding() {
        // 通知設定を反映
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

        // オンボーディング完了
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
        .environment(\.themeManager, ThemeManager())
}
