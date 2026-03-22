//
//  TagManagementView.swift
//  Nami
//
//  タグ管理画面 - デフォルト/カスタムタグの一覧、追加、削除、並び替え
//

import SwiftUI
import SwiftData

/// タグ管理画面
struct TagManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]

    /// 新規タグ追加シート表示フラグ
    @State private var showAddSheet = false
    /// 並び替えモード
    @State private var isReordering = false

    /// カスタムタグの数
    private var customTagCount: Int {
        allTags.filter { !$0.isDefault }.count
    }

    /// カテゴリ別にグループ化したタグ
    private var groupedTags: [(category: EmotionTagCategory, tags: [EmotionTag])] {
        let displayOrder: [EmotionTagCategory] = [.positive, .negative, .factor, .location, .activity, .social, .custom]
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
                // Category-grouped tag list
                ForEach(groupedTags, id: \.category) { group in
                    Section {
                        ForEach(group.tags, id: \.id) { tag in
                            tagRow(tag: tag, colors: colors)
                        }
                        .onDelete { indexSet in
                            deleteCustomTags(in: group.tags, at: indexSet)
                        }
                        .onMove { source, destination in
                            moveCustomTags(in: group.category, from: source, to: destination)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: group.category.icon)
                                .font(.caption)
                            Text(group.category.displayName)
                            Spacer()
                            Text("\(group.tags.count)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Add custom tag section
                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label(String(localized: "カスタムタグを追加"), systemImage: "plus.circle.fill")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(colors.accent)
                    }
                    .disabled(!premiumManager.canCreateCustomTag(currentCount: customTagCount))
                } footer: {
                    if premiumManager.isPremium {
                        Text(String(localized: "プレミアムプラン: 無制限にカスタムタグを作成できます。"))
                    } else {
                        let remaining = premiumManager.remainingCustomTags(currentCount: customTagCount)
                        if remaining > 0 {
                            Text(String(localized: "あと\(remaining)個のカスタムタグを作成できます。"))
                        } else {
                            Text(String(localized: "カスタムタグの上限に達しました。プレミアムプランで無制限に。"))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        }
        .navigationTitle(String(localized: "タグ"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { isReordering.toggle() }
                } label: {
                    Text(isReordering ? String(localized: "完了") : String(localized: "並び替え"))
                        .font(.system(.body, design: .rounded))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTagSheet(themeColors: colors) { name, category in
                addCustomTag(name: name, category: category)
            }
        }
    }

    /// Tag row
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
                Text(String(localized: "デフォルト"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
        }
        .deleteDisabled(tag.isDefault)
        .moveDisabled(tag.isDefault)
    }

    /// Delete custom tags by swipe
    private func deleteCustomTags(in tags: [EmotionTag], at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            if !tag.isDefault {
                modelContext.delete(tag)
            }
        }
    }

    /// Move tags within a category
    private func moveCustomTags(in category: EmotionTagCategory, from source: IndexSet, to destination: Int) {
        var categoryTags = allTags.filter { $0.category == category }
        categoryTags.move(fromOffsets: source, toOffset: destination)
        // Update sort order for all tags in this category
        for (index, tag) in categoryTags.enumerated() {
            tag.sortOrder = category.sortIndex * 1000 + index
        }
        HapticManager.lightFeedback()
    }

    /// Add a custom tag
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

// MARK: - Tag Add Sheet (with preview)

/// Enhanced tag add sheet with live preview
struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    let themeColors: ThemeColors
    let onAdd: (String, EmotionTagCategory) -> Void

    @State private var tagName = ""
    @State private var selectedCategory: EmotionTagCategory = .custom
    @FocusState private var isNameFocused: Bool
    @Query private var existingTags: [EmotionTag]

    /// All selectable categories
    private let categories: [EmotionTagCategory] = [.positive, .negative, .factor, .location, .activity, .social, .custom]

    /// Check for duplicate name
    private var isDuplicate: Bool {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return existingTags.contains { $0.name == trimmed }
    }

    /// Trimmed name for convenience
    private var trimmedName: String {
        tagName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Icon for the tag being created
    private var previewIcon: String {
        selectedCategory == .custom ? "star.fill" : selectedCategory.icon
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Live preview card
                previewCard
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                Form {
                    // Name input
                    Section {
                        TextField(String(localized: "タグ名を入力"), text: $tagName)
                            .font(.system(.body, design: .rounded))
                            .focused($isNameFocused)

                        if isDuplicate {
                            Label(String(localized: "同じ名前のタグが既に存在します"), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.red)
                        }

                        // Filter existing tags by input
                        if !trimmedName.isEmpty && !isDuplicate {
                            let suggestions = existingTags.filter {
                                $0.name.localizedCaseInsensitiveContains(trimmedName) && $0.name != trimmedName
                            }.prefix(3)
                            if !suggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "似ているタグ:"))
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.tertiary)
                                    HStack(spacing: 6) {
                                        ForEach(Array(suggestions), id: \.id) { tag in
                                            Text(tag.name)
                                                .font(.system(.caption, design: .rounded))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(Color(.systemGray5)))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Category selection
                    Section {
                        ForEach(categories) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: category.icon)
                                        .foregroundStyle(themeColors.accent)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(category.displayName)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text(categoryDescription(category))
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(themeColors.accent)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "カテゴリ"))
                    }
                }
            }
            .navigationTitle(String(localized: "タグを追加"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "追加")) {
                        if !trimmedName.isEmpty && !isDuplicate {
                            onAdd(trimmedName, selectedCategory)
                            dismiss()
                        }
                    }
                    .disabled(trimmedName.isEmpty || isDuplicate)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Live preview of the tag being created
    @ViewBuilder
    private var previewCard: some View {
        VStack(spacing: 8) {
            Text(String(localized: "プレビュー"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                Image(systemName: previewIcon)
                    .font(.caption)
                Text(trimmedName.isEmpty ? String(localized: "タグ名") : trimmedName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeColors.accent.opacity(trimmedName.isEmpty ? 0.05 : 0.12))
            )
            .foregroundStyle(trimmedName.isEmpty ? themeColors.accent.opacity(0.3) : themeColors.accent)
            .animation(.easeInOut(duration: 0.2), value: trimmedName)
            .animation(.easeInOut(duration: 0.2), value: selectedCategory)
        }
    }

    /// Short description for each category
    private func categoryDescription(_ category: EmotionTagCategory) -> String {
        switch category {
        case .positive: return String(localized: "良い気分の時に")
        case .negative: return String(localized: "つらい気分の時に")
        case .factor: return String(localized: "気分に影響する要因")
        case .location: return String(localized: "今いる場所")
        case .activity: return String(localized: "今している活動")
        case .social: return String(localized: "一緒にいる人")
        case .custom: return String(localized: "自由なカテゴリ")
        }
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
