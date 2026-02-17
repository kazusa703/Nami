//
//  SettingsView.swift
//  Nami
//
//  設定画面 - テーマ切替、記録設定、リマインダー、エクスポート等
//

import SwiftUI
import SwiftData
import StoreKit
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
    /// 購入成功アラート
    @State private var showPurchaseSuccessAlert = false

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                List {
                    // テーマ選択セクション
                    themeSection(colors: colors)

                    // 記録設定セクション
                    recordingSettingsSection(colors: colors)

                    // 感情タグセクション
                    tagSection(colors: colors)

                    // リマインダーセクション
                    reminderSection()

                    // ウィジェットセクション
                    widgetSection(colors: colors)

                    // データセクション
                    dataSection()

                    // iCloud同期セクション
                    iCloudSection(colors: colors)

                    // プレミアム（広告除去）セクション
                    premiumSection(colors: colors)

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

    @ViewBuilder
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
                                        colorScheme == .dark ? themeColors.backgroundEndDark : themeColors.backgroundEndLight
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
    @State private var pendingScoreRange: Int? = nil
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

    @ViewBuilder
    private func recordingSettingsSection(colors: ThemeColors) -> some View {
        Section {
            // 現在のスコア範囲を目立つカードで表示
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // 現在の範囲を大きく表示
                    VStack(spacing: 2) {
                        Text("1 〜 \(scoreRangeMax)")
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
                                Button {
                                    if range.rawValue != scoreRangeMax {
                                        pendingScoreRange = range.rawValue
                                        showRangeChangeAlert = true
                                    }
                                } label: {
                                    HStack {
                                        Text(range.displayName)
                                        Text(range.description)
                                        if range.rawValue == scoreRangeMax {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .disabled(range.rawValue == scoreRangeMax)
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
                        if !canChangeScoreRange {
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
                Text("範囲変更後のグラフには、変更地点に赤い縦線が表示されます。")
            }
        }
        .alert("スコア範囲を変更しますか？", isPresented: $showRangeChangeAlert) {
            Button("変更する") {
                if let newRange = pendingScoreRange {
                    withAnimation {
                        scoreRangeMax = newRange
                    }
                    AppConstants.sharedUserDefaults.set(newRange, forKey: AppConstants.scoreRangeMaxKey)
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
                Text("スコア範囲を「1〜\(scoreRangeMax)」から「1〜\(newRange)」に変更します。\n\n・今後の記録が新しい範囲で保存されます\n・過去の記録は元の範囲のまま保持されます\n・グラフでは異なる範囲のスコアが自動スケーリングされます\n・変更地点にグラフ上で赤い縦線が表示されます")
            }
        }
    }

    /// 現在の入力方式
    private var scoreInputType: ScoreInputType {
        ScoreInputType(rawValue: scoreInputTypeRaw) ?? .buttons
    }

    // MARK: - 感情タグセクション

    @ViewBuilder
    private func tagSection(colors: ThemeColors) -> some View {
        Section {
            NavigationLink {
                TagManagementView()
            } label: {
                Label("感情タグを管理", systemImage: "tag.fill")
                    .font(.system(.body, design: .rounded))
            }
        } header: {
            Text("感情タグ")
        } footer: {
            Text("記録時に感情や要因のタグを付けて、パターンを分析できます。")
        }
    }

    // MARK: - リマインダーセクション

    @ViewBuilder
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

    @ViewBuilder
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

    @ViewBuilder
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

    // MARK: - iCloud同期セクション

    @ViewBuilder
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
        } footer: {
            Text("気分記録と感情タグはiCloudに自動バックアップされます。写真とボイスメモはこのデバイスにのみ保存されます。")
        }
    }

    // MARK: - プレミアムセクション（広告除去）

    @ViewBuilder
    private func premiumSection(colors: ThemeColors) -> some View {
        Section {
            if premiumManager.isPremium {
                // 購入済み表示
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(colors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("プレミアム")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Text("広告は非表示になっています")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // 購入ボタン
                premiumPurchaseButton(colors: colors)

                // 復元ボタン
                Button {
                    Task { await premiumManager.restore() }
                } label: {
                    HStack {
                        Label("購入を復元", systemImage: "arrow.clockwise")
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        if premiumManager.isRestoring {
                            ProgressView()
                        }
                    }
                }
                .disabled(premiumManager.isRestoring || premiumManager.isPurchasing)

                // 商品取得失敗時のリトライ
                if premiumManager.productFetchFailed {
                    Button {
                        Task { await premiumManager.fetchProduct() }
                    } label: {
                        Label("商品情報を再取得", systemImage: "arrow.clockwise")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
            }

            // エラー表示（5秒後に自動消去）
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
            Text("プレミアム")
        } footer: {
            if !premiumManager.isPremium {
                VStack(alignment: .leading, spacing: 4) {
                    Text("購入すると、グラフ画面と統計画面の広告が永久に非表示になります。機能制限はありません。")
                    Text("購入はApple IDに紐付けられ、[利用規約](https://kazusa703.github.io/nami-support/ja/terms.html)と[プライバシーポリシー](https://kazusa703.github.io/nami-support/ja/privacy.html)が適用されます。")
                }
            }
        }
        .alert("購入完了", isPresented: $showPurchaseSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("プレミアムへのアップグレードありがとうございます！広告は非表示になりました。")
        }
        .onChange(of: premiumManager.showPurchaseSuccess) { _, newValue in
            if newValue {
                showPurchaseSuccessAlert = true
                premiumManager.showPurchaseSuccess = false
            }
        }
    }

    /// 購入ボタン
    @ViewBuilder
    private func premiumPurchaseButton(colors: ThemeColors) -> some View {
        Button {
            Task { await premiumManager.purchase() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("広告を除去")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    if let product = premiumManager.product {
                        Text(product.displayPrice)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if premiumManager.isPurchasing {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(premiumManager.isPurchasing || premiumManager.product == nil)
    }

    // MARK: - アプリ情報セクション

    @ViewBuilder
    private func aboutSection(colors: ThemeColors) -> some View {
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
            let memo = entry.memo?.replacingOccurrences(of: ",", with: "、") ?? ""
            let tags = entry.tags.joined(separator: "; ")
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
}

/// UIActivityViewControllerのSwiftUIラッパー
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
