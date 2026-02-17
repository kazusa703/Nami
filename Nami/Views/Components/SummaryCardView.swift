//
//  SummaryCardView.swift
//  Nami
//
//  SNSシェア用サマリーカード + スパークライン形状
//  ImageRenderer は @Environment 非対応のため全データをパラメータで受け取る
//

import SwiftUI

/// スパークライン（折れ線）を描画するカスタムShape
/// Swift Charts は ImageRenderer との互換性に問題があるため、Shape で代替する
struct SparklineShape: Shape {
    /// 0.0〜1.0に正規化されたデータ配列
    let data: [Double]

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2 else { return Path() }

        var path = Path()
        let step = rect.width / CGFloat(data.count - 1)

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * step
            let y = rect.height - (CGFloat(value) * rect.height)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

/// スパークラインの塗りつぶし領域用Shape
struct SparklineFillShape: Shape {
    let data: [Double]

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2 else { return Path() }

        var path = Path()
        let step = rect.width / CGFloat(data.count - 1)

        // 上辺（データライン）
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * step
            let y = rect.height - (CGFloat(value) * rect.height)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // 下辺（底辺を閉じる）
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

/// SNSシェア用サマリーカード
/// ImageRenderer で画像化するため、@Environment を使わず全データをパラメータで受け取る
struct SummaryCardView: View {
    /// 期間ラベル（例: "今週のまとめ"）
    let periodLabel: String
    /// 平均スコア
    let averageScore: Double
    /// 前期比トレンド（+/-）
    let trend: Double?
    /// 記録件数
    let entryCount: Int
    /// スパークラインデータ（0.0〜1.0正規化済み）
    let sparklineData: [Double]
    /// スコア最大値（表示用）
    let maxScore: Int
    /// テーマカラー
    let accentColor: Color
    /// グラフ線色
    let graphLineColor: Color
    /// グラフ塗りつぶし色
    let graphFillColor: Color
    /// 背景グラデーション開始色
    let bgStart: Color
    /// 背景グラデーション終了色
    let bgEnd: Color

    var body: some View {
        VStack(spacing: 16) {
            // ヘッダー：期間ラベル + ブランディング
            HStack {
                Text(periodLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Text("Nami")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // メインスコア
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", averageScore))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("/ \(maxScore)")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                // トレンド表示
                if let trend {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(.caption, weight: .bold))
                            Text(String(format: "%+.1f", trend))
                                .font(.system(.callout, design: .rounded, weight: .bold))
                        }
                        .foregroundStyle(trend >= 0 ? Color.green : Color.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((trend >= 0 ? Color.green : Color.red).opacity(0.2))
                        )

                        Text("前期比")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            // スパークライン
            if sparklineData.count >= 2 {
                ZStack {
                    SparklineFillShape(data: sparklineData)
                        .fill(
                            LinearGradient(
                                colors: [graphLineColor.opacity(0.3), graphLineColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    SparklineShape(data: sparklineData)
                        .stroke(graphLineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 60)
            }

            // フッター：記録件数
            HStack {
                Image(systemName: "pencil.line")
                    .font(.system(.caption2))
                Text("\(entryCount)件の記録")
                    .font(.system(.caption, design: .rounded, weight: .medium))

                Spacer()

                Text(Date.now, format: .dateTime.month(.defaultDigits).day(.defaultDigits))
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(24)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [bgStart, bgEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    SummaryCardView(
        periodLabel: "今週のまとめ",
        averageScore: 7.3,
        trend: 1.2,
        entryCount: 14,
        sparklineData: [0.3, 0.5, 0.7, 0.6, 0.8, 0.9, 0.7],
        maxScore: 10,
        accentColor: ThemeColors.ocean.accent,
        graphLineColor: .white,
        graphFillColor: ThemeColors.ocean.graphFill,
        bgStart: ThemeColors.ocean.accent,
        bgEnd: ThemeColors.ocean.accent.opacity(0.7)
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
