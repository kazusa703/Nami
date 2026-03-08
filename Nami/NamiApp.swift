//
//  NamiApp.swift
//  Nami
//
//  アプリのエントリポイント
//

import AppTrackingTransparency
import GoogleMobileAds
import SwiftData
import SwiftUI

@main
struct NamiApp: App {
    /// 画面回転の動的制御用AppDelegate
    @UIApplicationDelegateAdaptor(NamiAppDelegate.self) var appDelegate
    /// テーママネージャー（アプリ全体で共有）
    @State private var themeManager = ThemeManager()
    /// プレミアム状態マネージャー
    @State private var premiumManager = PremiumManager()
    /// HealthKitマネージャー
    @State private var healthKitManager = HealthKitManager()
    /// アプリのシーンフェーズ
    @Environment(\.scenePhase) private var scenePhase

    /// リマインダーの有効/無効（AppStorageと同期）
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 21
    @AppStorage("reminderMinute") private var reminderMinute = 0

    /// タグ非アクティブ化シート表示フラグ
    @State private var showTagDeactivationSheet = false

    /// SwiftDataのモデルコンテナ（App Group共有パス）
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MoodEntry.self,
            EmotionTag.self,
            TagCategory.self,
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
                #if DEBUG
                    print("App Group共有コンテナでのModelContainer作成に失敗: \(error)")
                #endif
                // App Groupは利用可能だがストア作成に失敗 → デフォルトにフォールバック
            }
        } else {
            #if DEBUG
                print("App Groupコンテナが利用できません。Xcode → Signing & Capabilities → App Groups で group.com.imai.Nami を有効化してください。")
            #endif
        }

        // フォールバック: デフォルトパスを使用（App Group未設定またはストア作成失敗時）
        do {
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [fallbackConfig])
        } catch {
            // Persistent store also failed — use in-memory store as last resort
            // so the app can still launch and show an error to the user
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("ModelContainerの作成に失敗しました: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.themeManager, themeManager)
                .environment(\.premiumManager, premiumManager)
                .environment(\.healthKitManager, healthKitManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        healthKitManager.invalidateTodayCache()
                    }
                }
                .onChange(of: premiumManager.isPremium) { _, isPremium in
                    if !isPremium {
                        // プレミアム失効: カスタムタグが上限超えなら選択シートを表示
                        let context = sharedModelContainer.mainContext
                        let descriptor = FetchDescriptor<EmotionTag>()
                        if let allTags = try? context.fetch(descriptor) {
                            let activeCustomCount = allTags.filter { !$0.isDefault && $0.isActive }.count
                            if activeCustomCount > premiumManager.freeCustomTagLimit {
                                showTagDeactivationSheet = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showTagDeactivationSheet) {
                    TagDeactivationSheet()
                }
                .task {
                    // デバッグビルド時のみ: テストデータ投入
                    #if DEBUG
                        DebugDataSeeder.seedIfNeeded(context: sharedModelContainer.mainContext)
                        // Range Picker boundary & tag scalability test data
                        if !UserDefaults.standard.bool(forKey: "debug_range_test_seeded") {
                            DebugDataSeeder.seedBoundaryData(context: sharedModelContainer.mainContext)
                            DebugDataSeeder.seedMassTagData(context: sharedModelContainer.mainContext, uniqueTagCount: 200)
                            UserDefaults.standard.set(true, forKey: "debug_range_test_seeded")
                        }
                    #endif

                    // 重複除去 → デフォルト感情タグの初期化
                    DefaultTags.deduplicateIfNeeded(context: sharedModelContainer.mainContext)
                    DefaultTags.seedIfNeeded(context: sharedModelContainer.mainContext)

                    // Google Mobile Ads SDK の初期化
                    #if !DEBUG
                        _ = await MobileAds.shared.start()
                    #endif

                    // ATT（App Tracking Transparency）許可リクエスト
                    // 広告パーソナライズのためのトラッキング許可ダイアログ
                    // UI表示後に少し遅延してダイアログを表示
                    #if !DEBUG
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            ATTrackingManager.requestTrackingAuthorization { _ in
                            }
                        }
                    #endif

                    // アプリ起動時: プレミアム失効 & カスタムタグ超過チェック
                    // （onChange は値の変化時のみ発火するため、起動時にも確認が必要）
                    if !premiumManager.isPremium {
                        let context = sharedModelContainer.mainContext
                        let descriptor = FetchDescriptor<EmotionTag>()
                        if let allTags = try? context.fetch(descriptor) {
                            let activeCustomCount = allTags.filter { !$0.isDefault && $0.isActive }.count
                            if activeCustomCount > premiumManager.freeCustomTagLimit {
                                showTagDeactivationSheet = true
                            }
                        }
                    }

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

        // Copy to temp location first, then move atomically
        let tempDir = newStoreURL.deletingLastPathComponent().appendingPathComponent("migration_temp")
        do {
            // Clean up any previous failed attempt
            if fileManager.fileExists(atPath: tempDir.path) {
                try? fileManager.removeItem(at: tempDir)
            }
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for ext in extensions {
                let oldFile = URL(fileURLWithPath: oldStoreURL.path + ext)
                let tempFile = tempDir.appendingPathComponent("Nami.store" + ext)

                if fileManager.fileExists(atPath: oldFile.path) {
                    try fileManager.copyItem(at: oldFile, to: tempFile)
                }
            }

            // All copies succeeded — move to final location
            for ext in extensions {
                let tempFile = tempDir.appendingPathComponent("Nami.store" + ext)
                let newFile = URL(fileURLWithPath: newStoreURL.path + ext)
                if fileManager.fileExists(atPath: tempFile.path) {
                    try fileManager.moveItem(at: tempFile, to: newFile)
                }
            }

            try? fileManager.removeItem(at: tempDir)
            UserDefaults.standard.set(true, forKey: migrationKey)
            #if DEBUG
                print("SwiftDataストアをApp Groupに移行しました")
            #endif
        } catch {
            // Clean up partial migration
            try? fileManager.removeItem(at: tempDir)
            for ext in extensions {
                let newFile = URL(fileURLWithPath: newStoreURL.path + ext)
                try? fileManager.removeItem(at: newFile)
            }
            #if DEBUG
                print("SwiftDataストア移行エラー: \(error)")
            #endif
        }
    }
}
