//
//  PredictionEngine.swift
//  Nami
//
//  Tomorrow's mood prediction engine (Premium feature)
//  Uses weekday patterns, recent trends, and tag correlations
//  to generate a probabilistic forecast.
//

import Foundation

// MARK: - PredictionEngine

/// Tomorrow's mood prediction engine (Premium feature)
enum PredictionEngine {

    // MARK: - Types

    /// Prediction result
    struct Prediction {
        let predictedScore: Double    // predicted normalized score (0.0-1.0)
        let confidence: Double        // 0.0-1.0
        let rangeLow: Double          // predicted - uncertainty
        let rangeHigh: Double         // predicted + uncertainty
        let factors: [String]         // explanation strings
    }

    /// Yesterday's prediction for comparison (persisted)
    struct PredictionRecord: Codable {
        let date: Date               // target date (the day being predicted)
        let predictedNormalized: Double
        let currentMax: Int
        let currentMin: Int
    }

    // MARK: - Constants

    /// Minimum entries needed for prediction
    static let minimumEntries = 30

    /// UserDefaults key for saved prediction
    private static let predictionKey = "lastPrediction"

    /// Factor weights
    private static let weekdayWeight: Double = 0.4
    private static let trendWeight: Double = 0.3
    private static let tagWeight: Double = 0.3

    // MARK: - Public API

    /// Generate prediction for tomorrow
    static func predictTomorrow(
        from entries: [MoodEntry],
        currentMax: Int,
        currentMin: Int = 1
    ) -> Prediction? {
        guard entries.count >= minimumEntries else { return nil }

        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date.now) else { return nil }
        let tomorrowWeekday = calendar.component(.weekday, from: tomorrow)

        // --- Factor 1: Weekday average (weight 0.4) ---
        let weekdayEntries = entries.filter {
            calendar.component(.weekday, from: $0.createdAt) == tomorrowWeekday
        }
        let weekdayAvg: Double? = weekdayEntries.isEmpty ? nil : {
            let sum = weekdayEntries.reduce(0.0) { $0 + $1.normalizedScore }
            return sum / Double(weekdayEntries.count)
        }()

        // --- Factor 2: Trend (weight 0.3) ---
        // Linear regression on last 3 days' daily averages
        let trendResult = computeRecentTrend(entries: entries, calendar: calendar)

        // --- Factor 3: Tag pattern (weight 0.3) ---
        // Look at today's entries' tags; find historical "next day after these tags" average
        let tagResult = computeTagFactor(entries: entries, calendar: calendar)

        // --- Combine ---
        var weightedSum: Double = 0
        var totalWeight: Double = 0
        var factors: [String] = []

        if let avg = weekdayAvg {
            weightedSum += avg * weekdayWeight
            totalWeight += weekdayWeight
            let weekdayName = weekdayDisplayName(tomorrowWeekday)
            let overallAvg = entries.reduce(0.0) { $0 + $1.normalizedScore } / Double(entries.count)
            if avg > overallAvg + 0.05 {
                factors.append(String(localized: "明日は\(weekdayName)（平均スコアが高い曜日）"))
            } else if avg < overallAvg - 0.05 {
                factors.append(String(localized: "明日は\(weekdayName)（平均スコアがやや低い曜日）"))
            } else {
                factors.append(String(localized: "明日は\(weekdayName)（平均的な曜日）"))
            }
        }

        if let trend = trendResult {
            weightedSum += trend.extrapolated * trendWeight
            totalWeight += trendWeight
            if trend.slope > 0.02 {
                factors.append(String(localized: "直近3日間は上昇傾向"))
            } else if trend.slope < -0.02 {
                factors.append(String(localized: "直近3日間は下降傾向"))
            } else {
                factors.append(String(localized: "直近3日間は安定傾向"))
            }
        }

        if let tagFactor = tagResult {
            weightedSum += tagFactor.nextDayAvg * tagWeight
            totalWeight += tagWeight
            let tagName = tagFactor.tagName
            let overallAvg = entries.reduce(0.0) { $0 + $1.normalizedScore } / Double(entries.count)
            if tagFactor.nextDayAvg > overallAvg + 0.05 {
                factors.append(String(localized: "今日のタグ「\(tagName)」の翌日は好調な傾向"))
            } else if tagFactor.nextDayAvg < overallAvg - 0.05 {
                factors.append(String(localized: "今日のタグ「\(tagName)」の翌日はやや低調な傾向"))
            } else {
                factors.append(String(localized: "今日のタグ「\(tagName)」の翌日は平均的な傾向"))
            }
        }

        guard totalWeight > 0 else { return nil }

        let predicted = (weightedSum / totalWeight).clamped(to: 0.0...1.0)

        // Confidence: based on data density (entries per week ratio over last 8 weeks)
        guard let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: Date.now) else { return nil }
        let recentEntries = entries.filter { $0.createdAt >= eightWeeksAgo }
        let weeksOfData = max(1.0, Double(calendar.dateComponents([.weekOfYear], from: eightWeeksAgo, to: Date.now).weekOfYear ?? 8))
        let entriesPerWeek = Double(recentEntries.count) / weeksOfData
        // 7 entries/week = full confidence; scale linearly
        let confidence = min(1.0, entriesPerWeek / 7.0)

        let uncertainty = (1.0 - confidence) * 0.3
        let rangeLow = max(0.0, predicted - uncertainty)
        let rangeHigh = min(1.0, predicted + uncertainty)

        return Prediction(
            predictedScore: predicted,
            confidence: confidence,
            rangeLow: rangeLow,
            rangeHigh: rangeHigh,
            factors: factors
        )
    }

    /// Save today's prediction for tomorrow (UserDefaults)
    static func savePrediction(_ prediction: Prediction, currentMax: Int, currentMin: Int) {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date.now) else { return }
        let record = PredictionRecord(
            date: tomorrow,
            predictedNormalized: prediction.predictedScore,
            currentMax: currentMax,
            currentMin: currentMin
        )
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: predictionKey)
        }
    }

    /// Load yesterday's saved prediction (if target date is today)
    static func loadYesterdayPrediction() -> PredictionRecord? {
        guard let data = UserDefaults.standard.data(forKey: predictionKey),
              let record = try? JSONDecoder().decode(PredictionRecord.self, from: data) else {
            return nil
        }
        // Check if the prediction's target date is today
        let calendar = Calendar.current
        guard calendar.isDateInToday(record.date) else { return nil }
        return record
    }

    /// Check if yesterday's prediction was significantly off
    /// Returns (predicted, actual, delta) scaled to currentMax range, or nil
    static func checkPredictionDeviation(
        entries: [MoodEntry],
        currentMax: Int,
        currentMin: Int = 1
    ) -> (predicted: Double, actual: Double, delta: Double)? {
        guard let record = loadYesterdayPrediction() else { return nil }

        // Get today's first entry
        let calendar = Calendar.current
        let todayEntries = entries.filter { calendar.isDateInToday($0.createdAt) }
        guard let firstEntry = todayEntries.min(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }

        // Scale predicted normalized score to current range
        let range = Double(currentMax - currentMin)
        let predictedScaled = record.predictedNormalized * range + Double(currentMin)
        let actualScaled = firstEntry.normalizedScore * range + Double(currentMin)
        let delta = actualScaled - predictedScaled

        // Only return if deviation is significant (> 2 in scaled range)
        guard abs(delta) > 2.0 else { return nil }

        return (predicted: predictedScaled, actual: actualScaled, delta: delta)
    }

    // MARK: - Private Helpers

    /// Result of recent trend computation
    private struct TrendResult {
        let slope: Double        // normalized score per day
        let extrapolated: Double // predicted normalized for tomorrow
    }

    /// Tag factor result
    private struct TagFactorResult {
        let tagName: String
        let nextDayAvg: Double   // average normalized score on next day
    }

    /// Compute linear regression on last 3 days' daily averages
    private static func computeRecentTrend(
        entries: [MoodEntry],
        calendar: Calendar
    ) -> TrendResult? {
        let today = calendar.startOfDay(for: Date.now)

        // Collect daily averages for last 3 days (today, yesterday, day before)
        var dailyAverages: [(dayOffset: Int, avg: Double)] = []
        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayEntries = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { continue }
            let avg = dayEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(dayEntries.count)
            dailyAverages.append((dayOffset: -offset, avg: avg))
        }

        guard dailyAverages.count >= 2 else { return nil }

        // Simple linear regression: y = mx + b
        // x = dayOffset (negative), extrapolate to x = 1 (tomorrow)
        let n = Double(dailyAverages.count)
        let sumX = dailyAverages.reduce(0.0) { $0 + Double($1.dayOffset) }
        let sumY = dailyAverages.reduce(0.0) { $0 + $1.avg }
        let sumXY = dailyAverages.reduce(0.0) { $0 + Double($1.dayOffset) * $1.avg }
        let sumXX = dailyAverages.reduce(0.0) { $0 + Double($1.dayOffset) * Double($1.dayOffset) }

        let denominator = n * sumXX - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        // Extrapolate to x = 1 (tomorrow)
        let extrapolated = (slope * 1.0 + intercept).clamped(to: 0.0...1.0)

        return TrendResult(slope: slope, extrapolated: extrapolated)
    }

    /// Compute tag-based next-day average for today's most impactful tag
    private static func computeTagFactor(
        entries: [MoodEntry],
        calendar: Calendar
    ) -> TagFactorResult? {
        // Get today's entries with tags
        let todayEntries = entries.filter { calendar.isDateInToday($0.createdAt) }
        let todayTags = Set(todayEntries.flatMap { $0.tags })
        guard !todayTags.isEmpty else { return nil }

        // Sort entries by date for next-day lookup
        let sortedEntries = entries.sorted { $0.createdAt < $1.createdAt }

        // For each of today's tags, compute average next-day score
        var bestTag: String?
        var bestSampleCount = 0
        var bestNextDayAvg: Double = 0

        for tag in todayTags {
            var nextDayScores: [Double] = []

            // Find all historical days that had this tag
            let tagEntries = sortedEntries.filter { $0.tags.contains(tag) }
            let tagDays = Set(tagEntries.map { calendar.startOfDay(for: $0.createdAt) })

            for day in tagDays {
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
                // Skip if next day is today or in the future
                guard nextDay < calendar.startOfDay(for: Date.now) else { continue }
                let nextDayEntries = sortedEntries.filter {
                    calendar.isDate($0.createdAt, inSameDayAs: nextDay)
                }
                guard !nextDayEntries.isEmpty else { continue }
                let avg = nextDayEntries.reduce(0.0) { $0 + $1.normalizedScore } / Double(nextDayEntries.count)
                nextDayScores.append(avg)
            }

            // Need at least 3 samples for this tag
            guard nextDayScores.count >= 3 else { continue }

            let avg = nextDayScores.reduce(0.0, +) / Double(nextDayScores.count)
            // Pick tag with most samples (most reliable)
            if nextDayScores.count > bestSampleCount {
                bestSampleCount = nextDayScores.count
                bestNextDayAvg = avg
                bestTag = tag
            }
        }

        guard let tagName = bestTag else { return nil }
        return TagFactorResult(tagName: tagName, nextDayAvg: bestNextDayAvg)
    }

    /// Get localized weekday display name
    private static func weekdayDisplayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        // weekday: 1=Sunday, 2=Monday, ... 7=Saturday
        let index = (weekday - 1) % 7
        return symbols[index]
    }
}

// MARK: - Double clamping extension

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
