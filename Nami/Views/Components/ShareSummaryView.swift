//
//  ShareSummaryView.swift
//  Nami
//
//  シェア用サマリー画面 - 週間/月間を切り替えてプレビュー + 画像生成 + 共有
//

import SwiftUI
import SwiftData

/// シェア期間の選択肢
enum SharePeriod: String, CaseIterable, Identifiable {
    case weekly = "週間"
    case monthly = "月間"

    var id: String { rawValue }
}

/// シェアサマリーシート
struct ShareSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let entries: [MoodEntry]
    let currentMaxScore: Int
    let themeColors: ThemeColors
    let statsVM: StatsViewModel

    @State private var selectedPeriod: SharePeriod = .weekly
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                themeColors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 期間切り替え
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(SharePeriod.allCases) { period in
                            Text(LocalizedStringKey(period.rawValue)).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // カードプレビュー
                    ScrollView {
                        summaryCard
                            .padding()
                    }

                    Spacer()

                    // シェアボタン
                    Button {
                        generateAndShare()
                    } label: {
                        Label("シェアする", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeColors.accent)
                            )
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("サマリーをシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    // MARK: - サマリーカード

    private var summaryCard: some View {
        let data = cardData
        return SummaryCardView(
            periodLabel: data.periodLabel,
            averageScore: data.averageScore,
            trend: data.trend,
            entryCount: data.entryCount,
            sparklineData: data.sparkline,
            maxScore: currentMaxScore,
            accentColor: themeColors.accent,
            graphLineColor: .white,
            graphFillColor: themeColors.graphFill,
            bgStart: themeColors.accent,
            bgEnd: themeColors.accent.opacity(0.7)
        )
    }

    // MARK: - データ計算

    private var cardData: (periodLabel: String, averageScore: Double, trend: Double?, entryCount: Int, sparkline: [Double]) {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .weekly:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let weekEntries = entries.filter { $0.createdAt >= startOfWeek }
            let avg = statsVM.weeklyAverage(entries: entries, currentMax: currentMaxScore) ?? 0
            let trend = statsVM.weeklyTrend(entries: entries, currentMax: currentMaxScore)
            let sparkline = statsVM.sparklineData(entries: entries, since: startOfWeek)
            return (String(localized: "今週のまとめ"), avg, trend, weekEntries.count, sparkline)

        case .monthly:
            let startOfMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
            let monthEntries = entries.filter { $0.createdAt >= startOfMonth }
            let avg = statsVM.monthlyAverage(entries: entries, currentMax: currentMaxScore) ?? 0
            // 月間トレンド（先月比）
            let currentAvg = statsVM.monthlyAverage(entries: entries, currentMax: currentMaxScore)
            let prevAvg = statsVM.lastMonthAverage(entries: entries, currentMax: currentMaxScore)
            let trend: Double? = (currentAvg != nil && prevAvg != nil) ? currentAvg! - prevAvg! : nil
            let sparkline = statsVM.sparklineData(entries: entries, since: startOfMonth)
            return (String(localized: "今月のまとめ"), avg, trend, monthEntries.count, sparkline)
        }
    }

    // MARK: - 画像生成 + シェア

    private func generateAndShare() {
        let data = cardData
        let cardView = SummaryCardView(
            periodLabel: data.periodLabel,
            averageScore: data.averageScore,
            trend: data.trend,
            entryCount: data.entryCount,
            sparklineData: data.sparkline,
            maxScore: currentMaxScore,
            accentColor: themeColors.accent,
            graphLineColor: .white,
            graphFillColor: themeColors.graphFill,
            bgStart: themeColors.accent,
            bgEnd: themeColors.accent.opacity(0.7)
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

#Preview {
    ShareSummaryView(
        entries: [],
        currentMaxScore: 10,
        themeColors: .ocean,
        statsVM: StatsViewModel()
    )
}
