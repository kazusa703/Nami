//
//  SettingsView.swift
//  Nami
//
//  設定画面 - テーマ切替、記録設定、リマインダー、エクスポート等
//

import StoreKit
import SwiftData
import SwiftUI
import WidgetKit

/// 設定画面
/// テーマ切り替え、スコア範囲/入力方式、リマインダー等の設定を提供する
struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.healthKitManager) private var healthKitManager
    @Environment(\.weatherManager) private var weatherManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var entries: [MoodEntry]

    /// ウィジェットから記録されたエントリ
    @Query(
        filter: #Predicate<MoodEntry> { $0.source == "widget" }
    ) private var widgetEntries: [MoodEntry]

    /// 未補完のウィジェットエントリ
    private var unenrichedWidgetEntries: [MoodEntry] {
        widgetEntries.filter { $0.needsEnrichment }
    }

    /// リマインダー通知の有効/無効
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    /// リマインダー通知の時刻
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0

    /// スコアレンジID
    @AppStorage(AppConstants.scoreRangeKey) private var scoreRangeRaw: String = ScoreRange.pos10.rawValue
    /// スコア入力方式
    @AppStorage(AppConstants.scoreInputTypeKey) private var scoreInputTypeRaw: String = ScoreInputType.buttons.rawValue
    /// ハプティクスの有効/無効
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    /// CSVエクスポートのシェアシート
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    /// CSVエクスポートエラー
    @State private var showExportErrorAlert = false
    /// データ全削除の確認アラート
    @State private var showDeleteAllAlert = false
    /// 通知権限が拒否された場合のアラート
    @State private var showPermissionDeniedAlert = false
    // 購入成功アラート

    /// クイックタグ追加のテキスト
    @State private var quickTagName = ""
    /// クイックタグ追加のカテゴリ
    @State private var quickTagCategory: EmotionTagCategory = .custom
    /// タグ追加エラーメッセージ
    @State private var tagAddError: String?
    /// 全タグ（タグセクション用）
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                List {
                    // タグセクション（最上部）
                    tagSection(colors: colors)

                    // テーマ選択セクション
                    themeSection(colors: colors)

                    // 記録設定セクション
                    recordingSettingsSection(colors: colors)

                    // リマインダーセクション
                    reminderSection()

                    // インサイト通知セクション
                    insightNotificationSection()

                    // ウィジェットセクション
                    widgetSection(colors: colors)

                    // データセクション
                    dataSection()

                    // HealthKit連携セクション
                    healthKitSection(colors: colors)

                    // 天気自動記録セクション
                    weatherSection(colors: colors)

                    // iCloud同期セクション
                    iCloudSection(colors: colors)

                    // プレミアム（広告除去）セクション
                    premiumSection(colors: colors)

                    // アプリ情報セクション
                    aboutSection(colors: colors)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - テーマセクション

    private func themeSection(colors: ThemeColors) -> some View {
        Section {
            HStack(spacing: 0) {
                ForEach(AppTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme
                    let tc = theme.colors

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            themeManager.currentTheme = theme
                        }
                        HapticManager.lightFeedback()
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                colorScheme == .dark ? tc.backgroundStartDark : tc.backgroundStartLight,
                                                colorScheme == .dark ? tc.backgroundEndDark : tc.backgroundEndLight,
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)

                                Circle()
                                    .fill(tc.accent)
                                    .frame(width: 16, height: 16)

                                if isSelected {
                                    Circle()
                                        .stroke(tc.accent, lineWidth: 3)
                                        .frame(width: 52, height: 52)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }

                            Text(theme.displayName)
                                .font(.system(.caption2, design: .rounded, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? colors.accent : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "テーマ"))
        }
    }

    // MARK: - 記録設定セクション

    /// 現在のスコアレンジ
    private var currentScoreRange: ScoreRange {
        ScoreRange(rawValue: scoreRangeRaw) ?? .pos10
    }

    /// スコア範囲変更の確認アラート
    @State private var pendingScoreRange: ScoreRange? = nil
    @State private var showRangeChangeAlert = false

    @State private var showAdvancedScoreRange = false

    private func recordingSettingsSection(colors: ThemeColors) -> some View {
        Section {
            // Compact: current range + change menu
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "スコア範囲"))
                            .font(.system(.body, design: .rounded))
                        Text(currentScoreRange.displayName)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(colors.accent)
                    }
                } icon: {
                    Image(systemName: "ruler")
                        .foregroundStyle(colors.accent)
                }

                Spacer()

                // Simple menu: recommended (1-10) prominently, others in submenu
                Menu {
                    // Recommended default
                    Button {
                        if scoreRangeRaw != ScoreRange.pos10.rawValue {
                            pendingScoreRange = .pos10
                            showRangeChangeAlert = true
                        }
                    } label: {
                        HStack {
                            Text("1〜10")
                            Text(String(localized: "おすすめ"))
                            if scoreRangeRaw == ScoreRange.pos10.rawValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    // Other ranges in submenu
                    Menu(String(localized: "その他の範囲")) {
                        Section(String(localized: "正のみ")) {
                            ForEach(ScoreRange.positiveRanges.filter { $0 != .pos10 }) { range in
                                Button {
                                    if range.rawValue != scoreRangeRaw {
                                        pendingScoreRange = range
                                        showRangeChangeAlert = true
                                    }
                                } label: {
                                    HStack {
                                        Text(range.displayName)
                                        if range.rawValue == scoreRangeRaw {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        Section(String(localized: "負あり")) {
                            ForEach(ScoreRange.negativeRanges) { range in
                                Button {
                                    if range.rawValue != scoreRangeRaw {
                                        pendingScoreRange = range
                                        showRangeChangeAlert = true
                                    }
                                } label: {
                                    HStack {
                                        Text(range.displayName)
                                        if range.rawValue == scoreRangeRaw {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Text(String(localized: "変更"))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(colors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(colors.accent.opacity(0.1)))
                }
            }

            // 入力方式Picker（ボタン数が多すぎる場合はスライダー強制のため非表示）
            if (currentScoreRange.maxValue - currentScoreRange.minValue + 1) <= 31 {
                HStack {
                    Label("入力方式", systemImage: scoreInputType.iconName)
                        .font(.system(.body, design: .rounded))

                    Spacer()

                    Picker("", selection: $scoreInputTypeRaw) {
                        ForEach(ScoreInputType.allCases) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(colors.accent)
                }
                .onChange(of: scoreInputTypeRaw) { _, _ in
                    HapticManager.lightFeedback()
                }
            } else {
                HStack {
                    Label("入力方式", systemImage: "slider.horizontal.3")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    Text("スライダー")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // ハプティクス切替
            Toggle(isOn: $hapticEnabled) {
                Label("触覚フィードバック", systemImage: "hand.tap")
                    .font(.system(.body, design: .rounded))
            }
        } header: {
            Text("記録設定")
        }
        .alert("スコア範囲を変更しますか？", isPresented: $showRangeChangeAlert) {
            Button("変更する") {
                if let newRange = pendingScoreRange {
                    withAnimation {
                        scoreRangeRaw = newRange.rawValue
                    }
                    newRange.save()
                    HapticManager.recordFeedback()
                }
                pendingScoreRange = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingScoreRange = nil
            }
        } message: {
            if let newRange = pendingScoreRange {
                Text("スコア範囲を「\(currentScoreRange.displayName)」から「\(newRange.displayName)」に変更します。\n\n・今後の記録が新しい範囲で保存されます\n・過去の記録は元の範囲のまま保持されます\n・グラフでは異なる範囲のスコアが自動スケーリングされます")
            }
        }
    }

    /// 現在の入力方式
    private var scoreInputType: ScoreInputType {
        ScoreInputType(rawValue: scoreInputTypeRaw) ?? .buttons
    }

    // MARK: - タグセクション

    @ViewBuilder
    private func tagSection(colors: ThemeColors) -> some View {
        let customTags = allTags.filter { !$0.isDefault }
        let customCount = customTags.count

        return Section {
            // Compact: management link with tag count
            NavigationLink {
                TagManagementView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tag.fill")
                        .font(.body)
                        .foregroundStyle(colors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "タグを管理"))
                            .font(.system(.body, design: .rounded))
                        Text(String(localized: "\(allTags.count)個のタグ（カスタム\(customCount)個）"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            // Inline quick add (compact single row)
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(colors.accent)

                TextField(String(localized: "新しいタグを追加..."), text: $quickTagName)
                    .font(.system(.subheadline, design: .rounded))
                    .submitLabel(.done)
                    .onSubmit { addQuickTag(colors: colors) }

                Menu {
                    ForEach([EmotionTagCategory.positive, .negative, .factor, .location, .activity, .social, .custom]) { cat in
                        Button {
                            quickTagCategory = cat
                        } label: {
                            Label(cat.displayName, systemImage: cat.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: quickTagCategory.icon)
                            .font(.caption2)
                        Text(quickTagCategory.displayName)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(colors.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(colors.accent.opacity(0.1)))
                }

                if !quickTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        addQuickTag(colors: colors)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Error message
            if let error = tagAddError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        tagAddError = nil
                    }
            }
        } header: {
            HStack {
                Text(String(localized: "タグ"))
                Spacer()
                if !premiumManager.isPremium {
                    let remaining = premiumManager.remainingCustomTags(currentCount: customCount)
                    Text(String(localized: "カスタム: \(customCount)/\(premiumManager.freeCustomTagLimit)"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(remaining > 0 ? Color.secondary : Color.orange)
                }
            }
        }
    }

    /// Quick add a tag inline
    private func addQuickTag(colors _: ThemeColors) {
        let trimmed = quickTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Duplicate check
        if allTags.contains(where: { $0.name == trimmed }) {
            tagAddError = String(localized: "同じ名前のタグが既に存在します")
            return
        }

        // Limit check
        let customCount = allTags.filter { !$0.isDefault }.count
        guard premiumManager.canCreateCustomTag(currentCount: customCount) else {
            tagAddError = String(localized: "カスタムタグの上限に達しました")
            return
        }

        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1
        let tag = EmotionTag(
            name: trimmed,
            category: quickTagCategory,
            icon: quickTagCategory == .custom ? "star.fill" : quickTagCategory.icon,
            isDefault: false,
            sortOrder: nextOrder
        )
        modelContext.insert(tag)
        quickTagName = ""
        HapticManager.lightFeedback()
    }

    // MARK: - リマインダーセクション

    private func reminderSection() -> some View {
        Section {
            Toggle(isOn: $reminderEnabled) {
                Label("リマインダー通知", systemImage: "bell")
                    .font(.system(.body, design: .rounded))
            }
            .onChange(of: reminderEnabled) { _, newValue in
                handleReminderToggle(enabled: newValue)
            }

            if reminderEnabled {
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
                .font(.system(.body, design: .rounded))
                .onChange(of: reminderHour) { _, _ in
                    NotificationManager.scheduleReminder(hour: reminderHour, minute: reminderMinute)
                }
                .onChange(of: reminderMinute) { _, _ in
                    NotificationManager.scheduleReminder(hour: reminderHour, minute: reminderMinute)
                }
            }
        } header: {
            Text("リマインダー")
        } footer: {
            if reminderEnabled {
                Text("毎日指定した時刻に気分記録のリマインダーを受け取ります。")
            }
        }
        .alert("通知が許可されていません", isPresented: $showPermissionDeniedAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("リマインダーを受け取るには、設定アプリで通知を許可してください。")
        }
    }

    // MARK: - インサイト通知セクション

    private func insightNotificationSection() -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { NotificationManager.insightNotificationsEnabled },
                set: { NotificationManager.insightNotificationsEnabled = $0 }
            )) {
                Label(String(localized: "インサイト通知"), systemImage: "lightbulb")
                    .font(.system(.body, design: .rounded))
            }

            Toggle(isOn: Binding(
                get: { NotificationManager.negativeAlertEnabled },
                set: { NotificationManager.negativeAlertEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(String(localized: "傾向アラート"), systemImage: "exclamationmark.triangle")
                        .font(.system(.body, design: .rounded))
                    Text(String(localized: "低スコアが続いた時にお知らせ"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "インサイト通知"))
        } footer: {
            Text(String(localized: "週1回の週間サマリーとパーソナルインサイトを通知で受け取ります。1日1回まで。"))
        }
    }

    /// リマインダートグルのハンドラ
    private func handleReminderToggle(enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationManager.requestPermission()
                if granted {
                    NotificationManager.scheduleReminder(hour: reminderHour, minute: reminderMinute)
                } else {
                    // 権限が拒否された場合、トグルをOFFに戻す
                    await MainActor.run {
                        reminderEnabled = false
                        showPermissionDeniedAlert = true
                    }
                }
            }
        } else {
            NotificationManager.cancelReminder()
        }
    }

    // MARK: - ウィジェットセクション

    /// Widget guide sheet flag
    @State private var showWidgetGuide = false

    private func widgetSection(colors: ThemeColors) -> some View {
        Section {
            // Manage widget entries
            NavigationLink {
                WidgetEntriesView()
            } label: {
                HStack {
                    Label(String(localized: "ウィジェット記録を管理"), systemImage: "square.grid.2x2")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    if !unenrichedWidgetEntries.isEmpty {
                        Text("\(unenrichedWidgetEntries.count)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Circle().fill(.orange))
                    }
                }
            }
        } header: {
            HStack {
                Text(String(localized: "ウィジェット"))
                Spacer()
                Button {
                    showWidgetGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text(String(localized: "ホーム画面を長押し → 左上の＋ → 「Nami」で検索して追加できます。"))
        }
        .sheet(isPresented: $showWidgetGuide) {
            WidgetGuideSheet(colors: colors)
        }
    }

    // MARK: - データセクション

    private func dataSection() -> some View {
        Section {
            Button {
                exportCSV()
            } label: {
                Label("データをエクスポート（CSV）", systemImage: "square.and.arrow.up")
                    .font(.system(.body, design: .rounded))
            }
            .disabled(entries.isEmpty)

            Button(role: .destructive) {
                showDeleteAllAlert = true
            } label: {
                Label("すべてのデータを削除", systemImage: "trash")
                    .font(.system(.body, design: .rounded))
            }
            .disabled(entries.isEmpty)
        } header: {
            Text("データ")
        }
        .alert("エクスポートに失敗しました", isPresented: $showExportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("CSVファイルの作成中にエラーが発生しました。ストレージの空き容量を確認してください。")
        }
        .alert("すべてのデータを削除しますか？", isPresented: $showDeleteAllAlert) {
            Button("削除する", role: .destructive) {
                deleteAllData()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。\(entries.count)件の記録がすべて削除されます。")
        }
    }

    /// すべてのデータを削除する
    private func deleteAllData() {
        for entry in entries {
            // 写真・ボイスメモファイルを削除
            if let photoPath = entry.photoPath {
                try? FileManager.default.removeItem(atPath: photoPath)
            }
            if let voicePath = entry.voiceMemoPath {
                try? FileManager.default.removeItem(atPath: voicePath)
            }
            modelContext.delete(entry)
        }
        HapticManager.recordFeedback()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - HealthKit連携セクション

    private func healthKitSection(colors _: ThemeColors) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { healthKitManager.isEnabled },
                set: { healthKitManager.isEnabled = $0 }
            )) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "ヘルスケア連携"))
                            .font(.system(.body, design: .rounded))
                        if healthKitManager.isEnabled && healthKitManager.isAuthorized {
                            Text(String(localized: "歩数・睡眠・心拍数を取得中"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.green)
                        } else if healthKitManager.isEnabled {
                            Text(String(localized: "権限を確認中..."))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            // Individual data type toggles
            if healthKitManager.isEnabled && healthKitManager.isAuthorized {
                Toggle(isOn: Binding(
                    get: { healthKitManager.stepsEnabled },
                    set: { healthKitManager.stepsEnabled = $0 }
                )) {
                    Label(String(localized: "歩数"), systemImage: "figure.walk")
                        .font(.system(.subheadline, design: .rounded))
                }

                Toggle(isOn: Binding(
                    get: { healthKitManager.sleepEnabled },
                    set: { healthKitManager.sleepEnabled = $0 }
                )) {
                    Label(String(localized: "睡眠"), systemImage: "bed.double.fill")
                        .font(.system(.subheadline, design: .rounded))
                }

                Toggle(isOn: Binding(
                    get: { healthKitManager.heartRateEnabled },
                    set: { healthKitManager.heartRateEnabled = $0 }
                )) {
                    Label(String(localized: "安静時心拍数"), systemImage: "heart.fill")
                        .font(.system(.subheadline, design: .rounded))
                }

                Toggle(isOn: Binding(
                    get: { healthKitManager.headphoneEnabled },
                    set: { healthKitManager.headphoneEnabled = $0 }
                )) {
                    Label(String(localized: "イヤホン使用時間"), systemImage: "headphones")
                        .font(.system(.subheadline, design: .rounded))
                }
            }

            if healthKitManager.isEnabled && !healthKitManager.isAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(String(localized: "このデバイスではヘルスケアを利用できません"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "ヘルスケア"))
        } footer: {
            Text(String(localized: "気分スコアとの相関を分析します。データはこのデバイス内でのみ処理されます。取得したくない項目はオフにできます。"))
        }
    }

    // MARK: - 天気セクション

    private func weatherSection(colors _: ThemeColors) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { weatherManager.isEnabled },
                set: { weatherManager.isEnabled = $0 }
            )) {
                HStack(spacing: 10) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "天気を自動記録"))
                            .font(.system(.body, design: .rounded))
                        if weatherManager.isEnabled && weatherManager.isAuthorized {
                            Text(String(localized: "記録時に天気を自動取得します"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.green)
                        } else if weatherManager.isEnabled {
                            Text(String(localized: "位置情報の権限を確認中..."))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            if weatherManager.isEnabled && !weatherManager.isAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash.fill")
                        .foregroundStyle(.orange)
                    Text(String(localized: "位置情報の使用を許可してください"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "天気"))
        } footer: {
            Text(String(localized: "記録時に現在地の天気と気温を自動で取得します。位置情報は天気取得にのみ使用され、保存されません。"))
        }
    }

    // MARK: - iCloud同期セクション

    private func iCloudSection(colors: ThemeColors) -> some View {
        Section {
            HStack(spacing: 12) {
                if FileManager.default.ubiquityIdentityToken != nil {
                    // iCloud接続中
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloudアカウントに接続中")
                            .font(.system(.body, design: .rounded))
                    }
                } else {
                    // iCloud未接続
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloudアカウントが未設定です")
                            .font(.system(.body, design: .rounded))
                        Text("iCloudを有効にするには、設定アプリでiCloudにサインインしてください。")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("iCloud同期")
            // Photo iCloud sync status
            if FileManager.default.ubiquityIdentityToken != nil {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.body)
                        .foregroundStyle(colors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "写真のiCloud同期"))
                            .font(.system(.body, design: .rounded))
                        Text(String(localized: "写真は自動的にiCloudにバックアップされます"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        } footer: {
            Text("気分記録とタグはiCloudに自動バックアップされます。写真もiCloud Documentsに自動同期されます。")
        }
    }

    // MARK: - Premium Section

    private func premiumSection(colors: ThemeColors) -> some View {
        Section {
            if premiumManager.isPremium {
                // Active premium status
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(colors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "プレミアム会員"))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        if let plan = premiumManager.activePlan {
                            Text(plan.displayName)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // Link to PRO tab
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "プレミアムの詳細を見る"))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Text(String(localized: "PROタブでプランを確認できます"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Restore button (always available as backup)
            Button {
                Task { await premiumManager.restore() }
            } label: {
                HStack {
                    Label(String(localized: "購入を復元"), systemImage: "arrow.clockwise")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    if premiumManager.isRestoring {
                        ProgressView()
                    }
                }
            }
            .disabled(premiumManager.isRestoring)

            // Error display (auto-dismiss after 5 seconds)
            if let error = premiumManager.errorMessage {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .task {
                        try? await Task.sleep(for: .seconds(5))
                        premiumManager.errorMessage = nil
                    }
            }
        } header: {
            Text(String(localized: "プレミアム"))
        }
    }

    // MARK: - アプリ情報セクション

    private func aboutSection(colors _: ThemeColors) -> some View {
        Section {
            HStack {
                Text("バージョン")
                    .font(.system(.body, design: .rounded))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // サポート
            Link(destination: URL(string: "https://kazusa703.github.io/nami-support/ja/support.html")!) {
                legalLinkRow(icon: "questionmark.circle", title: "サポート")
            }

            // プライバシーポリシー
            Link(destination: URL(string: "https://kazusa703.github.io/nami-support/ja/privacy.html")!) {
                legalLinkRow(icon: "hand.raised", title: "プライバシーポリシー")
            }

            // 利用規約
            Link(destination: URL(string: "https://kazusa703.github.io/nami-support/ja/terms.html")!) {
                legalLinkRow(icon: "doc.text", title: "利用規約")
            }
        } header: {
            Text("アプリ情報")
        }
    }

    /// 法的リンク行の共通ビュー
    private func legalLinkRow(icon: String, title: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(.body, design: .rounded))
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - CSVエクスポート

    /// 記録データをCSVファイルに書き出す
    private func exportCSV() {
        let header = String(localized: "日時,スコア,最小スコア,最大スコア,メモ,タグ\n")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let rows = entries.map { entry in
            let date = dateFormatter.string(from: entry.createdAt)
            let memo = (entry.memo ?? "")
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            let tags = entry.tags.joined(separator: "; ").replacingOccurrences(of: "\"", with: "\"\"")
            return "\(date),\(entry.score),\(entry.scoreRangeMin),\(entry.maxScore),\"\(memo)\",\"\(tags)\""
        }.joined(separator: "\n")

        let csv = header + rows

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("nami_export.csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            exportURL = fileURL
            showExportSheet = true
        } catch {
            showExportErrorAlert = true
        }
    }
}

/// UIActivityViewControllerのSwiftUIラッパー
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
