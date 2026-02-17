//
//  LockScreenWidgetViews.swift
//  NamiWidget
//
//  ロック画面ウィジェット（Circular / Rectangular / Inline）
//  参考: Apple Health, Daylio のロック画面ウィジェット
//

import SwiftUI
import WidgetKit

// MARK: - Circular（円形ゲージ）

/// ロック画面 円形ウィジェット: スコアゲージ
struct CircularLockScreenView: View {
    let entry: MoodWidgetEntry

    var body: some View {
        if let score = entry.latestScore {
            let fraction = Double(score) / Double(entry.maxScore)

            Gauge(value: fraction) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 8))
            } currentValueLabel: {
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            // 記録なし
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 10))
                    Text("--")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

// MARK: - Rectangular（長方形）

/// ロック画面 長方形ウィジェット: スコア + ストリーク + ミニスパークライン
struct RectangularLockScreenView: View {
    let entry: MoodWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            // 左: スコア
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Nami")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }

                if let score = entry.latestScore {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                } else {
                    Text("--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .opacity(0.4)
                }

                // ストリーク or 記録数
                if entry.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                        Text("\(entry.currentStreak)日")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                }
            }

            Spacer()

            // 右: ミニスパークライン（7日分）
            miniSparkline
                .frame(width: 70, height: 30)
        }
    }

    /// 7日間のミニスパークライン
    private var miniSparkline: some View {
        let scores = entry.dailyData.map { daily -> Double in
            daily.entryCount > 0 ? daily.averageScore : 0
        }

        return Canvas { context, size in
            // 有効なスコアのみでスパークラインを描画
            let validScores = scores.filter { $0 > 0 }
            guard validScores.count >= 2 else { return }

            let maxVal = Double(entry.maxScore)
            let points: [CGPoint] = scores.enumerated().compactMap { index, score in
                guard score > 0 else { return nil }
                let x = size.width * Double(index) / 6.0
                let y = size.height * (1 - score / maxVal)
                return CGPoint(x: x, y: y)
            }

            guard points.count >= 2 else { return }

            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(path, with: .foreground, lineWidth: 1.5)

            // 最新ポイント
            if let last = points.last {
                let dot = Path(ellipseIn: CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5))
                context.fill(dot, with: .foreground)
            }
        }
    }
}

// MARK: - Inline（テキスト一行）

/// ロック画面 インラインウィジェット: テキストのみ
struct InlineLockScreenView: View {
    let entry: MoodWidgetEntry

    var body: some View {
        if let score = entry.latestScore {
            if entry.currentStreak > 0 {
                Text("Nami: \(score) 🔥\(entry.currentStreak)日")
            } else {
                Text("Nami: \(score)")
            }
        } else {
            Text("Nami: 未記録")
        }
    }
}
