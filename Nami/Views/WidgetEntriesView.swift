//
//  WidgetEntriesView.swift
//  Nami
//
//  ウィジェット記録の管理画面
//  ウィジェットから記録されたエントリの一覧・編集・削除を提供する
//

import SwiftUI
import SwiftData

/// ウィジェット記録管理画面のフィルター
enum WidgetEntryFilter: String, CaseIterable {
    case needsDetails = "未補完"
    case all = "すべて"
}

/// ウィジェット記録管理画面
struct WidgetEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager

    @Query(
        filter: #Predicate<MoodEntry> { $0.source == "widget" },
        sort: \MoodEntry.createdAt,
        order: .reverse
    ) private var widgetEntries: [MoodEntry]

    @State private var filter: WidgetEntryFilter = .needsDetails
    @State private var editingEntry: MoodEntry?

    /// フィルター適用後のエントリ
    private var filteredEntries: [MoodEntry] {
        switch filter {
        case .needsDetails:
            return widgetEntries.filter(\.needsEnrichment)
        case .all:
            return widgetEntries
        }
    }

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // フィルターPicker
                Picker("フィルター", selection: $filter) {
                    ForEach(WidgetEntryFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if filteredEntries.isEmpty {
                    emptyState(colors: colors)
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            entryRow(entry: entry, colors: colors)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingEntry = entry
                                }
                        }
                        .onDelete { indexSet in
                            deleteEntries(at: indexSet)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("ウィジェット記録")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEntry) { entry in
            RecordingSheet(
                score: entry.score,
                maxScore: entry.maxScore,
                themeColors: themeManager.colors,
                isEditing: true,
                initialMemo: entry.memo ?? "",
                initialTags: Set(entry.tags),
                onSave: { memo, photo, voiceMemoURL, tags in
                    // 既存エントリを更新
                    if !memo.isEmpty {
                        entry.memo = String(memo.prefix(100))
                    }
                    if let photo {
                        entry.photoPath = MediaManager.savePhoto(photo)
                    }
                    if let voiceMemoURL {
                        entry.voiceMemoPath = MediaManager.saveVoiceMemo(from: voiceMemoURL)
                    }
                    entry.tags = tags
                    editingEntry = nil
                },
                onSkip: {
                    editingEntry = nil
                }
            )
        }
    }

    // MARK: - エントリ行

    @ViewBuilder
    private func entryRow(entry: MoodEntry, colors: ThemeColors) -> some View {
        HStack(spacing: 12) {
            // スコア表示
            Text("\(entry.score)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(colors.color(for: entry.score, maxScore: entry.maxScore))
                .frame(width: 36)

            // 詳細
            VStack(alignment: .leading, spacing: 4) {
                // 日時
                Text(entry.createdAt, format: .dateTime.month(.defaultDigits).day(.defaultDigits).hour().minute())
                    .font(.system(.subheadline, design: .rounded, weight: .medium))

                // メモ・タグプレビュー
                HStack(spacing: 6) {
                    if let memo = entry.memo, !memo.isEmpty {
                        Text(memo)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !entry.tags.isEmpty {
                        Text(entry.tags.prefix(2).joined(separator: ", "))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(colors.accent.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 補完ステータスアイコン
            if entry.needsEnrichment {
                Image(systemName: "pencil.circle")
                    .font(.system(.body))
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.body))
                    .foregroundStyle(.green)
            }

            // ウィジェットアイコン
            Image(systemName: "square.grid.2x2")
                .font(.system(.caption))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 空状態

    @ViewBuilder
    private func emptyState(colors: ThemeColors) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: filter == .needsDetails ? "checkmark.circle" : "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(colors.accent.opacity(0.3))

            Text(filter == .needsDetails ? "補完が必要なエントリはありません" : "ウィジェットからの記録はありません")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)

            if filter == .all {
                Text("ホーム画面のウィジェットからスコアボタンをタップして記録できます")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - 削除

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = filteredEntries[index]
            // 写真・ボイスメモファイルを削除
            if let photoPath = entry.photoPath {
                try? FileManager.default.removeItem(atPath: photoPath)
            }
            if let voicePath = entry.voiceMemoPath {
                try? FileManager.default.removeItem(atPath: voicePath)
            }
            modelContext.delete(entry)
        }
        HapticManager.lightFeedback()
    }
}

#Preview {
    NavigationStack {
        WidgetEntriesView()
    }
    .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
    .environment(\.themeManager, ThemeManager())
}
