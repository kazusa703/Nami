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
            print("通知権限リクエストエラー: \(error)")
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
            if let error {
                print("通知スケジュールエラー: \(error)")
            }
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

    // MARK: - Weekly Summary Notification

    private static let weeklySummaryIdentifier = "nami.weekly.summary"

    /// Schedule a weekly summary notification (every Monday at 9am)
    static func scheduleWeeklySummary(averageScore: Double, bestDay: String, currentMax _: Int) {
        cancelWeeklySummary()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "先週のまとめ")
        let scoreText = String(format: "%.1f", averageScore)
        content.body = String(localized: "先週の平均スコアは\(scoreText)でした。\(bestDay)が一番良い日でした。")
        content.sound = .default

        // Every Monday at 9am
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 9
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: weeklySummaryIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Weekly summary notification error: \(error)")
            }
        }
    }

    /// Cancel weekly summary notification
    static func cancelWeeklySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklySummaryIdentifier])
    }

    // MARK: - Insight Notifications

    private static let insightIdentifier = "nami.insight"
    private static let streakInsightIdentifier = "nami.insight.streak"
    private static let negativeAlertIdentifier = "nami.insight.negative"

    /// Max 1 insight notification per day
    private static let lastInsightNotifKey = "lastInsightNotificationDate"

    private static var canSendInsightToday: Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastInsightNotifKey) as? Date else { return true }
        return !Calendar.current.isDateInToday(lastDate)
    }

    private static func markInsightSent() {
        UserDefaults.standard.set(Date.now, forKey: lastInsightNotifKey)
    }

    // MARK: ① Delayed Insight (next day at same time as last recording)

    /// Schedule "yesterday's insight" notification for tomorrow at the same time
    /// Called after recording + insight generation
    static func scheduleDelayedInsight(title: String, body: String) {
        guard canSendInsightToday else { return }

        cancelPending(identifier: insightIdentifier)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "INSIGHT"

        // 24 hours from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)

        let request = UNNotificationRequest(
            identifier: insightIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Insight notification error: \(error)") }
        }
        markInsightSent()
    }

    // MARK: ② Streak Milestone Notification

    /// Notify when user hits a recording streak milestone
    static func scheduleStreakNotification(days: Int) {
        cancelPending(identifier: streakInsightIdentifier)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(days)日連続達成！")
        content.body = String(localized: "\(days)日間のデータが溜まりました。あなたの気分パターンが見えてきました。統計タブを確認しましょう。")
        content.sound = .default
        content.categoryIdentifier = "STREAK"

        // Show immediately (1 second delay to avoid blocking)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: streakInsightIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: ④ Negative Trend Alert

    /// Alert when 3+ consecutive negative recordings detected
    /// Only if user has opted in (checked via UserDefaults)
    static func scheduleNegativeAlert(averageScore: Double, days: Int) {
        let optedIn = UserDefaults.standard.bool(forKey: "negativeAlertEnabled")
        guard optedIn, canSendInsightToday else { return }

        cancelPending(identifier: negativeAlertIdentifier)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "最近の傾向")
        let scoreText = String(format: "%.1f", averageScore)
        content.body = String(localized: "最近しんどい日が\(days)日続いています（平均\(scoreText)）。少し振り返ってみませんか？")
        content.sound = .default
        content.categoryIdentifier = "INSIGHT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: negativeAlertIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Negative alert error: \(error)") }
        }
        markInsightSent()
    }

    // MARK: - Insight Notification Preferences

    /// Whether insight notifications are enabled (separate from reminder)
    static var insightNotificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "insightNotificationsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "insightNotificationsEnabled") }
    }

    /// Whether negative trend alerts are enabled (requires explicit opt-in)
    static var negativeAlertEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "negativeAlertEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "negativeAlertEnabled") }
    }

    // MARK: - Helpers

    private static func cancelPending(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
