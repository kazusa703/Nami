//
//  WatchMainView.swift
//  NamiWatch
//
//  Watch メイン画面 - Digital Crown でスコア選択、記録ボタン、タグ選択
//

import SwiftUI

/// Watchメイン画面
/// Digital Crownでスコアを選択し、記録ボタンで保存する
struct WatchMainView: View {
    @Environment(\.dismiss) private var dismiss
    let connector: WatchPhoneConnector

    /// 現在選択中のスコア
    @State private var selectedScore: Double = 5
    /// タグ選択画面を表示するか
    @State private var showTagSelection = false
    /// 選択中のタグ
    @State private var selectedTags: Set<String> = []
    /// 記録完了アニメーション
    @State private var showRecordedFeedback = false
    /// スコア範囲上限（UserDefaultsから読み取り）
    @State private var maxScore: Int = 10

    /// アクセントカラー（テーマ依存、簡易版）
    private var accentColor: Color {
        .blue // Watch版は簡易テーマ
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // スコア表示
                if showRecordedFeedback {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        Text("記録しました")
                            .font(.system(.caption, design: .rounded))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // スコア表示（大きなテキスト）
                    Text("\(Int(selectedScore))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .focusable()
                        .digitalCrownRotation(
                            $selectedScore,
                            from: 1,
                            through: Double(maxScore),
                            by: 1,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )

                    Text("1〜\(maxScore)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // 選択中のタグ
                if !selectedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(selectedTags), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(.caption2, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(accentColor.opacity(0.2)))
                            }
                        }
                    }
                    .frame(height: 20)
                }

                // ボタン群
                HStack(spacing: 12) {
                    // タグ選択ボタン
                    Button {
                        showTagSelection = true
                    } label: {
                        Image(systemName: "tag")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)

                    // 記録ボタン
                    Button {
                        recordMood()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                }
            }
            .navigationTitle("Nami")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTagSelection) {
                WatchTagSelectionView(
                    connector: connector,
                    selectedTags: $selectedTags
                )
            }
            .onAppear {
                maxScore = WatchConstants.sharedUserDefaults.integer(forKey: WatchConstants.scoreRangeMaxKey)
                if maxScore == 0 { maxScore = 10 }
                selectedScore = Double(maxScore) / 2.0
            }
        }
    }

    /// 気分を記録する
    private func recordMood() {
        let score = Int(selectedScore)
        connector.recordMood(
            score: score,
            maxScore: maxScore,
            tags: Array(selectedTags)
        )

        // フィードバック表示
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showRecordedFeedback = true
        }

        // リセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showRecordedFeedback = false
                selectedTags.removeAll()
            }
        }
    }
}
