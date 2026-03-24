//
//  NamiApp.swift
//  Nami
//
//  アプリのエントリポイント
//

import SwiftData
import SwiftUI
import UIKit
import WidgetKit

// MARK: - 画面回転制御

/// フルスクリーン表示時のみランドスケープを許可するためのAppDelegate
class NamiAppDelegate: NSObject, UIApplicationDelegate {
    /// trueの間はランドスケープを許可する（フルスクリーンチャート用）
    static var allowLandscape = false

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        if NamiAppDelegate.allowLandscape {
            return [.portrait, .landscapeLeft, .landscapeRight]
        }
        return .portrait
    }
}

@main
struct NamiApp: App {
    @UIApplicationDelegateAdaptor(NamiAppDelegate.self) var appDelegate
    /// テーママネージャー（アプリ全体で共有）
    @State private var themeManager = ThemeManager()
    /// プレミアム状態マネージャー
    @State private var premiumManager = PremiumManager()
    /// HealthKitマネージャー
    @State private var healthKitManager = HealthKitManager()
    /// 天気マネージャー
    @State private var weatherManager = WeatherManager()

    /// リマインダーの有効/無効（AppStorageと同期）
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0

    /// SwiftDataのモデルコンテナ（App Group共有パス）
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MoodEntry.self,
            EmotionTag.self,
        ])

        // App Groupの共有コンテナが利用可能か確認
        if let containerURL = AppConstants.sharedContainerURL {
            // 旧ストアからApp Groupへの移行を実行
            Self.migrateStoreIfNeeded()

            let storeURL = containerURL.appendingPathComponent("Nami.store")

            // ストアの親ディレクトリを確保
            let fileManager = FileManager.default
            let parentDir = storeURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            let config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .automatic // iCloud同期を有効化
            )

            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                print("App Group共有コンテナでのModelContainer作成に失敗: \(error)")
                // App Groupは利用可能だがストア作成に失敗 → デフォルトにフォールバック
            }
        } else {
            print("App Groupコンテナが利用できません。Xcode → Signing & Capabilities → App Groups で group.com.imai.Nami を有効化してください。")
        }

        // フォールバック: デフォルトパスを使用（App Group未設定またはストア作成失敗時）
        do {
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
        } catch {
            fatalError("ModelContainerの作成に失敗しました: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.themeManager, themeManager)
                .environment(\.premiumManager, premiumManager)
                .environment(\.healthKitManager, healthKitManager)
                .environment(\.weatherManager, weatherManager)
                .task {
                    // デフォルトタグの初期化
                    DefaultTags.seedIfNeeded(context: sharedModelContainer.mainContext)
                    DefaultTags.seedV2IfNeeded(context: sharedModelContainer.mainContext)

                    // Import pending widget records from UserDefaults queue
                    Self.importPendingWidgetRecords(context: sharedModelContainer.mainContext)

                    // WatchConnectivityの初期化
                    WatchConnectivityManager.shared.modelContainer = sharedModelContainer
                    WatchConnectivityManager.shared.activate()

                    // HealthKit連携の初期化
                    if healthKitManager.isEnabled {
                        await healthKitManager.checkAuthorizationStatus()
                    }

                    // iCloud写真同期（バックグラウンド実行）
                    if MediaManager.isICloudAvailable {
                        Task.detached(priority: .background) {
                            await MediaManager.syncPhotosFromiCloud()
                            await MediaManager.syncPhotosToiCloud()
                        }
                    }

                    // 週間サマリー通知のスケジュール（毎週月曜9時）
                    Self.scheduleWeeklySummaryIfNeeded(context: sharedModelContainer.mainContext)

                    // ネガティブ傾向検知（3日連続低スコア → 通知）
                    Self.checkNegativeTrend(context: sharedModelContainer.mainContext)

                    // アプリ起動時にリマインダーが有効ならスケジュールを再設定
                    if reminderEnabled {
                        let authorized = await NotificationManager.isAuthorized()
                        if authorized {
                            NotificationManager.scheduleReminder(hour: reminderHour, minute: reminderMinute)
                        } else {
                            // 権限が取り消されていた場合、リマインダーを無効化
                            reminderEnabled = false
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Widget Record Import

    /// Import mood records queued by the widget via App Group UserDefaults
    private static func importPendingWidgetRecords(context: ModelContext) {
        let defaults = AppConstants.sharedUserDefaults
        let pending = defaults.pendingWidgetRecords
        guard !pending.isEmpty else { return }

        for record in pending {
            let entry = MoodEntry(
                score: record.score,
                maxScore: record.maxScore,
                scoreRangeMin: record.scoreRangeMin,
                source: "widget",
                createdAt: record.createdAt
            )
            entry.id = record.id
            context.insert(entry)
        }

        try? context.save()

        // Clear the queue after successful import
        defaults.pendingWidgetRecords = []
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Weekly Summary Notification

    /// Schedule weekly summary notification with actual stats data
    private static func scheduleWeeklySummaryIfNeeded(context: ModelContext) {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: .now),
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return }

        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { entry in
                entry.createdAt >= weekStart && entry.createdAt < weekEnd
            }
        )

        guard let lastWeekEntries = try? context.fetch(descriptor),
              !lastWeekEntries.isEmpty else { return }

        // Calculate average
        let avg = lastWeekEntries.map { Double($0.score) }.reduce(0, +) / Double(lastWeekEntries.count)

        // Find best day
        let grouped = Dictionary(grouping: lastWeekEntries) { calendar.startOfDay(for: $0.createdAt) }
        let bestDay = grouped.max { a, b in
            let aAvg = a.value.map { Double($0.score) }.reduce(0, +) / Double(a.value.count)
            let bAvg = b.value.map { Double($0.score) }.reduce(0, +) / Double(b.value.count)
            return aAvg < bAvg
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E曜日"
        let bestDayName = bestDay.map { formatter.string(from: $0.key) } ?? ""

        NotificationManager.scheduleWeeklySummary(
            averageScore: avg,
            bestDay: bestDayName,
            currentMax: 10
        )
    }

    // MARK: - Negative Trend Detection

    /// Check if user has 3+ consecutive days below personal average and notify
    private static func checkNegativeTrend(context: ModelContext) {
        guard NotificationManager.negativeAlertEnabled else { return }

        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) else { return }

        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.createdAt >= weekAgo },
            sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
        )
        guard let recentEntries = try? context.fetch(descriptor),
              recentEntries.count >= 5 else { return }

        // Calculate personal average (all time, approximated from recent)
        let allAvg = recentEntries.map(\.normalizedScore).reduce(0, +) / Double(recentEntries.count)

        // Check consecutive days below average
        var consecutiveLowDays = 0
        var totalLowScore = 0.0
        var currentDay = calendar.startOfDay(for: .now)

        for _ in 0 ..< 7 {
            let dayEntries = recentEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: currentDay) }
            if dayEntries.isEmpty { break }
            let dayAvg = dayEntries.map(\.normalizedScore).reduce(0, +) / Double(dayEntries.count)
            if dayAvg < allAvg - 0.05 {
                consecutiveLowDays += 1
                totalLowScore += dayAvg
            } else {
                break
            }
            currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay)!
        }

        if consecutiveLowDays >= 3 {
            let avgScore = (totalLowScore / Double(consecutiveLowDays)) * 10 // rough scale to 10
            NotificationManager.scheduleNegativeAlert(averageScore: avgScore, days: consecutiveLowDays)
        }
    }

    // MARK: - データ移行

    /// 旧デフォルトストアからApp Group共有コンテナへSwiftDataファイルを移行する
    /// 移行済みの場合はスキップ。App Groupが利用可能な場合のみ呼ばれる前提
    private static func migrateStoreIfNeeded() {
        let fileManager = FileManager.default
        let migrationKey = "hasmigratedToAppGroup"

        // 既に移行済みならスキップ
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }

        // 旧ストアのパス（SwiftDataのデフォルト保存先）
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let oldStoreURL = appSupportDir.appendingPathComponent("default.store")

        // 旧ストアが存在しなければ移行不要
        guard fileManager.fileExists(atPath: oldStoreURL.path) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // App Group共有コンテナの新ストアURL
        guard let newStoreURL = AppConstants.sharedStoreURL else {
            return
        }

        // 新ストアが既に存在する場合は移行済みとみなす
        if fileManager.fileExists(atPath: newStoreURL.path) {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // 親ディレクトリを確保
        let parentDir = newStoreURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // SwiftData関連ファイルの拡張子一覧
        let extensions = ["", ".wal", ".shm"]

        do {
            for ext in extensions {
                let oldFile = URL(fileURLWithPath: oldStoreURL.path + ext)
                let newFile = URL(fileURLWithPath: newStoreURL.path + ext)

                if fileManager.fileExists(atPath: oldFile.path) {
                    try fileManager.copyItem(at: oldFile, to: newFile)
                }
            }
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("SwiftDataストアをApp Groupに移行しました")
        } catch {
            print("SwiftDataストア移行エラー: \(error)")
        }
    }
}
