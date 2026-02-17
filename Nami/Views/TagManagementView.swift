//
//  TagManagementView.swift
//  Nami
//
//  感情タグ管理画面 - デフォルト/カスタムタグの一覧、追加、削除
//

import SwiftUI
import SwiftData

/// 感情タグ管理画面
struct TagManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]

    /// 新規タグ追加シート表示フラグ
    @State private var showAddSheet = false

    /// カスタムタグの数
    private var customTagCount: Int {
        allTags.filter { !$0.isDefault }.count
    }

    /// カテゴリ別にグループ化したタグ
    private var groupedTags: [(category: EmotionTagCategory, tags: [EmotionTag])] {
        let displayOrder: [EmotionTagCategory] = [.positive, .negative, .factor, .custom]
        return displayOrder.compactMap { category in
            let tags = allTags.filter { $0.category == category }
            return tags.isEmpty ? nil : (category, tags)
        }
    }

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            List {
                // カテゴリ別タグ一覧
                ForEach(groupedTags, id: \.category) { group in
                    Section {
                        ForEach(group.tags, id: \.id) { tag in
                            tagRow(tag: tag, colors: colors)
                        }
                        .onDelete { indexSet in
                            deleteCustomTags(in: group.tags, at: indexSet)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: group.category.icon)
                                .font(.caption)
                            Text(group.category.displayName)
                        }
                    }
                }

                // カスタムタグ追加セクション
                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("カスタムタグを追加", systemImage: "plus.circle.fill")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(colors.accent)
                    }
                    .disabled(!premiumManager.canCreateCustomTag(currentCount: customTagCount))
                } footer: {
                    if premiumManager.isPremium {
                        Text("プレミアムプラン: 無制限にカスタムタグを作成できます。")
                    } else {
                        let remaining = premiumManager.remainingCustomTags(currentCount: customTagCount)
                        if remaining > 0 {
                            Text("あと\(remaining)個のカスタムタグを作成できます。")
                        } else {
                            Text("カスタムタグの上限に達しました。プレミアムプランで無制限に。")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("感情タグ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddTagSheet(themeColors: colors) { name, category in
                addCustomTag(name: name, category: category)
            }
        }
    }

    /// タグ行
    @ViewBuilder
    private func tagRow(tag: EmotionTag, colors: ThemeColors) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tag.icon)
                .font(.body)
                .foregroundStyle(colors.accent)
                .frame(width: 28)

            Text(tag.name)
                .font(.system(.body, design: .rounded))

            Spacer()

            if tag.isDefault {
                Text("デフォルト")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
        }
        .deleteDisabled(tag.isDefault) // デフォルトタグは削除不可
    }

    /// カスタムタグのスワイプ削除
    private func deleteCustomTags(in tags: [EmotionTag], at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            if !tag.isDefault {
                modelContext.delete(tag)
            }
        }
    }

    /// カスタムタグを追加する
    private func addCustomTag(name: String, category: EmotionTagCategory) {
        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1
        let tag = EmotionTag(
            name: name,
            category: category,
            icon: category == .custom ? "star.fill" : category.icon,
            isDefault: false,
            sortOrder: nextOrder
        )
        modelContext.insert(tag)
        HapticManager.lightFeedback()
    }
}

// MARK: - カスタムタグ追加シート

/// カスタムタグ追加シート
struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    let themeColors: ThemeColors
    let onAdd: (String, EmotionTagCategory) -> Void

    @State private var tagName = ""
    @State private var selectedCategory: EmotionTagCategory = .custom
    @FocusState private var isNameFocused: Bool
    @Query private var existingTags: [EmotionTag]

    /// 選択可能なカテゴリ（カスタム以外も選択可）
    private let categories: [EmotionTagCategory] = [.positive, .negative, .factor, .custom]

    /// 入力名が既存タグと重複しているか
    private var isDuplicate: Bool {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return existingTags.contains { $0.name == trimmed }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タグ名", text: $tagName)
                        .font(.system(.body, design: .rounded))
                        .focused($isNameFocused)

                    if isDuplicate {
                        Text("同じ名前のタグが既に存在します")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("名前")
                }

                Section {
                    ForEach(categories) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(themeColors.accent)
                                    .frame(width: 24)
                                Text(category.displayName)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(themeColors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("カテゴリ")
                }
            }
            .navigationTitle("タグを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !isDuplicate {
                            onAdd(trimmed, selectedCategory)
                            dismiss()
                        }
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        TagManagementView()
    }
    .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
    .environment(\.themeManager, ThemeManager())
    .environment(\.premiumManager, PremiumManager())
}
