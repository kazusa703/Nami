//
//  MainView.swift
//  Nami
//
//  メイン記録画面 - スコア範囲と入力方式に対応した気分記録
//

import SwiftData
import SwiftUI

/// メイン記録画面
/// アプリ起動直後に表示され、1タップで気分を記録できる
struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.weatherManager) private var weatherManager

    @State private var viewModel = MoodViewModel()
    @State private var statsVM = StatsViewModel()
    /// Cached streak values (rebuilt on entries.count change)
    @State private var cachedCurrentStreak: Int = 0
    @State private var cachedLongestStreak: Int = 0
    /// Progressive disclosure: coaching tips after Nth recording
    @AppStorage("totalRecordCount") private var totalRecordCount: Int = 0
    @State private var showCoachTip: String? = nil
    @State private var showMainHelp = false
    /// Personalized greeting message (4-level fallback)
    @State private var greetingMessage: String = ""
    /// Entry being edited from inbox
    @State private var inboxEditingEntry: MoodEntry?
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    /// アプリ外記録で詳細未追加のエントリ（widget + notification）
    private var quickRecordsNeedingDetails: [MoodEntry] {
        entries.filter { $0.needsDetails }
    }

    /// 設定から読み取るスコアレンジID
    @AppStorage(AppConstants.scoreRangeKey) private var scoreRangeRaw: String = ScoreRange.pos10.rawValue
    /// 設定から読み取る入力方式
    @AppStorage(AppConstants.scoreInputTypeKey) private var scoreInputTypeRaw: String = ScoreInputType.buttons.rawValue

    /// 現在のスコアレンジ
    private var scoreRange: ScoreRange {
        ScoreRange(rawValue: scoreRangeRaw) ?? .pos10
    }

    /// 現在の入力方式
    private var scoreInputType: ScoreInputType {
        ScoreInputType(rawValue: scoreInputTypeRaw) ?? .buttons
    }

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                // 背景グラデーション
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    let isCompact = verticalSizeClass == .compact

                    // クイック記録の未整理バナー（widget + notification）
                    if !quickRecordsNeedingDetails.isEmpty {
                        quickRecordInbox(entries: quickRecordsNeedingDetails, colors: colors)
                    }

                    if isCompact {
                        // 横画面: スクロール可能なレイアウト（間隔を縮小）
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                // タイトル（コンパクト）
                                Text("今の気分は？")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.accent)

                                // 記録完了アニメーション
                                if viewModel.showRecordedAnimation {
                                    HStack(spacing: 8) {
                                        Text("\(viewModel.recordedScore)")
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                            .foregroundStyle(colors.color(for: viewModel.recordedScore, minScore: viewModel.recordedScoreRangeMin, maxScore: viewModel.recordedMaxScore))
                                            .transition(.scale.combined(with: .opacity))
                                        Text("記録しました")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .transition(.opacity)
                                    }
                                }

                                // スコア入力ビュー
                                ScoreInputView(
                                    inputType: scoreInputType,
                                    minScore: scoreRange.minValue,
                                    maxScore: scoreRange.maxValue,
                                    themeColors: colors
                                ) { score in
                                    viewModel.recordMood(score: score, maxScore: scoreRange.maxValue, scoreRangeMin: scoreRange.minValue, context: modelContext, weatherManager: weatherManager)
                                }

                                // 最新の記録表示
                                if let latest = entries.first {
                                    latestRecordView(entry: latest, colors: colors)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // 縦画面: 通常レイアウト
                        VStack(spacing: 32) {
                            Spacer()

                            // ストリークバッジ
                            StreakBadgeView(
                                currentStreak: cachedCurrentStreak,
                                longestStreak: cachedLongestStreak,
                                colors: colors
                            )

                            // パーソナライズ挨拶
                            VStack(spacing: 8) {
                                Text(greetingMessage.isEmpty ? String(localized: "今の気分は？") : greetingMessage)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(colors.accent)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)

                                Text("\(scoreRange.displayName)でタップして記録")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            // 記録完了アニメーション
                            if viewModel.showRecordedAnimation {
                                VStack(spacing: 4) {
                                    Text("\(viewModel.recordedScore)")
                                        .font(.system(size: 64, weight: .bold, design: .rounded))
                                        .foregroundStyle(colors.color(for: viewModel.recordedScore, minScore: viewModel.recordedScoreRangeMin, maxScore: viewModel.recordedMaxScore))
                                        .transition(.scale.combined(with: .opacity))

                                    Text("記録しました")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .transition(.opacity)
                                }
                                .frame(height: 100)
                            }

                            // スコア入力ビュー（ボタン or スライダー）
                            ScoreInputView(
                                inputType: scoreInputType,
                                minScore: scoreRange.minValue,
                                maxScore: scoreRange.maxValue,
                                themeColors: colors
                            ) { score in
                                viewModel.recordMood(score: score, maxScore: scoreRange.maxValue, scoreRangeMin: scoreRange.minValue, context: modelContext, weatherManager: weatherManager)
                            }

                            Spacer()

                            // 最新の記録表示 or 初回ヒント
                            if let latest = entries.first {
                                latestRecordView(entry: latest, colors: colors)
                            } else {
                                firstLaunchHint(colors: colors)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            Button { showMainHelp = true } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(.body))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showMainHelp) {
            FeatureHelpSheet(title: String(localized: "画面の見方"), items: HelpContent.mainViewHelp, accentColor: themeManager.colors.accent)
        }
        .onAppear {
            rebuildStreakCache()
            // Generate personalized greeting
            Task {
                let weather = await weatherManager.fetchCurrentWeather()
                greetingMessage = GreetingService.generateGreeting(
                    entries: entries,
                    weatherCondition: weather.condition,
                    weatherTemperature: weather.temperature
                )
            }
            // Show custom tag creation tip on first launch after onboarding
            if !entries.isEmpty && !UserDefaults.standard.bool(forKey: "hasCreatedCustomTag") {
                let dismissedKey = "dismissedCustomTagTip"
                if !UserDefaults.standard.bool(forKey: dismissedKey) {
                    showCoachTipDelayed(String(localized: "💡 自分だけのタグを作ってみましょう！設定 → タグから追加できます"))
                }
            }
        }
        .onChange(of: entries.count) { oldCount, newCount in
            rebuildStreakCache()
            // Progressive disclosure: show coaching tips after specific recording counts
            if newCount > oldCount {
                totalRecordCount = newCount
                showCoachingTipIfNeeded()
            }
        }
        .overlay(alignment: .bottom) {
            if let tip = showCoachTip {
                coachTipBanner(tip, colors: themeManager.colors)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60)
            }
        }
        .animation(.spring(response: 0.4), value: showCoachTip)
        .sheet(isPresented: $show14DayCard) {
            FourteenDayMilestoneCard(entries: entries, themeColors: themeManager.colors)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showRecordingSheet) {
            RecordingSheet(
                score: viewModel.recordedScore,
                maxScore: viewModel.recordedMaxScore,
                scoreRangeMin: viewModel.recordedScoreRangeMin,
                themeColors: themeManager.colors,
                onSave: { memo, photo, voiceMemoURL, tags, energyLevel in
                    viewModel.saveRecording(memo: memo, photo: photo, voiceMemoURL: voiceMemoURL, tags: tags, energyLevel: energyLevel)
                },
                onSkip: {
                    viewModel.skipRecording()
                }
            )
        }
    }

    // MARK: - ウィジェットエントリバナー

    // MARK: - Quick Record Inbox

    private func quickRecordInbox(entries quickEntries: [MoodEntry], colors: ThemeColors) -> some View {
        Button {
            // Open the first entry for editing
            inboxEditingEntry = quickEntries.first
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(colors.accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "\(quickEntries.count)件の記録にタグ・メモを追加できます"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(String(localized: "タップして振り返りましょう"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(quickEntries.count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(colors.accent))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(colors.accent.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .sheet(item: $inboxEditingEntry) { entry in
            RecordingSheet(
                score: entry.score,
                maxScore: entry.maxScore,
                scoreRangeMin: entry.scoreRangeMin,
                themeColors: colors,
                isEditing: true,
                initialMemo: entry.memo ?? "",
                initialTags: Set(entry.tags),
                onSave: { memo, photo, voiceMemoURL, tags, energyLevel in
                    if !memo.isEmpty { entry.memo = String(memo.prefix(100)) }
                    if let photo { entry.photoPath = MediaManager.savePhoto(photo) }
                    if let voiceMemoURL { entry.voiceMemoPath = MediaManager.saveVoiceMemo(from: voiceMemoURL) }
                    entry.tags = tags
                    entry.energyLevel = energyLevel
                    inboxEditingEntry = nil
                    // Open next entry if available
                    let remaining = quickRecordsNeedingDetails.filter { $0.id != entry.id }
                    if let next = remaining.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            inboxEditingEntry = next
                        }
                    }
                },
                onSkip: {
                    inboxEditingEntry = nil
                }
            )
        }
        .animation(.spring(response: 0.4), value: quickEntries.count)
    }

    /// 初回起動時のヒント表示
    private func firstLaunchHint(colors: ThemeColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(colors.accent.opacity(0.6))

            Text("上のボタンをタップして\n最初の記録をつけてみましょう")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }

    /// 最新の記録を表示するビュー
    private func latestRecordView(entry: MoodEntry, colors: ThemeColors) -> some View {
        VStack(spacing: 6) {
            Text("最新の記録")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(entry.score)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(colors.color(for: entry.score, minScore: entry.scoreRangeMin, maxScore: entry.maxScore))
                    Text("/\(entry.maxScore)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                // 写真・ボイスメモのインジケータ
                if entry.photoPath != nil {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundStyle(colors.accent.opacity(0.6))
                }
                if entry.voiceMemoPath != nil {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundStyle(colors.accent.opacity(0.6))
                }

                // エネルギーレベルアイコン
                if let energy = entry.energyLevel {
                    Image(systemName: energyIcon(for: energy))
                        .font(.caption)
                        .foregroundStyle(energyColor(for: energy))
                }

                // ウィジェット記録アイコン
                if entry.source == "widget" {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.6))
                }

                if let memo = entry.memo {
                    Text(memo)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // タグチップ表示（最大3個 + "+N"）
            if !entry.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(.caption2, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(colors.accent.opacity(0.1)))
                            .foregroundStyle(colors.accent)
                    }
                    if entry.tags.count > 3 {
                        Text("+\(entry.tags.count - 3)")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Nemuri sleep summary (if available)
            if let sleep = NemuriDataReader.readLatestSleep(),
               Calendar.current.isDateInToday(sleep.wakeTime) || Calendar.current.isDateInYesterday(sleep.wakeTime)
            {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                    Text(String(localized: "\(sleep.formattedDuration) · スコア\(Int(sleep.qualityScore))"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.indigo.opacity(0.08)))
            }

            Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
    }

    // MARK: - Energy Helpers

    private func energyIcon(for level: Int) -> String {
        switch level {
        case 1: return "battery.25percent"
        case 2: return "battery.50percent"
        case 3: return "battery.100percent"
        default: return "battery.50percent"
        }
    }

    private func energyColor(for level: Int) -> Color {
        switch level {
        case 1: return .orange
        case 2: return .blue
        case 3: return .green
        default: return .secondary
        }
    }

    // MARK: - Progressive Disclosure

    private func showCoachingTipIfNeeded() {
        let count = totalRecordCount
        switch count {
        case 1:
            showCoachTipDelayed(String(localized: "タグを付けると、パターン分析がもっと深まります"))
        case 2:
            // Check if user has created any custom tags
            if !UserDefaults.standard.bool(forKey: "hasCreatedCustomTag") {
                showCoachTipDelayed(String(localized: "💡 自分だけのタグを作ってみましょう！設定 → タグから追加できます"))
            }
        case 3:
            if !entries.contains(where: { $0.energyLevel != nil }) {
                showCoachTipDelayed(String(localized: "エネルギーレベルも記録してみましょう。気分との関係が見えてきます"))
            }
        case 7:
            showCoachTipDelayed(String(localized: "1週間の記録が溜まりました！統計タブでインサイトを確認しましょう"))
        case 14:
            show14DayMilestone()
        default:
            break
        }
    }

    @State private var show14DayCard = false

    private func show14DayMilestone() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            show14DayCard = true
        }
    }

    private func showCoachTipDelayed(_ text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCoachTip = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            showCoachTip = nil
        }
    }

    private func coachTipBanner(_ text: String, colors _: ThemeColors) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                showCoachTip = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Cache

    private func rebuildStreakCache() {
        cachedCurrentStreak = statsVM.currentStreak(entries: entries)
        cachedLongestStreak = statsVM.longestStreak(entries: entries)
    }
}

// MARK: - 14-Day Milestone Card

/// Shown after 14 days of recording - the first real payoff
struct FourteenDayMilestoneCard: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [MoodEntry]
    let themeColors: ThemeColors

    private let statsVM = StatsViewModel()

    var body: some View {
        let cal = Calendar.current
        let weekdayAvg = statsVM.weekdayAverages(entries: entries, currentMax: 10)
        let bestWeekday = weekdayAvg.max(by: { $0.value < $1.value })
        let worstWeekday = weekdayAvg.min(by: { $0.value < $1.value })
        let weekdayNames = ["", "日", "月", "火", "水", "木", "金", "土"]

        NavigationStack {
            VStack(spacing: 20) {
                // Celebration
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(themeColors.accent)
                    .symbolEffect(.bounce)

                Text(String(localized: "2週間記録できました！"))
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(String(localized: "あなたのデータからわかったこと"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    if let best = bestWeekday {
                        insightRow(
                            icon: "calendar.badge.plus",
                            color: .green,
                            text: String(localized: "\(weekdayNames[best.key])曜日が最も気分が良い（\(String(format: "%.1f", best.value))）")
                        )
                    }
                    if let worst = worstWeekday {
                        insightRow(
                            icon: "calendar.badge.minus",
                            color: .orange,
                            text: String(localized: "\(weekdayNames[worst.key])曜日が最も低め（\(String(format: "%.1f", worst.value))）")
                        )
                    }

                    let avg = entries.map(\.normalizedScore).reduce(0, +) / Double(max(entries.count, 1)) * 10
                    insightRow(
                        icon: "chart.bar.fill",
                        color: themeColors.accent,
                        text: String(localized: "2週間の平均スコア: \(String(format: "%.1f", avg))")
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "統計タブでもっと見る"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(themeColors.accent)
                        )
                }
            }
            .padding(24)
        }
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
