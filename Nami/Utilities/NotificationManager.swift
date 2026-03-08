//
//  NotificationManager.swift
//  Nami
//
//  リマインダー通知の管理
//

import UserNotifications

/// リマインダー通知を管理するユーティリティ
enum NotificationManager {
    /// 通知リクエストの識別子
    private static let reminderIdentifier = "nami.daily.reminder"

    /// 通知権限をリクエストする
    /// - Returns: 権限が許可されたかどうか
    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            #if DEBUG
                print("通知権限リクエストエラー: \(error)")
            #endif
            return false
        }
    }

    /// 毎日指定時刻にリマインダー通知をスケジュールする
    /// - Parameters:
    ///   - hour: 時（0〜23）
    ///   - minute: 分（0〜59）
    static func scheduleReminder(hour: Int, minute: Int) {
        // 既存の通知をキャンセルしてから再スケジュール
        cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "今日の気分は？")
        content.body = String(localized: "今の気分を記録して、自分の波を振り返りましょう。")
        content.sound = .default

        // 毎日繰り返すトリガー
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
                if let error {
                    print("通知スケジュールエラー: \(error)")
                }
            #endif
        }
    }

    /// リマインダー通知をキャンセルする
    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    /// 現在の通知権限ステータスを確認する
    /// - Returns: 通知が許可されているかどうか
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
