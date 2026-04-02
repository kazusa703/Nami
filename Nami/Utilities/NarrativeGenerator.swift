//
//  NarrativeGenerator.swift
//  Nami
//
//  Generates personalized narrative text for monthly reports
//  2-3 sentences summarizing the month's mood journey
//

import SwiftUI

enum NarrativeGenerator {
    struct NarrativeResult {
        let plainText: String
        let highlightedTagName: String?
    }

    static func generate(
        activeDays: Int,
        daysInMonth: Int,
        monthName: String,
        average: Double,
        previousAverage: Double?,
        topRescueAction: (name: String, multiplier: Double)?
    ) -> NarrativeResult {
        var sentences: [String] = []
        var highlightTag: String?

        // Sentence 1: Recording activity
        if activeDays == daysInMonth {
            sentences.append([
                "毎日欠かさず記録した、充実の\(monthName)でした。",
                "一日も休まず記録を続けた\(monthName)。",
                "\(daysInMonth)日間、毎日記録を重ねた\(monthName)でした。",
            ].randomElement()!)
        } else if activeDays >= Int(Double(daysInMonth) * 0.8) {
            sentences.append("\(activeDays)日間記録を続けた、安定した\(monthName)でした。")
        } else if activeDays >= Int(Double(daysInMonth) * 0.5) {
            sentences.append("\(activeDays)日分の記録を振り返る\(monthName)。")
        } else if activeDays >= 7 {
            sentences.append("少しずつ記録を重ねた\(monthName)でした。")
        } else {
            sentences.append("\(monthName)の記録は\(activeDays)日分。少しずつでも大丈夫。")
        }

        // Sentence 2: Trend vs previous month
        if let prev = previousAverage {
            let diff = average - prev
            if diff > 1.0 {
                sentences.append("先月から大きく上向き、平均\(String(format: "%.1f", average))まで伸びました。")
            } else if diff > 0.3 {
                sentences.append("先月より少し上向きの\(String(format: "%.1f", average))。いい調子です。")
            } else if diff > -0.3 {
                sentences.append("先月とほぼ同じリズムで、安定が続いています。")
            } else if diff > -1.0 {
                sentences.append("少し波のある月でしたが、それも大切な記録です。")
            } else {
                sentences.append("大きな波がありましたが、記録を続けたこと自体に価値があります。")
            }
        }

        // Sentence 3: Highlight action
        if let action = topRescueAction, action.multiplier >= 1.3 {
            highlightTag = action.name
            sentences.append("特に「\(action.name)」があなたの支えになった月でした。")
        }

        return NarrativeResult(
            plainText: sentences.joined(separator: ""),
            highlightedTagName: highlightTag
        )
    }

    /// Convert narrative to AttributedString with tag name highlighted
    static func attributedText(
        from result: NarrativeResult,
        accentColor: Color
    ) -> AttributedString {
        var attributed = AttributedString(result.plainText)

        if let tagName = result.highlightedTagName,
           let range = attributed.range(of: "「\(tagName)」")
        {
            attributed[range].foregroundColor = accentColor
            attributed[range].font = .body.bold()
        }

        return attributed
    }
}
