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
    @Environment(\.premiumManager) private var premiumManager

    @State private var viewModel = MoodViewModel()
    @State private var interstitialManager = InterstitialAdManager()
    @State private var showAdRemoveHint = false
    @State private var showPaywall = false
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    /// ウィジェットから記録されたエントリ
    @Query(
        filter: #Predicate<MoodEntry> { $0.source == "widget" },
        sort: \MoodEntry.createdAt,
        order: .reverse
    ) private var widgetEntries: [MoodEntry]

    /// 未補完のウィジェットエントリ（メモ・タグ・写真・ボイスメモが未追加）
    private var unenrichedWidgetEntries: [MoodEntry] {
        widgetEntries.filter { $0.needsEnrichment }
    }

    /// 設定から読み取るスコア範囲上限
    @AppStorage(AppConstants.scoreRangeMaxKey) private var scoreRangeMax: Int = 10
    /// 設定から読み取るスコア範囲下限
    @AppStorage(AppConstants.scoreRangeMinKey) private var scoreRangeMin: Int = 1
    /// 設定から読み取る入力方式
    @AppStorage(AppConstants.scoreInputTypeKey) private var scoreInputTypeRaw: String = ScoreInputType.buttons.rawValue

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
                    // ウィジェット記録バナー
                    if !unenrichedWidgetEntries.isEmpty {
                        widgetEntryBanner(count: unenrichedWidgetEntries.count, colors: colors)
                    }

                    // Today's tip
                    if entries.count >= 20 {
                        todayTipView(colors: colors)
                    }

                    VStack(spacing: 32) {
                        Spacer()

                        // タイトル
                        VStack(spacing: 8) {
                            Text("今の気分は？")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(colors.accent)

                            Text("\(scoreRangeMin)〜\(scoreRangeMax)でタップして記録")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        // 記録完了アニメーション
                        if viewModel.showRecordedAnimation {
                            VStack(spacing: 4) {
                                Text("\(viewModel.recordedScore)")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundStyle(colors.color(for: viewModel.recordedScore, maxScore: viewModel.recordedMaxScore))
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
                            maxScore: scoreRangeMax,
                            minScore: scoreRangeMin,
                            themeColors: colors
                        ) { score in
                            viewModel.recordMood(score: score, maxScore: scoreRangeMax, minScore: scoreRangeMin, context: modelContext)
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

                    // Post-interstitial subtle hint
                    if showAdRemoveHint {
                        Button {
                            showAdRemoveHint = false
                            showPaywall = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("広告を非表示にする")
                                    .font(.system(.caption2, design: .rounded))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Capsule().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 4)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
        }
        .alert("記録エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.showRecordingSheet, onDismiss: {
            viewModel.isRecording = false
            viewModel.lastRecordedEntry = nil

            // Show interstitial ad every 4 recordings (free users only)
            if !premiumManager.isPremium {
                interstitialManager.recordCompleted()

                // Show subtle hint after interstitial was displayed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if interstitialManager.didShowAd {
                        withAnimation(.easeInOut(duration: 0.3)) { showAdRemoveHint = true }
                        // Auto dismiss after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation(.easeInOut(duration: 0.3)) { showAdRemoveHint = false }
                        }
                    }
                }
            }
        }) {
            RecordingSheet(
                score: viewModel.recordedScore,
                maxScore: viewModel.recordedMaxScore,
                minScore: viewModel.recordedMinScore,
                themeColors: themeManager.colors,
                onSave: { memo, photo, voiceMemoURL, tags in
                    viewModel.saveRecording(memo: memo, photo: photo, voiceMemoURL: voiceMemoURL, tags: tags, context: modelContext)
                },
                onSkip: {
                    viewModel.skipRecording()
                }
            )
        }
        .task {
            interstitialManager.loadAd()
        }
    }

    // MARK: - ウィジェットエントリバナー

    private func widgetEntryBanner(count: Int, colors: ThemeColors) -> some View {
        NavigationLink {
            WidgetEntriesView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ウィジェットから\(count)件の記録")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("タップしてメモやタグを追加")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
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

    // MARK: - 今日のヒント

    @ViewBuilder
    private func todayTipView(colors: ThemeColors) -> some View {
        let tips = InsightEngine.generateDailyTips(
            from: entries, currentMax: scoreRangeMax, currentMin: scoreRangeMin
        )
        if let tip = tips.first {
            HStack(spacing: 8) {
                Image(systemName: tip.icon)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(colors.accent)
                    .frame(width: 16)
                Text(tip.text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal)
            .padding(.top, 4)
        }
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
                        .foregroundStyle(colors.color(for: entry.score, maxScore: entry.maxScore))
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

                // ウィジェット記録アイコン
                if entry.source == "widget" {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
}

#Preview {
    MainView()
        .modelContainer(for: [MoodEntry.self, EmotionTag.self, TagCategory.self], inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
