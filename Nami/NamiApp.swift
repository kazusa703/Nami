//
//  NamiApp.swift
//  Nami
//
//  アプリのエントリポイント
//

import SwiftUI
import SwiftData
import AppTrackingTransparency
import GoogleMobileAds

@main
struct NamiApp: App {
    /// 画面回転の動的制御用AppDelegate
    @UIApplicationDelegateAdaptor(NamiAppDelegate.self) var appDelegate
    /// テーママネージャー（アプリ全体で共有）
    @State private var themeManager = ThemeManager()
    /// プレミアム状態マネージャー
    @State private var premiumManager = PremiumManager()

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
                cloudKitDatabase: .automatic  // iCloud同期を有効化
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
                .task {
                    // デフォルト感情タグの初期化
                    DefaultTags.seedIfNeeded(context: sharedModelContainer.mainContext)

                    // WatchConnectivityの初期化
                    WatchConnectivityManager.shared.modelContainer = sharedModelContainer
                    WatchConnectivityManager.shared.activate()

                    // Google Mobile Ads SDK の初期化
                    _ = await MobileAds.shared.start()

                    // ATT（App Tracking Transparency）許可リクエスト
                    // 広告パーソナライズのためのトラッキング許可ダイアログ
                    // UI表示後に少し遅延してダイアログを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        ATTrackingManager.requestTrackingAuthorization { _ in }
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
