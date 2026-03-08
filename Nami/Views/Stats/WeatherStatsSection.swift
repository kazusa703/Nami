//
//  WeatherStatsSection.swift
//  Nami
//
//  Weather-mood correlation section for StatsView
//

import SwiftUI

struct WeatherStatsSection: View {
    let entries: [MoodEntry]
    let themeColors: ThemeColors
    let currentMax: Int
    let currentMin: Int

    @State private var conditionBands: [HealthBandData]?
    @State private var temperatureBands: [HealthBandData]?
    @State private var pressureBands: [HealthBandData]?
    @State private var conditionBest: BestConditionResult?
    @State private var temperatureBest: BestConditionResult?
    @State private var pressureBest: BestConditionResult?
    @State private var computed = false

    // MARK: - Thresholds

    private enum WeatherThresholds {
        enum Temperature {
            static let cold = 10.0 // <10 = cold
            static let warm = 20.0 // 10-20 = cool, 20-28 = warm
            static let hot = 28.0 // >=28 = hot
        }

        enum Pressure {
            static let low = 1005.0 // <1005hPa = low pressure
            static let high = 1020.0 // >=1020hPa = high pressure
        }
    }

    var body: some View {
        let weatherDays = countWeatherDays()

        Group {
            if weatherDays < 5 {
                progressCard(dayCount: weatherDays)
            } else if computed {
                chartsCard(dayCount: weatherDays)
            }
        }
        .task(id: entries.count) {
            guard weatherDays >= 5 else { return }
            computeBandAverages()
        }
    }

    // MARK: - Progress Card

    private func progressCard(dayCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cloud.sun")
                    .foregroundStyle(.cyan)
                Text("天気と気分")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            if dayCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    Text("あと\(5 - dayCount)日分のデータで表示されます")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Charts Card

    @ViewBuilder
    private func chartsCard(dayCount: Int) -> some View {
        let hasAnyChart = conditionBands != nil || temperatureBands != nil || pressureBands != nil

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "cloud.sun")
                    .foregroundStyle(.cyan)
                Text("天気と気分")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Text("\(dayCount)日分")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if hasAnyChart {
                let bestConditions = [conditionBest, temperatureBest, pressureBest].compactMap { $0 }

                if !bestConditions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(bestConditions.enumerated()), id: \.offset) { _, result in
                            bestConditionRow(result)
                        }
                    }

                    Divider()
                        .padding(.vertical, 2)
                }

                if let conditionBands {
                    HealthMoodChartView(
                        title: "天気別の気分",
                        icon: "cloud.sun",
                        bands: conditionBands,
                        themeColors: themeColors,
                        maxScore: currentMax,
                        minScore: currentMin
                    )
                }

                if let temperatureBands {
                    HealthMoodChartView(
                        title: "気温別の気分",
                        icon: "thermometer.medium",
                        bands: temperatureBands,
                        themeColors: themeColors,
                        maxScore: currentMax,
                        minScore: currentMin
                    )
                }

                if let pressureBands {
                    HealthMoodChartView(
                        title: "気圧別の気分",
                        icon: "barometer",
                        bands: pressureBands,
                        themeColors: themeColors,
                        maxScore: currentMax,
                        minScore: currentMin
                    )
                }
            } else {
                Text("データのばらつきが増えるとパターンが見えてきます。記録を続けてみてください。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Best Condition Row

    private func bestConditionRow(_ result: BestConditionResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.metricIcon)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(themeColors.accent)
                .frame(width: 16)
            Text(bestConditionText(for: result))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bestConditionText(for result: BestConditionResult) -> String {
        let deltaStr = String(format: "%.1f", result.delta)
        return "\(result.metricName)が\(result.bestBandLabel)日（\(result.thresholdDesc)）は気分が +\(deltaStr)pt 高い傾向"
    }

    // MARK: - Types

    private struct BestConditionResult {
        let metricIcon: String
        let metricName: String
        let bestBandLabel: String
        let thresholdDesc: String
        let bestBandAvg: Double
        let delta: Double
        let bestBandCount: Int
    }

    private struct DailyWeatherData {
        let date: Date
        let condition: String
        let temperature: Double? // nil if no temp data for this day
        let pressure: Double? // nil if no pressure data for this day
    }

    private struct PairedDay {
        let score: Double
        let weather: DailyWeatherData
    }

    private enum WeatherMetricType {
        case condition, temperature, pressure

        var icon: String {
            switch self {
            case .condition: return "cloud.sun"
            case .temperature: return "thermometer.medium"
            case .pressure: return "barometer"
            }
        }

        var displayName: String {
            switch self {
            case .condition: return "天気"
            case .temperature: return "気温"
            case .pressure: return "気圧"
            }
        }

        func thresholdDescription(for band: String) -> String {
            switch (self, band) {
            case (.condition, "晴れ"): return "晴れ・ほぼ晴れ"
            case (.condition, "曇り"): return "やや曇り〜曇り"
            case (.condition, "雨/雪"): return "雨・雪・雷"
            case (.temperature, "寒い"): return "10℃未満"
            case (.temperature, "涼しい"): return "10〜20℃"
            case (.temperature, "暖かい"): return "20〜28℃"
            case (.temperature, "暑い"): return "28℃以上"
            case (.pressure, "低気圧"): return "1005hPa未満"
            case (.pressure, "普通"): return "1005〜1020hPa"
            case (.pressure, "高気圧"): return "1020hPa以上"
            default: return band
            }
        }
    }

    // MARK: - Weather Condition Classification

    private static func classifyCondition(_ condition: String) -> String {
        let sunny = ["晴れ", "ほぼ晴れ", "天気雨"]
        let cloudy = ["やや曇り", "ほぼ曇り", "曇り", "霧", "もや", "煙霧"]
        if sunny.contains(condition) { return "晴れ" }
        if cloudy.contains(condition) { return "曇り" }
        return "雨/雪"
    }

    private static func classifyTemperature(_ temp: Double) -> String {
        if temp < WeatherThresholds.Temperature.cold { return "寒い" }
        if temp < WeatherThresholds.Temperature.warm { return "涼しい" }
        if temp < WeatherThresholds.Temperature.hot { return "暖かい" }
        return "暑い"
    }

    private static func classifyPressure(_ pressure: Double) -> String {
        if pressure < WeatherThresholds.Pressure.low { return "低気圧" }
        if pressure >= WeatherThresholds.Pressure.high { return "高気圧" }
        return "普通"
    }

    // MARK: - Helpers

    private func countWeatherDays() -> Int {
        let calendar = Calendar.current
        var days = Set<Date>()
        for entry in entries where entry.weatherCondition != nil {
            days.insert(calendar.startOfDay(for: entry.createdAt))
        }
        return days.count
    }

    /// Mode of an array of strings
    private static func mode(of values: [String]) -> String? {
        var counts: [String: Int] = [:]
        for v in values {
            counts[v, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Band Computation

    private func computeBandAverages() {
        let calendar = Calendar.current

        // Group entries by day, compute daily average normalizedScore
        var dailyScores: [Date: Double] = [:]
        var dailyCounts: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            dailyScores[day, default: 0] += entry.normalizedScore
            dailyCounts[day, default: 0] += 1
        }

        var dayAvgScores: [Date: Double] = [:]
        for (day, totalNorm) in dailyScores {
            let count = dailyCounts[day, default: 1]
            let avgNorm = totalNorm / Double(count)
            dayAvgScores[day] = avgNorm * Double(currentMax - currentMin) + Double(currentMin)
        }

        // Group weather entries by day
        var dayConditions: [Date: [String]] = [:]
        var dayTemperatures: [Date: [Double]] = [:]
        var dayPressures: [Date: [Double]] = [:]

        for entry in entries {
            guard entry.weatherCondition != nil else { continue }
            let day = calendar.startOfDay(for: entry.createdAt)
            if let cond = entry.weatherCondition {
                dayConditions[day, default: []].append(cond)
            }
            if let temp = entry.weatherTemperature {
                dayTemperatures[day, default: []].append(temp)
            }
            if let press = entry.weatherPressure {
                dayPressures[day, default: []].append(press)
            }
        }

        // Build daily weather data
        var dailyWeather: [Date: DailyWeatherData] = [:]
        for day in dayConditions.keys {
            guard let condMode = Self.mode(of: dayConditions[day] ?? []) else { continue }
            let temps = dayTemperatures[day] ?? []
            let presses = dayPressures[day] ?? []
            dailyWeather[day] = DailyWeatherData(
                date: day,
                condition: condMode,
                temperature: temps.isEmpty ? nil : Self.avg(temps),
                pressure: presses.isEmpty ? nil : Self.avg(presses)
            )
        }

        // Pair weather + mood score
        var paired: [PairedDay] = []
        for (day, weather) in dailyWeather {
            if let score = dayAvgScores[day] {
                paired.append(PairedDay(score: score, weather: weather))
            }
        }

        // Condition bands
        conditionBands = buildBands(from: paired, extract: { Self.classifyCondition($0.weather.condition) })

        // Temperature bands (only days with actual temp data)
        let tempPairs = paired.filter { $0.weather.temperature != nil }
        if !tempPairs.isEmpty {
            temperatureBands = buildBands(from: tempPairs, extract: { Self.classifyTemperature($0.weather.temperature!) })
        }

        // Pressure bands (only days with actual pressure data)
        let pressPairs = paired.filter { $0.weather.pressure != nil }
        if !pressPairs.isEmpty {
            pressureBands = buildBands(from: pressPairs, extract: { Self.classifyPressure($0.weather.pressure!) })
        }

        // Best condition insights (need 14+ paired days)
        if paired.count >= 14 {
            conditionBest = buildBestCondition(
                from: paired, metricType: .condition,
                classify: { Self.classifyCondition($0.weather.condition) }
            )
            if tempPairs.count >= 14 {
                temperatureBest = buildBestCondition(
                    from: tempPairs, metricType: .temperature,
                    classify: { Self.classifyTemperature($0.weather.temperature!) }
                )
            }
            if pressPairs.count >= 14 {
                pressureBest = buildBestCondition(
                    from: pressPairs, metricType: .pressure,
                    classify: { Self.classifyPressure($0.weather.pressure!) }
                )
            }
        }

        computed = true
    }

    // MARK: - Band Building

    private func buildBands(
        from paired: [PairedDay],
        extract: (PairedDay) -> String
    ) -> [HealthBandData]? {
        var bandScores: [String: [Double]] = [:]
        for p in paired {
            let label = extract(p)
            bandScores[label, default: []].append(p.score)
        }

        let nonEmpty = bandScores.filter { !$0.value.isEmpty }
        guard nonEmpty.count >= 2 else { return nil }

        // Sort by predefined order
        let order = ["晴れ", "曇り", "雨/雪", "寒い", "涼しい", "暖かい", "暑い", "低気圧", "普通", "高気圧"]
        let sorted = nonEmpty.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? 99
            let bi = order.firstIndex(of: b.key) ?? 99
            return ai < bi
        }

        return sorted.map { label, scores in
            let avg = scores.reduce(0, +) / Double(scores.count)
            return HealthBandData(label: label, averageScore: avg, entryCount: scores.count)
        }
    }

    // MARK: - Best Condition

    private func buildBestCondition(
        from paired: [PairedDay],
        metricType: WeatherMetricType,
        classify: (PairedDay) -> String
    ) -> BestConditionResult? {
        var bandScores: [String: [Double]] = [:]
        for p in paired {
            let label = classify(p)
            bandScores[label, default: []].append(p.score)
        }

        let validBands = bandScores.filter { $0.value.count >= 3 }
        guard validBands.count >= 2 else { return nil }

        let bandAvgs = validBands.mapValues { scores in
            scores.reduce(0, +) / Double(scores.count)
        }

        let sorted = bandAvgs.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return (validBands[a.key]?.count ?? 0) > (validBands[b.key]?.count ?? 0)
        }

        guard let best = sorted.first, let worst = sorted.last else { return nil }
        let delta = best.value - worst.value
        guard delta >= 0.5 else { return nil }

        return BestConditionResult(
            metricIcon: metricType.icon,
            metricName: metricType.displayName,
            bestBandLabel: best.key,
            thresholdDesc: metricType.thresholdDescription(for: best.key),
            bestBandAvg: best.value,
            delta: delta,
            bestBandCount: validBands[best.key]?.count ?? 0
        )
    }

    private static func avg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0.0, +) / Double(values.count)
    }
}
