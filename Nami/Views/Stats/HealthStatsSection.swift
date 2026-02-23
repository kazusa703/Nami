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

        computed = true
    }

    private struct PairedDay {
        let score: Double
        let health: DailyHealthData
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
