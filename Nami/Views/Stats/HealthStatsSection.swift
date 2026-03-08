//
//  HealthStatsSection.swift
//  Nami
//
//  Health-mood correlation section for StatsView
//

import SwiftUI

struct HealthStatsSection: View {
    let healthData: [DailyHealthData]
    let entries: [MoodEntry]
    let themeColors: ThemeColors
    let currentMax: Int
    let currentMin: Int

    @State private var stepBands: [HealthBandData]?
    @State private var sleepBands: [HealthBandData]?
    @State private var energyBands: [HealthBandData]?
    @State private var stepBestCondition: BestConditionResult?
    @State private var sleepBestCondition: BestConditionResult?
    @State private var energyBestCondition: BestConditionResult?
    @State private var computed = false

    var body: some View {
        let dayCount = healthData.count

        Group {
            if dayCount < 5 {
                progressCard(dayCount: dayCount)
            } else if computed {
                chartsCard()
            }
        }
        .task(id: healthData.count) {
            guard dayCount >= 5 else { return }
            computeBandAverages()
        }
    }

    // MARK: - Progress Card

    private func progressCard(dayCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(.pink)
                Text("ヘルスケアと気分")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                Text("あと\(5 - dayCount)日分のデータで表示されます")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
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
    private func chartsCard() -> some View {
        let hasAnyChart = stepBands != nil || sleepBands != nil || energyBands != nil

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(.pink)
                Text("ヘルスケアと気分")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Text("\(healthData.count)日分")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if hasAnyChart {
                let bestConditions = [stepBestCondition, sleepBestCondition, energyBestCondition].compactMap { $0 }

                if !bestConditions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(bestConditions.enumerated()), id: \.offset) { _, result in
                            bestConditionRow(result)
                        }
                    }

                    Divider()
                        .padding(.vertical, 2)
                }

                if let stepBands {
                    HealthMoodChartView(
                        title: "歩数別の気分",
                        icon: "figure.walk",
                        bands: stepBands,
                        themeColors: themeColors,
                        maxScore: currentMax,
                        minScore: currentMin
                    )
                }

                if let sleepBands {
                    HealthMoodChartView(
                        title: "睡眠時間別の気分",
                        icon: "bed.double.fill",
                        bands: sleepBands,
                        themeColors: themeColors,
                        maxScore: currentMax,
                        minScore: currentMin
                    )
                }

                if let energyBands {
                    HealthMoodChartView(
                        title: "運動量別の気分",
                        icon: "flame.fill",
                        bands: energyBands,
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
        let bandDesc: String
        switch (result.metricIcon, result.bestBandLabel) {
        case ("bed.double.fill", "長い"):
            bandDesc = "睡眠が長めの日"
        case ("bed.double.fill", "短い"):
            bandDesc = "睡眠が短めの日"
        default:
            bandDesc = "\(result.metricName)が\(result.bestBandLabel)日"
        }
        let deltaStr = String(format: "%.1f", result.delta)
        return "\(bandDesc)（\(result.thresholdDesc)）は気分が +\(deltaStr)pt 高い傾向"
    }

    // MARK: - Band Computation

    private func computeBandAverages() {
        let calendar = Calendar.current

        // Group entries by day and compute daily average normalizedScore
        var dailyScores: [Date: Double] = [:]
        var dailyCounts: [Date: Int] = [:]

        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            dailyScores[day, default: 0] += entry.normalizedScore
            dailyCounts[day, default: 0] += 1
        }

        // Build day -> scaled average score
        var dayAvgScores: [Date: Double] = [:]
        for (day, totalNorm) in dailyScores {
            let count = dailyCounts[day, default: 1]
            let avgNorm = totalNorm / Double(count)
            dayAvgScores[day] = avgNorm * Double(currentMax - currentMin) + Double(currentMin)
        }

        // Build health data lookup by day
        var healthByDay: [Date: DailyHealthData] = [:]
        for hd in healthData {
            healthByDay[hd.id] = hd
        }

        // Collect paired data (days with both health and mood data)
        var paired: [PairedDay] = []
        for (day, score) in dayAvgScores {
            if let hd = healthByDay[day] {
                paired.append(PairedDay(score: score, health: hd))
            }
        }

        // Steps bands
        stepBands = buildBands(from: paired, extract: { $0.health.steps.map(Double.init) }) { value in
            if value < Double(HealthThresholds.Steps.low) {
                return "少ない"
            } else if value >= Double(HealthThresholds.Steps.high) {
                return "多い"
            } else {
                return "普通"
            }
        }

        // Sleep bands
        sleepBands = buildBands(from: paired, extract: { $0.health.sleepMinutes.map(Double.init) }) { value in
            if value < Double(HealthThresholds.Sleep.short) {
                return "短い"
            } else if value >= Double(HealthThresholds.Sleep.long) {
                return "長い"
            } else {
                return "普通"
            }
        }

        // Active energy bands
        energyBands = buildBands(from: paired, extract: { $0.health.activeEnergyKcal }) { value in
            if value < HealthThresholds.ActiveEnergy.low {
                return "少ない"
            } else if value >= HealthThresholds.ActiveEnergy.high {
                return "多い"
            } else {
                return "普通"
            }
        }

        // Best condition insights (need more data than charts)
        if paired.count >= 14 {
            let classifySteps: (Double) -> String = { value in
                if value < Double(HealthThresholds.Steps.low) { return "少ない" }
                else if value >= Double(HealthThresholds.Steps.high) { return "多い" }
                else { return "普通" }
            }
            let classifySleep: (Double) -> String = { value in
                if value < Double(HealthThresholds.Sleep.short) { return "短い" }
                else if value >= Double(HealthThresholds.Sleep.long) { return "長い" }
                else { return "普通" }
            }
            let classifyEnergy: (Double) -> String = { value in
                if value < HealthThresholds.ActiveEnergy.low { return "少ない" }
                else if value >= HealthThresholds.ActiveEnergy.high { return "多い" }
                else { return "普通" }
            }

            stepBestCondition = buildBestCondition(
                from: paired, metricType: .steps,
                extract: { $0.health.steps.map(Double.init) }, classify: classifySteps
            )
            sleepBestCondition = buildBestCondition(
                from: paired, metricType: .sleep,
                extract: { $0.health.sleepMinutes.map(Double.init) }, classify: classifySleep
            )
            energyBestCondition = buildBestCondition(
                from: paired, metricType: .energy,
                extract: { $0.health.activeEnergyKcal }, classify: classifyEnergy
            )
        }

        computed = true
    }

    private struct PairedDay {
        let score: Double
        let health: DailyHealthData
    }

    // MARK: - Best Condition Types

    private struct BestConditionResult {
        let metricIcon: String
        let metricName: String
        let bestBandLabel: String
        let thresholdDesc: String
        let bestBandAvg: Double
        let delta: Double
        let bestBandCount: Int
    }

    private enum HealthMetricType {
        case steps, sleep, energy

        var icon: String {
            switch self {
            case .steps: return "figure.walk"
            case .sleep: return "bed.double.fill"
            case .energy: return "flame.fill"
            }
        }

        var displayName: String {
            switch self {
            case .steps: return "歩数"
            case .sleep: return "睡眠"
            case .energy: return "運動量"
            }
        }

        func thresholdDescription(for band: String) -> String {
            switch (self, band) {
            case (.steps, "少ない"): return "3,000歩未満"
            case (.steps, "普通"): return "3,000〜8,000歩"
            case (.steps, "多い"): return "8,000歩以上"
            case (.sleep, "短い"): return "6時間未満"
            case (.sleep, "普通"): return "6〜8時間"
            case (.sleep, "長い"): return "8時間以上"
            case (.energy, "少ない"): return "150kcal未満"
            case (.energy, "普通"): return "150〜400kcal"
            case (.energy, "多い"): return "400kcal以上"
            default: return band
            }
        }
    }

    // MARK: - Best Condition Computation

    private func buildBestCondition(
        from paired: [PairedDay],
        metricType: HealthMetricType,
        extract: (PairedDay) -> Double?,
        classify: (Double) -> String
    ) -> BestConditionResult? {
        var bandScores: [String: [Double]] = [:]
        for p in paired {
            guard let value = extract(p) else { continue }
            let label = classify(value)
            bandScores[label, default: []].append(p.score)
        }

        // Only bands with >= 3 entries are valid
        let validBands = bandScores.filter { $0.value.count >= 3 }
        guard validBands.count >= 2 else { return nil }

        // Compute averages
        let bandAvgs = validBands.mapValues { scores in
            scores.reduce(0, +) / Double(scores.count)
        }

        // Find best and worst (tie-break by entry count)
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

    /// Build bands for a metric. Returns nil if fewer than 2 bands have data.
    private func buildBands(
        from paired: [PairedDay],
        extract: (PairedDay) -> Double?,
        classify: (Double) -> String
    ) -> [HealthBandData]? {
        var bandScores: [String: [Double]] = [:]
        for p in paired {
            guard let value = extract(p) else { continue }
            let label = classify(value)
            bandScores[label, default: []].append(p.score)
        }

        let nonEmpty = bandScores.filter { !$0.value.isEmpty }
        guard nonEmpty.count >= 2 else { return nil }

        let order = ["少ない", "短い", "普通", "多い", "長い"]
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
}
