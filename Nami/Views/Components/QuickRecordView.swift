//
//  QuickRecordView.swift
//  Nami
//
//  Lightweight recording view for deep link from widget tap.
//  Shows score buttons → RecordingSheet flow.
//

import SwiftData
import SwiftUI

/// Quick record view shown when widget deep-links to nami://record
struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeManager) private var themeManager
    @Environment(\.weatherManager) private var weatherManager

    @AppStorage(AppConstants.scoreRangeKey) private var scoreRangeRaw: String = ScoreRange.pos10.rawValue

    @State private var viewModel = MoodViewModel()
    @State private var recorded = false

    private var scoreRange: ScoreRange {
        ScoreRange(rawValue: scoreRangeRaw) ?? .pos10
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(String(localized: "今の気分は？"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(themeManager.colors.accent)

                Text("\(scoreRange.displayName)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                ScoreInputView(
                    inputType: .buttons,
                    minScore: scoreRange.minValue,
                    maxScore: scoreRange.maxValue,
                    themeColors: themeManager.colors
                ) { score in
                    viewModel.recordMood(
                        score: score,
                        maxScore: scoreRange.maxValue,
                        scoreRangeMin: scoreRange.minValue,
                        context: modelContext,
                        weatherManager: weatherManager
                    )
                    recorded = true
                }

                if recorded {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(String(localized: "記録しました"))
                            .font(.system(.headline, design: .rounded))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
        }
        .sheet(isPresented: $viewModel.showRecordingSheet) {
            if let entry = viewModel.lastRecordedEntry {
                RecordingSheet(
                    score: entry.score,
                    maxScore: entry.maxScore,
                    scoreRangeMin: entry.scoreRangeMin,
                    themeColors: themeManager.colors,
                    onSave: { memo, photo, voiceMemoURL, tags, energyLevel in
                        if !memo.isEmpty { entry.memo = String(memo.prefix(100)) }
                        if let photo { entry.photoPath = MediaManager.savePhoto(photo) }
                        if let voiceMemoURL { entry.voiceMemoPath = MediaManager.saveVoiceMemo(from: voiceMemoURL) }
                        entry.tags = tags
                        entry.energyLevel = energyLevel
                    },
                    onSkip: {
                        viewModel.showRecordingSheet = false
                    }
                )
            }
        }
        .animation(.spring(response: 0.3), value: recorded)
    }
}
