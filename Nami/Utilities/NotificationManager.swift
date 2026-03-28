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

    // MARK: - ⑤ Smart Reminder (Auto-learn recording time)

    private static let smartReminderKey = "recordingTimeHistory"
    private static let smartReminderEnabledKey = "smartReminderEnabled"

    /// Whether smart reminder is enabled
    static var smartReminderEnabled: Bool {
        get { UserDefaults.standard.object(forKey: smartReminderEnabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: smartReminderEnabledKey) }
    }

    /// Record the time user made a mood entry (call after each recording)
    static func trackRecordingTime() {
        let hour = Calendar.current.component(.hour, from: .now)
        var history = UserDefaults.standard.array(forKey: smartReminderKey) as? [Int] ?? []
        history.append(hour)
        // Keep last 14 entries
        if history.count > 14 { history = Array(history.suffix(14)) }
        UserDefaults.standard.set(history, forKey: smartReminderKey)

        // After 7+ recordings, auto-set reminder to most common hour
        if history.count >= 7, smartReminderEnabled {
            updateSmartReminder(from: history)
        }
    }

    /// Calculate most common recording hour and schedule reminder
    private static func updateSmartReminder(from hours: [Int]) {
        var counts: [Int: Int] = [:]
        for h in hours {
            counts[h, default: 0] += 1
        }
        guard let peakHour = counts.max(by: { $0.value < $1.value })?.key else { return }

        // Schedule 30 min before peak hour
        let reminderHour = peakHour
        let reminderMinute = 0
        scheduleReminder(hour: reminderHour, minute: reminderMinute)

        // Save for display in settings
        UserDefaults.standard.set(peakHour, forKey: "smartReminderHour")
    }

    /// Get the learned peak recording hour (nil if not enough data)
    static var learnedRecordingHour: Int? {
        let history = UserDefaults.standard.array(forKey: smartReminderKey) as? [Int] ?? []
        guard history.count >= 7 else { return nil }
        var counts: [Int: Int] = [:]
        for h in history {
            counts[h, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - ⑥ Win-back Notifications (inactive user re-engagement)

    private static let winbackPrefix = "nami.winback"
    private static let lastRecordDateKey = "lastMoodRecordDate"

    /// Update the last recording date (call after each recording)
    static func updateLastRecordDate() {
        UserDefaults.standard.set(Date.now, forKey: lastRecordDateKey)
    }

    /// Schedule win-back notifications for inactive users
    /// Call on app launch
    static func scheduleWinbackIfNeeded() {
        guard insightNotificationsEnabled else { return }

        // Cancel existing win-back notifications
        let ids = ["\(winbackPrefix).7", "\(winbackPrefix).14", "\(winbackPrefix).30"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)

        guard let lastRecord = UserDefaults.standard.object(forKey: lastRecordDateKey) as? Date else { return }

        let daysSinceRecord = Calendar.current.dateComponents([.day], from: lastRecord, to: .now).day ?? 0

        // Only schedule future win-backs (don't send if already past the window)
        if daysSinceRecord < 7 {
            scheduleWinback(
                identifier: "\(winbackPrefix).7",
                afterDays: 7 - daysSinceRecord,
                title: String(localized: "最近どうですか？"),
                body: String(localized: "少しの間記録が途切れていますが、それも大丈夫。気が向いたときに、また気分を残してみませんか？")
            )
        }

        if daysSinceRecord < 14 {
            scheduleWinback(
                identifier: "\(winbackPrefix).14",
                afterDays: 14 - daysSinceRecord,
                title: String(localized: "データは残っています"),
                body: String(localized: "これまでの記録はすべて保存されています。いつでも戻って、振り返ることができます。")
            )
        }

        if daysSinceRecord < 30 {
            scheduleWinback(
                identifier: "\(winbackPrefix).30",
                afterDays: 30 - daysSinceRecord,
                title: String(localized: "お久しぶりです"),
                body: String(localized: "1ヶ月ぶりですね。たった1回の記録から、また始められます。")
            )
        }
    }

    private static func scheduleWinback(identifier: String, afterDays: Int, title: String, body: String) {
        guard afterDays > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WINBACK"

        let seconds = TimeInterval(afterDays * 86400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Cancel all win-back notifications (call when user records)
    static func cancelWinback() {
        let ids = ["\(winbackPrefix).7", "\(winbackPrefix).14", "\(winbackPrefix).30"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Monthly Report Notification

    private static let monthlyReportID = "nami.monthlyReport"

    /// Schedule a local notification for the 1st of next month at the given hour
    static func scheduleMonthlyReportNotification(lastMonthActiveDays: Int, monthName: String) {
        cancelPending(identifier: monthlyReportID)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "🌊 \(monthName)のレポートが完成しました")
        content.body = String(localized: "先月は\(lastMonthActiveDays)日間記録できました！あなただけの気分の波をチェックしましょう。")
        content.sound = .default
        content.userInfo = ["action": "openMonthlyReport"]

        // 1st of next month at 9:00 AM
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.hour = 9
        components.minute = 3 // Slight offset to avoid :00 congestion

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: monthlyReportID, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Helpers

    private static func cancelPending(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
