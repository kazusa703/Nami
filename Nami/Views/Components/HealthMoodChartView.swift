//
//  HealthMoodChartView.swift
//  Nami
//
//  Reusable horizontal bar chart for health-mood correlation bands
//

import SwiftUI

// MARK: - HealthBandData

struct HealthBandData: Identifiable {
    let id = UUID()
    let label: String
    let averageScore: Double
    let entryCount: Int
}

// MARK: - HealthMoodChartView

struct HealthMoodChartView: View {
    let title: String
    let icon: String
    let bands: [HealthBandData]
    let themeColors: ThemeColors
    let maxScore: Int
    let minScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(themeColors.accent)
                Text(title)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            ForEach(bands) { band in
                HStack(spacing: 8) {
                    Text(band.label)
                        .font(.system(.caption, design: .rounded))
                        .frame(width: 55, alignment: .leading)

                    GeometryReader { geo in
                        let range = Double(max(maxScore - minScore, 1))
                        let ratio = min(max((band.averageScore - Double(minScore)) / range, 0.05), 1.0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                themeColors.color(
                                    for: Int(band.averageScore.rounded()),
                                    maxScore: maxScore,
                                    minScore: minScore
                                ).gradient
                            )
                            .frame(width: geo.size.width * ratio)
                    }
                    .frame(height: 14)

                    Text(String(format: "%.1f", band.averageScore))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(
                            themeColors.color(
                                for: Int(band.averageScore.rounded()),
                                maxScore: maxScore,
                                minScore: minScore
                            )
                        )
                        .frame(width: 28, alignment: .trailing)

                    Text("(\(band.entryCount))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28)
                }
            }
        }
    }
}
