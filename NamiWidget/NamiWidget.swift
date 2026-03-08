//
//  NamiWidget.swift
//  NamiWidget
//
//  ウィジェットのTimelineProvider & Widget定義
//

import SwiftData
import SwiftUI
import WidgetKit

// MARK: - ウィジェットデータ

/// ウィジェット表示用のデータ
struct MoodWidgetEntry: TimelineEntry {
    let date: Date
    /// 直近7日間の日別データ（日付・平均スコア・記録数）
    let dailyData: [DailyMood]
    /// 最新のスコア
    let latestScore: Int?
    /// 最新の記録時刻
    let latestDate: Date?
    /// 週間平均
    let weeklyAverage: Double?
    /// 月間平均
    let monthlyAverage: Double?
    /// 先週比トレンド（+/-）
    let weeklyTrend: Double?
    /// 連続記録日数（ストリーク）
    let currentStreak: Int
    /// 今日の記録件数
    let todayCount: Int
    /// 現在のテーマ
    let theme: WidgetTheme
    /// スコアレンジ上限
    let maxScore: Int
    /// スコアレンジ下限
    let minScore: Int
}

/// 日別気分データ
struct DailyMood {
    let date: Date
    let averageScore: Double
    let entryCount: Int
}

// MARK: - タイムラインプロバイダー

struct NamiTimelineProvider: TimelineProvider {
    /// プレースホルダー表示用
    func placeholder(in _: Context) -> MoodWidgetEntry {
        MoodWidgetEntry(
            date: .now,
            dailyData: Self.sampleDaily(),
            latestScore: 7,
            latestDate: .now,
            weeklyAverage: 6.5,
            monthlyAverage: 6.2,
            weeklyTrend: 0.3,
            currentStreak: 5,
            todayCount: 2,
            theme: .ocean,
            maxScore: 10,
            minScore: 1
        )
    }

    /// スナップショット（ウィジェットギャラリー等で表示）
    func getSnapshot(in context: Context, completion: @escaping (MoodWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(fetchEntry())
        }
    }

    /// タイムライン生成（定期更新）
    func getTimeline(in _: Context, completion: @escaping (Timeline<MoodWidgetEntry>) -> Void) {
        let entry = fetchEntry()
        // 30分後に次の更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - データ取得

    private func fetchEntry() -> MoodWidgetEntry {
        let theme = WidgetTheme.current
        let maxScore = {
            let stored = WidgetConstants.sharedUserDefaults.integer(forKey: WidgetConstants.scoreRangeMaxKey)
            return stored > 0 ? stored : 10
        }()
        let minScore = WidgetConstants.sharedUserDefaults.object(forKey: WidgetConstants.scoreRangeMinKey) as? Int ?? 1

        guard let container = makeSharedModelContainer() else {
            return emptyEntry(theme: theme, maxScore: maxScore, minScore: minScore)
        }

        let context = ModelContext(container)
        let calendar = Calendar.current

        // 直近30日間のエントリを取得（週間・月間計算に使用）
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: .now) ?? .now
        var descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.createdAt >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 500
        let recentEntries = (try? context.fetch(descriptor)) ?? []

        // ストリーク計算用に全エントリの日付を取得
        var allDescriptor = FetchDescriptor<MoodEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        allDescriptor.fetchLimit = 365
        let allEntries = (try? context.fetch(allDescriptor)) ?? []

        // 日別データ（直近7日）
        let dailyData = buildDailyData(entries: recentEntries, calendar: calendar)

        // 最新スコア
        let latest = recentEntries.last
        let latestScore = latest?.score
        let latestDate = latest?.createdAt

        // 週間平均
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekEntries = recentEntries.filter { $0.createdAt >= sevenDaysAgo }
        let weeklyAverage: Double? = weekEntries.isEmpty ? nil
            : Double(weekEntries.map(\.score).reduce(0, +)) / Double(weekEntries.count)

        // 先週の平均（トレンド計算用）
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now
        let lastWeekEntries = recentEntries.filter { $0.createdAt >= fourteenDaysAgo && $0.createdAt < sevenDaysAgo }
        let lastWeekAvg: Double? = lastWeekEntries.isEmpty ? nil
            : Double(lastWeekEntries.map(\.score).reduce(0, +)) / Double(lastWeekEntries.count)
        let weeklyTrend: Double? = (weeklyAverage != nil && lastWeekAvg != nil)
            ? weeklyAverage! - lastWeekAvg! : nil

        // 月間平均
        let monthlyAverage: Double? = recentEntries.isEmpty ? nil
            : Double(recentEntries.map(\.score).reduce(0, +)) / Double(recentEntries.count)

        // ストリーク計算
        let currentStreak = calculateStreak(entries: allEntries, calendar: calendar)

        // 今日の記録件数
        let todayCount = recentEntries.filter { calendar.isDateInToday($0.createdAt) }.count

        return MoodWidgetEntry(
            date: .now,
            dailyData: dailyData,
            latestScore: latestScore,
            latestDate: latestDate,
            weeklyAverage: weeklyAverage,
            monthlyAverage: monthlyAverage,
            weeklyTrend: weeklyTrend,
            currentStreak: currentStreak,
            todayCount: todayCount,
            theme: theme,
            maxScore: maxScore,
            minScore: minScore
        )
    }

    /// 直近7日の日別データを構築
    private func buildDailyData(entries: [MoodEntry], calendar: Calendar) -> [DailyMood] {
        var result: [DailyMood] = []
        for dayOffset in (0 ..< 7).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { continue }
            let dayStart = calendar.startOfDay(for: targetDate)
            let dayEntries = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: dayStart) }

            if dayEntries.isEmpty {
                result.append(DailyMood(date: dayStart, averageScore: 0, entryCount: 0))
            } else {
                let avg = Double(dayEntries.map(\.score).reduce(0, +)) / Double(dayEntries.count)
                result.append(DailyMood(date: dayStart, averageScore: avg, entryCount: dayEntries.count))
            }
        }
        return result
    }

    /// 連続記録日数を計算（今日から遡る）
    private func calculateStreak(entries: [MoodEntry], calendar: Calendar) -> Int {
        guard !entries.isEmpty else { return 0 }

        // 記録がある日のSetを作成
        var recordedDays = Set<Date>()
        for entry in entries {
            recordedDays.insert(calendar.startOfDay(for: entry.createdAt))
        }

        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        // 今日記録がなければ、昨日から数える
        if !recordedDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while recordedDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    /// 空のエントリ
    private func emptyEntry(theme: WidgetTheme, maxScore: Int, minScore: Int = 1) -> MoodWidgetEntry {
        MoodWidgetEntry(
            date: .now,
            dailyData: [],
            latestScore: nil,
            latestDate: nil,
            weeklyAverage: nil,
            monthlyAverage: nil,
            weeklyTrend: nil,
            currentStreak: 0,
            todayCount: 0,
            theme: theme,
            maxScore: maxScore,
            minScore: minScore
        )
    }

    /// サンプルの日別データ
    static func sampleDaily() -> [DailyMood] {
        let calendar = Calendar.current
        let scores: [Double] = [5, 6, 4, 7, 8, 6, 7]
        return (0 ..< 7).map { i in
            let date = calendar.date(byAdding: .day, value: -(6 - i), to: .now) ?? .now
            return DailyMood(date: calendar.startOfDay(for: date), averageScore: scores[i], entryCount: i % 2 == 0 ? 2 : 1)
        }
    }
}

// MARK: - ウィジェット定義

/// メインウィジェット（Small / Medium / Large）
struct NamiWidget: Widget {
    let kind = "NamiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NamiTimelineProvider()) { entry in
            NamiWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(.clear)
                }
        }
        .configurationDisplayName("Nami")
        .description("今日の気分と最近の波を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// ロック画面ウィジェット
struct NamiLockScreenWidget: Widget {
    let kind = "NamiLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NamiTimelineProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nami")
        .description("ロック画面に今の気分を表示します。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// メインウィジェットのビュー切り替え
struct NamiWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MoodWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

/// ロック画面ウィジェットのビュー切り替え
struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MoodWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        default:
            CircularLockScreenView(entry: entry)
        }
    }
}
