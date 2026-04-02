//
//  ScoreWaveShape.swift
//  Nami
//
//  Wave shape that draws a smooth Bezier curve from daily average scores
//  Used as a background decoration in the monthly report header
//

import SwiftUI

struct ScoreWaveShape: Shape {
    /// Daily average scores (1-31 days, value 1.0-10.0, 0 = no record)
    let dailyScores: [Double]

    func path(in rect: CGRect) -> Path {
        // Filter to only days with data
        let dataPoints = dailyScores.enumerated().compactMap { index, score -> (Int, Double)? in
            score > 0 ? (index, score) : nil
        }

        guard dataPoints.count >= 2 else {
            return Path()
        }

        var path = Path()
        let totalDays = max(dailyScores.count - 1, 1)

        /// Convert score to Y position (10=top, 1=bottom)
        func yFor(_ score: Double) -> CGFloat {
            let normalized = (score - 1.0) / 9.0 // 0.0-1.0
            return rect.height * (1.0 - normalized) * 0.7 + rect.height * 0.1
        }

        // Start at first data point
        let first = dataPoints[0]
        let startX = rect.width * CGFloat(first.0) / CGFloat(totalDays)
        path.move(to: CGPoint(x: startX, y: yFor(first.1)))

        // Smooth Bezier curves between data points
        for i in 1 ..< dataPoints.count {
            let prev = dataPoints[i - 1]
            let curr = dataPoints[i]
            let prevX = rect.width * CGFloat(prev.0) / CGFloat(totalDays)
            let currX = rect.width * CGFloat(curr.0) / CGFloat(totalDays)
            let midX = (prevX + currX) / 2

            path.addCurve(
                to: CGPoint(x: currX, y: yFor(curr.1)),
                control1: CGPoint(x: midX, y: yFor(prev.1)),
                control2: CGPoint(x: midX, y: yFor(curr.1))
            )
        }

        // Close path for fill (line down to bottom, across, back up)
        let last = dataPoints.last!
        let lastX = rect.width * CGFloat(last.0) / CGFloat(totalDays)
        path.addLine(to: CGPoint(x: lastX, y: rect.height))
        path.addLine(to: CGPoint(x: startX, y: rect.height))
        path.closeSubpath()

        return path
    }
}
