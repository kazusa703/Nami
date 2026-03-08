//
//  SettingsView.swift
//  Nami
//
//  設定画面 - テーマ切替、記録設定、リマインダー、エクスポート等
//

import CoreLocation
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

    /// スコア範囲上限
    @AppStorage(AppConstants.scoreRangeMaxKey) private var scoreRangeMax: Int = 10
    /// スコア範囲下限
    @AppStorage(AppConstants.scoreRangeMinKey) private var scoreRangeMin: Int = 1
    /// スコア入力方式
    @AppStorage(AppConstants.scoreInputTypeKey) private var scoreInputTypeRaw: String = ScoreInputType.buttons.rawValue
    /// ハプティクスの有効/無効
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    /// 天気自動記録の有効/無効
    @AppStorage("weatherTrackingEnabled") private var weatherTrackingEnabled = false
    /// HealthKit連携の有効/無効
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    /// HealthKit権限拒否アラート
    @State private var showHealthKitDeniedAlert = false
    @State private var premiumBenefitsExpanded = false
    @Environment(\.healthKitManager) private var healthKitManager

    /// CSVエクスポートのシェアシート
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    /// CSVエクスポートエラー
    @State private var showExportErrorAlert = false
    /// データ全削除の確認アラート
    @State private var showDeleteAllAlert = false
    /// 通知権限が拒否された場合のアラート
    @State private var showPermissionDeniedAlert = false
    /// 購入成功アラート
    @State private var showPurchaseSuccessAlert = false
    /// ペイウォールシート
    @State private var showPaywall = false

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                List {
                    // プレミアムセクション（一番上）
                    premiumSection(colors: colors)

                    // テーマ選択セクション
                    themeSection(colors: colors)

                    // 記録設定セクション
                    recordingSettingsSection(colors: colors)

                    // 感情タグセクション
                    tagSection(colors: colors)

                    // 天気設定セクション
                    weatherSection(colors: colors)

                    // ヘルスケア設定セクション
                    healthKitSection(colors: colors)

                    // リマインダーセクション
                    reminderSection()

                    // ウィジェットセクション
                    widgetSection(colors: colors)

                    // データセクション
                    dataSection()

                    // iCloud同期セクション
                    iCloudSection(colors: colors)

                    // アプリ情報セクション
                    aboutSection(colors: colors)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
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
                                        colorScheme == .dark ? themeColors.backgroundEndDark : themeColors.backgroundEndLight,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .overlay(
                                // アクセントカラーサンプル（小さな丸）
                                Circle()
                                    .fill(themeColors.accent)
                                    .frame(width: 18, height: 18)
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
                                .foregroundStyle(colors.accent)
                                .font(.title3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("テーマ")
        }
    }

    // MARK: - 記録設定セクション

    /// スコア範囲変更の確認アラート
    @State private var pendingScoreRange: ScoreRange? = nil
    @State private var showRangeChangeAlert = false
    /// スコア範囲の最終変更日（月1回制限用）
    @AppStorage(AppConstants.lastScoreRangeChangeDateKey) private var lastScoreRangeChangeDateInterval: Double = 0

    /// スコア範囲変更可能かどうか（前回変更から30日以上経過）
    private var canChangeScoreRange: Bool {
        guard lastScoreRangeChangeDateInterval > 0 else { return true } // 初回は許可
        let lastDate = Date(timeIntervalSince1970: lastScoreRangeChangeDateInterval)
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSince >= 30
    }

    /// 次にスコア範囲変更可能になるまでの残り日数
    private var daysUntilScoreRangeChange: Int {
        guard lastScoreRangeChangeDateInterval > 0 else { return 0 }
        let lastDate = Date(timeIntervalSince1970: lastScoreRangeChangeDateInterval)
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return max(30 - daysSince, 0)
    }

    private func recordingSettingsSection(colors: ThemeColors) -> some View {
        Section {
            // 現在のスコア範囲を目立つカードで表示
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // 現在の範囲を大きく表示
                    VStack(spacing: 2) {
                        Text("\(scoreRangeMin) 〜 \(scoreRangeMax)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(colors.accent)
                        Text("現在のスコア範囲")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colors.accent.opacity(0.08))
                    )

                    // 範囲選択メニュー（月1回のみ変更可能）
                    if canChangeScoreRange {
                        Menu {
                            ForEach(ScoreRange.allCases) { range in
                                let isCurrent = range.minScore == scoreRangeMin && range.maxScore == scoreRangeMax
                                Button {
                                    if !isCurrent {
                                        pendingScoreRange = range
                                        showRangeChangeAlert = true
                                    }
                                } label: {
                                    HStack {
                                        Text(range.displayName)
                                        Text(range.description)
                                        if isCurrent {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .disabled(isCurrent)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                Text("変更")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                            }
                            .foregroundStyle(colors.accent)
                            .frame(width: 60, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colors.accent.opacity(0.08))
                            )
                        }
                    } else {
                        // 変更不可（クールダウン中）
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                            Text("あと\(daysUntilScoreRangeChange)日")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5).opacity(0.5))
                        )
                    }
                }

                // 注意書き
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(.caption))
                        .foregroundStyle(.orange)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("スコア範囲の変更は今後の記録に適用されます。過去の記録は元の範囲のまま保持され、グラフ上では自動的にスケーリングされます。")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if canChangeScoreRange {
                            Text("変更後30日間は再変更できません。慎重にお選びください。")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("スコア範囲は月に1回のみ変更できます。あと\(daysUntilScoreRangeChange)日お待ちください。")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // 入力方式Picker（maxScore > 30 の場合はスライダー強制のため非表示）
            if scoreRangeMax <= 30 {
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
        } footer: {
            if scoreRangeMax > 10 {
                Text("範囲変更後のグラフには、変更地点に縦線が表示されます。")
            }
        }
        .alert("スコア範囲を変更しますか？", isPresented: $showRangeChangeAlert) {
            Button("変更する") {
                if let newRange = pendingScoreRange {
                    withAnimation {
                        scoreRangeMin = newRange.minScore
                        scoreRangeMax = newRange.maxScore
                    }
                    AppConstants.sharedUserDefaults.set(newRange.maxScore, forKey: AppConstants.scoreRangeMaxKey)
                    AppConstants.sharedUserDefaults.set(newRange.minScore, forKey: AppConstants.scoreRangeMinKey)
                    // 変更日を記録（月1回制限用）
                    lastScoreRangeChangeDateInterval = Date().timeIntervalSince1970
                    HapticManager.recordFeedback()
                }
                pendingScoreRange = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingScoreRange = nil
            }
        } message: {
            if let newRange = pendingScoreRange {
                Text("スコア範囲を「\(scoreRangeMin)〜\(scoreRangeMax)」から「\(newRange.minScore)〜\(newRange.maxScore)」に変更します。\n\n・今後の記録が新しい範囲で保存されます\n・過去の記録は元の範囲のまま保持されます\n・グラフでは異なる範囲のスコアが自動スケーリングされます\n・変更地点にグラフ上で縦線が表示されます")
            }
        }
    }

    /// 現在の入力方式
    private var scoreInputType: ScoreInputType {
        ScoreInputType(rawValue: scoreInputTypeRaw) ?? .buttons
    }

    // MARK: - 感情タグセクション

    private func tagSection(colors _: ThemeColors) -> some View {
        Section {
            NavigationLink {
                TagManagementView()
            } label: {
                Label("タグを管理", systemImage: "tag.fill")
                    .font(.system(.body, design: .rounded))
            }
        } header: {
            Text("感情タグ")
        } footer: {
            Text("記録時に感情や要因のタグを付けて、パターンを分析できます。")
        }
    }

    // MARK: - 天気セクション

    @State private var weatherManager = WeatherManager()

    private func weatherSection(colors _: ThemeColors) -> some View {
        Section {
            if premiumManager.isPremium {
                Toggle(isOn: $weatherTrackingEnabled) {
                    Label("天気を自動記録", systemImage: "cloud.sun.fill")
                        .font(.system(.body, design: .rounded))
                }
                .onChange(of: weatherTrackingEnabled) { _, newValue in
                    if newValue {
                        let status = weatherManager.authorizationStatus
                        if status == .notDetermined {
                            weatherManager.requestLocationPermission()
                        }
                    }
                }

                // 位置情報が未許可の場合
                if weatherTrackingEnabled {
                    let status = weatherManager.authorizationStatus
                    if status == .denied || status == .restricted {
                        HStack(spacing: 10) {
                            Image(systemName: "location.slash.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("位置情報が許可されていません")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                Text("天気データの取得には位置情報が必要です")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Label("天気を自動記録", systemImage: "cloud.sun.fill")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    Text("PRO")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange))
                        .foregroundStyle(.white)
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("天気")
        } footer: {
            Text("有効にすると、記録時に現在地の天気・気温・気圧を自動で取得します。統計画面で天気と気分の相関を分析できます。")
        }
    }

    // MARK: - ヘルスケアセクション

    private func healthKitSection(colors _: ThemeColors) -> some View {
        Section {
            Toggle(isOn: $healthKitEnabled) {
                Label("ヘルスケア連携", systemImage: "heart.text.square")
                    .font(.system(.body, design: .rounded))
            }
            .onChange(of: healthKitEnabled) { _, newValue in
                if newValue {
                    Task {
                        let granted = await healthKitManager.requestAuthorization()
                        if !granted {
                            await MainActor.run {
                                healthKitEnabled = false
                                showHealthKitDeniedAlert = true
                            }
                        }
                    }
                }
            }
        } header: {
            Text("ヘルスケア")
        } footer: {
            Text("歩数・睡眠・運動量と気分の関連を統計画面で分析できます。データは外部に送信されません。")
        }
        .alert("ヘルスケアへのアクセスが許可されていません", isPresented: $showHealthKitDeniedAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ヘルスケアデータにアクセスするには、設定 > ヘルスケア > データアクセスとデバイス > Nami で許可してください。")
        }
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

    private func widgetSection(colors: ThemeColors) -> some View {
        Section {
            // ウィジェット記録を管理
            NavigationLink {
                WidgetEntriesView()
            } label: {
                HStack {
                    Label("ウィジェット記録を管理", systemImage: "square.grid.2x2")
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

            // ホーム画面ウィジェット
            VStack(alignment: .leading, spacing: 10) {
                widgetRow(
                    icon: "square.grid.2x2",
                    iconColor: colors.accent,
                    title: "小",
                    description: "最新スコア + スコアボタンで直接記録"
                )
                widgetRow(
                    icon: "rectangle",
                    iconColor: colors.accent,
                    title: "中",
                    description: "トレンド・バーチャート + スコアボタンで直接記録"
                )
                widgetRow(
                    icon: "rectangle.portrait",
                    iconColor: colors.accent,
                    title: "大",
                    description: "統計カード・チャート + スコアボタンで直接記録"
                )
            }

            Divider()

            // ロック画面ウィジェット
            VStack(alignment: .leading, spacing: 10) {
                Text("ロック画面")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)

                widgetRow(
                    icon: "circle",
                    iconColor: colors.graphLine,
                    title: "円形",
                    description: "スコアゲージ"
                )
                widgetRow(
                    icon: "rectangle.fill",
                    iconColor: colors.graphLine,
                    title: "長方形",
                    description: "スコア・ストリーク・ミニグラフ"
                )
                widgetRow(
                    icon: "textformat",
                    iconColor: colors.graphLine,
                    title: "インライン",
                    description: "スコアとストリークをテキスト表示"
                )
            }
        } header: {
            Text("ウィジェット")
        } footer: {
            Text("ホーム画面を長押し → 左上の＋ → 「Nami」で検索して追加できます。アプリを開かずに記録できます。")
        }
    }

    /// ウィジェット説明の1行
    private func widgetRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Text(description)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
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
                MediaManager.deleteMedia(at: photoPath)
            }
            if let voicePath = entry.voiceMemoPath {
                MediaManager.deleteMedia(at: voicePath)
            }
            modelContext.delete(entry)
        }
        HapticManager.recordFeedback()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - iCloud同期セクション

    private func iCloudSection(colors _: ThemeColors) -> some View {
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
        } footer: {
            Text("気分記録と感情タグはiCloudに自動バックアップされます。写真とボイスメモはこのデバイスにのみ保存されます。")
        }
    }

    // MARK: - プレミアムセクション

    private func premiumSection(colors: ThemeColors) -> some View {
        Section {
            if premiumManager.isPremium {
                premiumActiveView(colors: colors)
            } else {
                // Premium upsell card — gradient background, visually distinct from other sections
                Button {
                    showPaywall = true
                } label: {
                    VStack(spacing: 16) {
                        // Top: icon + title + tagline
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(.white.opacity(0.2))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nami PRO")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("波をもっと深く読む")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        // Benefit chips — compact 2x2 grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ], spacing: 8) {
                            premiumChip(icon: "eye.slash", text: "広告なし")
                            premiumChip(icon: "chart.bar.xaxis", text: "高度な統計")
                            premiumChip(icon: "tag", text: "タグ無制限")
                            premiumChip(icon: "cloud.sun", text: "天気連携")
                        }

                        // Benefits disclosure
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                premiumBenefitsExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .rotationEffect(.degrees(premiumBenefitsExpanded ? 90 : 0))
                                Text("PROでできること")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                Spacer()
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }

                        if premiumBenefitsExpanded {
                            VStack(alignment: .leading, spacing: 10) {
                                premiumBenefitDetail(
                                    icon: "eye.slash",
                                    text: "バナー・全画面広告が消え、記録だけに集中できる"
                                )
                                premiumBenefitDetail(
                                    icon: "tag",
                                    text: "タグを20個以上、無制限に作成。自分だけの感情を細かく分類"
                                )
                                premiumBenefitDetail(
                                    icon: "cloud.sun",
                                    text: "天気・気温・気圧を自動記録し、体調との相関を発見"
                                )
                                premiumBenefitDetail(
                                    icon: "chart.bar.xaxis",
                                    text: "どのタグが気分にどれだけ影響しているか数値で確認"
                                )
                                premiumBenefitDetail(
                                    icon: "arrow.triangle.branch",
                                    text: "タグの組み合わせ効果や連鎖パターンを可視化"
                                )
                                premiumBenefitDetail(
                                    icon: "arrow.uturn.up",
                                    text: "気分が落ちた後、何がきっかけで回復したか特定"
                                )
                                premiumBenefitDetail(
                                    icon: "doc.text",
                                    text: "月間レポートで1ヶ月の気分の波を振り返り"
                                )
                                premiumBenefitDetail(
                                    icon: "exclamationmark.triangle",
                                    text: "行動と気分のズレを検知し、無理をしていないかチェック"
                                )
                            }
                            .padding(.vertical, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // CTA
                        Text("すべての機能を解放")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(colors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [colors.accent, colors.accent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // Error message
                if let error = premiumManager.errorMessage {
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.red)
                        .task {
                            try? await Task.sleep(for: .seconds(5))
                            premiumManager.errorMessage = nil
                        }
                }

                // Product fetch retry
                if premiumManager.productFetchFailed {
                    Button {
                        Task { await premiumManager.fetchProducts() }
                    } label: {
                        Label("商品情報を再取得", systemImage: "arrow.clockwise")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }

                // Restore — unobtrusive text link
                Button {
                    Task { await premiumManager.restore() }
                } label: {
                    HStack(spacing: 4) {
                        if premiumManager.isRestoring {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("購入を復元")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(premiumManager.isRestoring || premiumManager.isPurchasing)
                .listRowBackground(Color.clear)
            }
        } header: {
            if !premiumManager.isPremium {
                // No header for free users — the gradient card speaks for itself
            } else {
                Text("プレミアム")
            }
        } footer: {
            if !premiumManager.isPremium {
                VStack(alignment: .center, spacing: 4) {
                    Text("[利用規約](https://kazusa703.github.io/nami-support/ja/terms.html) ・ [プライバシーポリシー](https://kazusa703.github.io/nami-support/ja/privacy.html)")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
        }
        .alert("購入完了", isPresented: $showPurchaseSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("プレミアムへのアップグレードありがとうございます！")
        }
        .onChange(of: premiumManager.showPurchaseSuccess) { _, newValue in
            if newValue {
                showPurchaseSuccessAlert = true
                premiumManager.showPurchaseSuccess = false
            }
        }
    }

    /// Compact benefit chip for premium card
    private func premiumChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.15))
        )
    }

    private func premiumBenefitDetail(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    /// プレミアム有効時の表示 — status card with clean design
    @ViewBuilder
    private func premiumActiveView(colors: ThemeColors) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(colors.accent.gradient)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Nami PRO")
                            .font(.system(.body, design: .rounded, weight: .bold))
                        Text("有効")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.green))
                    }

                    if let planType = premiumManager.currentPlanType {
                        switch planType {
                        case .monthly:
                            if let exp = premiumManager.subscriptionExpirationDate {
                                Text("月額プラン ・ 次回更新: \(exp, format: .dateTime.month().day())")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("月額プラン")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        case .yearly:
                            if let exp = premiumManager.subscriptionExpirationDate {
                                Text("年額プラン ・ 次回更新: \(exp, format: .dateTime.year().month().day())")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("年額プラン")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        case .lifetime:
                            Text("買い切りプラン ・ 永久利用")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
        }

        // Subscription management link (not for lifetime)
        if premiumManager.currentPlanType != .lifetime {
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Label("サブスクリプションを管理", systemImage: "gear")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
        let header = String(localized: "日時,スコア,最大スコア,メモ,タグ\n")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let rows = entries.map { entry in
            let date = dateFormatter.string(from: entry.createdAt)
            let memo = csvEscape(entry.memo ?? "")
            let tags = csvEscape(entry.tags.joined(separator: "; "))
            return "\(date),\(entry.score),\(entry.maxScore),\(memo),\(tags)"
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

    /// Escape a field for RFC 4180 CSV (wrap in quotes if it contains comma, quote, or newline)
    private func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
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
