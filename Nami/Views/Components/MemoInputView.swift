//
//  MemoInputView.swift
//  Nami
//
//  メモ入力シート（新規記録・既存編集の両方に対応、テンプレート付き）
//

import SwiftData
import SwiftUI

/// メモ入力ビュー
/// 気分記録後の新規メモ追加、または既存エントリのメモ編集に使用する
struct MemoInputView: View {
    let score: Int
    let maxScore: Int
    let themeColors: ThemeColors
    /// 編集対象のエントリ（nilなら新規記録モード）
    let editingEntry: MoodEntry?
    let onSave: (String) -> Void
    let onSkip: () -> Void

    @State private var memoText = ""
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// メモの最大文字数
    private let maxLength = 100

    /// クイックメモテンプレート
    private let templates = [
        "仕事がんばった", "リラックスした", "疲れた",
        "楽しかった", "不安だった", "感謝",
    ]

    /// 編集モードかどうか
    private var isEditing: Bool {
        editingEntry != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // スコア表示
                VStack(spacing: 8) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColors.color(for: score, maxScore: maxScore))

                    Text(isEditing ? "メモを編集" : "記録しました")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                // テンプレートチップ（横スクロール）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates, id: \.self) { template in
                            Button {
                                insertTemplate(template)
                            } label: {
                                Text(template)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(themeColors.accent.opacity(0.1))
                                    )
                                    .foregroundStyle(themeColors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // メモ入力フィールド
                VStack(alignment: .leading, spacing: 8) {
                    Text("メモを追加（任意）")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("今の気持ちをひとこと...", text: $memoText, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(3 ... 5)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        )
                        .focused($isFocused)
                        .onChange(of: memoText) { _, newValue in
                            if newValue.count > maxLength {
                                memoText = String(newValue.prefix(maxLength))
                            }
                        }

                    // 文字数カウンター
                    HStack {
                        Spacer()
                        Text("\(memoText.count)/\(maxLength)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // ボタン群
                VStack(spacing: 12) {
                    // 保存ボタン（編集モードではメモが空でも保存可能 = メモ削除）
                    Button {
                        onSave(memoText)
                    } label: {
                        Text("保存")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeColors.accent)
                            )
                            .foregroundStyle(.white)
                    }

                    // スキップ/キャンセルボタン
                    Button {
                        onSkip()
                    } label: {
                        Text(isEditing ? "キャンセル" : "スキップ")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle(isEditing ? "メモ編集" : "メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSkip()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // 編集モードの場合、既存メモを読み込む
            if let entry = editingEntry, let memo = entry.memo {
                memoText = memo
            }
            isFocused = true
        }
    }

    /// テンプレートをテキストフィールドに挿入する
    private func insertTemplate(_ template: String) {
        if memoText.isEmpty {
            memoText = template
        } else {
            // 既存テキストの末尾に追加（文字数制限内）
            let newText = memoText + " " + template
            memoText = String(newText.prefix(maxLength))
        }
        HapticManager.lightFeedback()
    }
}

#Preview {
    Text("")
        .sheet(isPresented: .constant(true)) {
            MemoInputView(
                score: 7,
                maxScore: 10,
                themeColors: .ocean,
                editingEntry: nil,
                onSave: { _ in },
                onSkip: {}
            )
        }
}
