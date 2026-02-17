//
//  TagImpactSheet.swift
//  Nami
//
//  タグの影響分析シート（ビフォーアフター比較）
//  特定タグがある日 vs ない日のスコアを比較する
//

import SwiftUI
import SwiftData
import Charts

/// 分布チャート用のデータ行
struct DistributionBar: Identifiable {
    let id = UUID()
    let bucket: String   // スコアラベル（例: "7" or "1-5"）
    let count: Int
    let group: String    // "タグあり" or "タグなし"
    let sortKey: Int     // ソート用
}

/// タグの影響分析シート
struct TagImpactSheet: View {
    let entries: [MoodEntry]
    let currentMaxScore: Int
    let themeColors: ThemeColors

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTag: String = ""
    @State private var statsVM = StatsViewModel()

    /// エントリで使用されている全タグ（出現回数付き）
    private var tagList: [(tag: String, count: Int)] {
        statsVM.allTagCounts(entries: entries)
    }

    /// 選択可能かどうか（5件以上）
    private let minimumSamples = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // タグピッカー
                    tagPicker

                    if !selectedTag.isEmpty {
                        // インパクトデータ
                        if let impact = statsVM.tagImpactData(
                            tag: selectedTag,
                            entries: entries,
                            currentMax: currentMaxScore
                        ) {
                            // 平均スコア比較カード
                            comparisonCard(impact: impact)

                            // 分布比較チャート
                            distributionChart(impact: impact)

                            // サンプルサイズ情報
                            sampleInfo(impact: impact)
                        } else {
                            noDataView
                        }
                    } else {
                        promptView
                    }
                }
                .padding()
            }
            .navigationTitle("タグの影響分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                // 初期選択: 最も使用頻度の高いタグ（5件以上あるもの）
                if selectedTag.isEmpty {
                    selectedTag = tagList.first(where: { $0.count >= minimumSamples })?.tag ?? ""
                }
            }
        }
    }

    // MARK: - タグピッカー

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分析するタグ")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            // タグチップをFlowLayoutで表示
            FlowLayout(spacing: 8) {
                ForEach(tagList, id: \.tag) { item in
                    let isDisabled = item.count < minimumSamples
                    let isSelected = selectedTag == item.tag

                    Button {
                        guard !isDisabled else { return }
                        selectedTag = item.tag
                        HapticManager.lightFeedback()
                    } label: {
                        HStack(spacing: 4) {
                            Text(item.tag)
                                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .regular))
                            Text("\(item.count)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                isSelected
                                    ? themeColors.accent
                                    : isDisabled
                                        ? Color(.systemGray5)
                                        : Color(.systemGray6)
                            )
                        )
                        .foregroundStyle(
                            isSelected ? .white : isDisabled ? .secondary : .primary
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(isDisabled ? 0.5 : 1.0)
                }
            }

            if tagList.contains(where: { $0.count < minimumSamples }) {
                Text("※ \(minimumSamples)件未満のタグは選択できません")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - 平均スコア比較カード

    @ViewBuilder
    private func comparisonCard(impact: (withAvg: Double, withoutAvg: Double, delta: Double,
                                        withDays: Int, withoutDays: Int,
                                        withDist: [Int: Int], withoutDist: [Int: Int])) -> some View {
        VStack(spacing: 16) {
            Text("「\(selectedTag)」の日 vs それ以外の日")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            HStack(spacing: 20) {
                // タグありの日
                VStack(spacing: 6) {
                    Text(String(format: "%.1f", impact.withAvg))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColors.color(for: Int(impact.withAvg.rounded()), maxScore: currentMaxScore))
                    Text("タグあり")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(themeColors.accent)
                    Text("\(impact.withDays)日")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 差分表示
                VStack(spacing: 4) {
                    Image(systemName: impact.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.title3)
                    Text(String(format: "%+.1f", impact.delta))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                .foregroundStyle(impact.delta >= 0 ? .green : .orange)

                // タグなしの日
                VStack(spacing: 6) {
                    Text(String(format: "%.1f", impact.withoutAvg))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColors.color(for: Int(impact.withoutAvg.rounded()), maxScore: currentMaxScore))
                    Text("タグなし")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(impact.withoutDays)日")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - 分布比較チャート

    @ViewBuilder
    private func distributionChart(impact: (withAvg: Double, withoutAvg: Double, delta: Double,
                                           withDays: Int, withoutDays: Int,
                                           withDist: [Int: Int], withoutDist: [Int: Int])) -> some View {
        let bars = buildDistributionBars(withDist: impact.withDist, withoutDist: impact.withoutDist)

        if !bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("スコア分布の比較")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                // 凡例
                HStack(spacing: 16) {
                    legendItem(color: themeColors.accent, label: "「\(selectedTag)」あり")
                    legendItem(color: Color.gray.opacity(0.5), label: "なし")
                }
                .font(.system(.caption2, design: .rounded))

                distributionChartContent(bars: bars)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    /// 分布チャート本体（型推論の負荷を分散するため分離）
    @ViewBuilder
    private func distributionChartContent(bars: [DistributionBar]) -> some View {
        let accentColor = themeColors.accent
        let grayColor = Color.gray.opacity(0.5)
        let bucketCount = Set(bars.map(\.bucket)).count

        Chart(bars) { bar in
            BarMark(
                x: .value("回数", bar.count),
                y: .value("スコア", bar.bucket)
            )
            .foregroundStyle(by: .value("グループ", bar.group))
            .position(by: .value("グループ", bar.group))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale([
            "タグあり": accentColor,
            "タグなし": grayColor
        ])
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(.caption, design: .rounded))
            }
        }
        .frame(height: CGFloat(bucketCount) * 36)
    }

    /// 凡例アイテム
    @ViewBuilder
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
        }
    }

    /// 分布データをバケットに変換
    private func buildDistributionBars(withDist: [Int: Int], withoutDist: [Int: Int]) -> [DistributionBar] {
        var bars: [DistributionBar] = []
        let buckets = scoreBuckets()

        for bucket in buckets {
            let withCount = bucket.range.reduce(0) { $0 + (withDist[$1] ?? 0) }
            let withoutCount = bucket.range.reduce(0) { $0 + (withoutDist[$1] ?? 0) }

            bars.append(DistributionBar(bucket: bucket.label, count: withCount, group: "タグあり", sortKey: bucket.sortKey))
            bars.append(DistributionBar(bucket: bucket.label, count: withoutCount, group: "タグなし", sortKey: bucket.sortKey))
        }

        return bars
    }

    /// スコアレンジに応じたバケット分割
    private func scoreBuckets() -> [(label: String, range: ClosedRange<Int>, sortKey: Int)] {
        if currentMaxScore <= 10 {
            return (1...currentMaxScore).map { ("\($0)", $0...$0, $0) }
        } else if currentMaxScore <= 30 {
            let step = 5
            return stride(from: 1, through: currentMaxScore, by: step).map { start in
                let end = min(start + step - 1, currentMaxScore)
                return ("\(start)-\(end)", start...end, start)
            }
        } else {
            let step = 10
            return stride(from: 1, through: currentMaxScore, by: step).map { start in
                let end = min(start + step - 1, currentMaxScore)
                return ("\(start)-\(end)", start...end, start)
            }
        }
    }

    // MARK: - サンプルサイズ情報

    @ViewBuilder
    private func sampleInfo(impact: (withAvg: Double, withoutAvg: Double, delta: Double,
                                     withDays: Int, withoutDays: Int,
                                     withDist: [Int: Int], withoutDist: [Int: Int])) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text("「\(selectedTag)」を記録した日（\(impact.withDays)日）とそれ以外の日（\(impact.withoutDays)日）の平均スコアを比較しています。サンプル数が少ない場合、傾向が安定しない可能性があります。")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - 空状態

    private var noDataView: some View {
        ContentUnavailableView {
            Label("データ不足", systemImage: "chart.bar.xaxis")
        } description: {
            Text("このタグの比較に十分なデータがありません。")
        }
    }

    private var promptView: some View {
        ContentUnavailableView {
            Label("タグを選択", systemImage: "hand.tap")
        } description: {
            Text("上のタグを選ぶと、そのタグがある日とない日のスコアを比較します。")
        }
    }
}

#Preview {
    Text("")
        .sheet(isPresented: .constant(true)) {
            TagImpactSheet(
                entries: [],
                currentMaxScore: 10,
                themeColors: .ocean
            )
        }
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
}
