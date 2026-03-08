//
//  TagManagementView.swift
//  Nami
//
//  感情タグ管理画面 - タグの一覧、追加、削除
//  カテゴリの追加/削除、プレミアム失効時のタグ非アクティブ化選択UI
//

import SwiftData
import SwiftUI

// MARK: - Tag group representation

/// Display group for tags (built-in category or custom TagCategory)
struct TagGroupInfo: Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let builtInCategory: EmotionTagCategory?
    let customCategory: TagCategory?
    let tags: [EmotionTag]

    var isBuiltIn: Bool {
        builtInCategory != nil
    }
}

// MARK: - TagManagementView

/// 感情タグ管理画面
struct TagManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]
    @Query(sort: \TagCategory.sortOrder) private var customCategories: [TagCategory]

    @State private var showAddSheet = false
    @State private var showAddCategorySheet = false
    @State private var categoryToDelete: TagGroupInfo?
    @State private var tagToDelete: EmotionTag?

    /// アクティブなカスタムタグの数
    private var activeCustomTagCount: Int {
        allTags.filter { !$0.isDefault && $0.isActive }.count
    }

    /// カテゴリ別にグループ化したタグ（動的）
    private var groupedTags: [TagGroupInfo] {
        var groups: [TagGroupInfo] = []

        // 1. Built-in categories (show only if they have tags)
        for cat in EmotionTagCategory.builtIn {
            let tags = allTags.filter { $0.category == cat }
            if !tags.isEmpty {
                groups.append(TagGroupInfo(
                    id: cat.rawValue,
                    displayName: cat.displayName,
                    icon: cat.icon,
                    builtInCategory: cat,
                    customCategory: nil,
                    tags: tags
                ))
            }
        }

        // 2. Custom categories (always show, even if empty)
        for tc in customCategories {
            let tags = allTags.filter { $0.category == .custom && $0.customCategoryId == tc.id }
            groups.append(TagGroupInfo(
                id: tc.id.uuidString,
                displayName: tc.name,
                icon: tc.icon,
                builtInCategory: nil,
                customCategory: tc,
                tags: tags
            ))
        }

        // 3. Uncategorized custom tags (nil OR orphaned categoryId)
        let knownCategoryIds = Set(customCategories.map(\.id))
        let uncategorized = allTags.filter {
            $0.category == .custom &&
                ($0.customCategoryId == nil || !knownCategoryIds.contains($0.customCategoryId!))
        }
        if !uncategorized.isEmpty {
            groups.append(TagGroupInfo(
                id: "custom_uncategorized",
                displayName: EmotionTagCategory.custom.displayName,
                icon: EmotionTagCategory.custom.icon,
                builtInCategory: .custom,
                customCategory: nil,
                tags: uncategorized
            ))
        }

        return groups
    }

    var body: some View {
        let colors = themeManager.colors

        ZStack {
            colors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            List {
                // Add tag / add category — top of list for easy access
                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("タグを追加", systemImage: "plus.circle.fill")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(colors.accent)
                    }
                    .disabled(!premiumManager.canCreateCustomTag(currentCount: activeCustomTagCount))

                    Button {
                        showAddCategorySheet = true
                    } label: {
                        Label("カテゴリを追加", systemImage: "folder.badge.plus")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(colors.accent)
                    }
                } footer: {
                    if premiumManager.isPremium {
                        Text("プレミアムプラン: 無制限にカスタムタグを作成できます。")
                    } else {
                        let remaining = premiumManager.remainingCustomTags(currentCount: activeCustomTagCount)
                        if remaining > 0 {
                            Text("あと\(remaining)個のカスタムタグを作成できます。")
                        } else {
                            Text("カスタムタグの上限に達しました。プレミアムプランで無制限に。")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Premium expiry banner
                if premiumManager.needsTagDeactivation(activeCustomTagCount: activeCustomTagCount) {
                    tagDeactivationBanner(colors: colors)
                }

                // Tag groups
                ForEach(groupedTags) { group in
                    Section {
                        ForEach(group.tags, id: \.id) { tag in
                            tagRow(tag: tag, colors: colors)
                        }
                        .onDelete { indexSet in
                            deleteTags(in: group.tags, at: indexSet)
                        }
                    } header: {
                        categoryHeader(group: group, colors: colors)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("タグを管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddTagSheet(
                themeColors: colors,
                customCategories: customCategories
            ) { name, category, customCategoryId in
                addTag(name: name, category: category, customCategoryId: customCategoryId)
            }
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(themeColors: colors) { name, icon in
                addCategory(name: name, icon: icon)
            }
        }
        .alert("タグを削除", isPresented: Binding(
            get: { tagToDelete != nil },
            set: { if !$0 { tagToDelete = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let tag = tagToDelete {
                    modelContext.delete(tag)
                    HapticManager.lightFeedback()
                    tagToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                tagToDelete = nil
            }
        } message: {
            if let tag = tagToDelete, tag.isDefault {
                Text("「\(tag.name)」はデフォルトタグです。削除しても過去の記録には影響しません。")
            } else if let tag = tagToDelete {
                Text("「\(tag.name)」を削除しますか？過去の記録には影響しません。")
            }
        }
        .alert("カテゴリを削除", isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let group = categoryToDelete {
                    deleteCategory(group: group)
                    HapticManager.lightFeedback()
                    categoryToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            if let group = categoryToDelete {
                Text("「\(group.displayName)」カテゴリと配下の\(group.tags.count)個のタグを全て削除します。過去の記録には影響しません。")
            }
        }
    }

    // MARK: - Category header with delete button

    private func categoryHeader(group: TagGroupInfo, colors _: ThemeColors) -> some View {
        HStack(spacing: 6) {
            Image(systemName: group.icon)
                .font(.caption)
            Text(group.displayName)

            Spacer()

            // Only show delete for custom categories (not built-in or uncategorized)
            if group.customCategory != nil {
                Button {
                    categoryToDelete = group
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("「\(group.displayName)」カテゴリを削除")
            }
        }
    }

    // MARK: - Tag deactivation banner

    private func tagDeactivationBanner(colors: ThemeColors) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("タグの整理が必要です")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }

                Text("プレミアムプランが終了しました。アクティブにするカスタムタグを\(premiumManager.freeCustomTagLimit)個まで選んでください。残りは「休止中」になりますが、データは保持されます。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("アクティブ: \(activeCustomTagCount)/\(premiumManager.freeCustomTagLimit)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(activeCustomTagCount > premiumManager.freeCustomTagLimit ? .red : colors.accent)
                    Spacer()
                    Text("タグをタップして切替")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Tag row
    @ViewBuilder
    private func tagRow(tag: EmotionTag, colors: ThemeColors) -> some View {
        let needsDeactivation = premiumManager.needsTagDeactivation(activeCustomTagCount: activeCustomTagCount)
        let isCustom = !tag.isDefault

        HStack(spacing: 12) {
            Image(systemName: tag.icon)
                .font(.body)
                .foregroundStyle(tag.isActive ? colors.accent : .gray)
                .frame(width: 28)

            Text(tag.name)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(tag.isActive ? .primary : .secondary)

            Spacer()

            if tag.isDefault {
                Text("デフォルト")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.systemGray5)))
            } else if !tag.isActive {
                Text("休止中")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.gray))
            }
        }
        .opacity(tag.isActive ? 1.0 : 0.6)
        .contentShape(Rectangle())
        .onTapGesture {
            if needsDeactivation && isCustom {
                let currentCount = activeCustomTagCount
                withAnimation(.easeInOut(duration: 0.2)) {
                    if tag.isActive {
                        tag.isActive = false
                        HapticManager.lightFeedback()
                    } else if currentCount < premiumManager.freeCustomTagLimit {
                        tag.isActive = true
                        HapticManager.lightFeedback()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    /// Delete tags via swipe (with confirmation for default tags)
    private func deleteTags(in tags: [EmotionTag], at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            if tag.isDefault {
                tagToDelete = tag
            } else {
                modelContext.delete(tag)
                HapticManager.lightFeedback()
            }
        }
    }

    /// Delete a category and all its tags
    private func deleteCategory(group: TagGroupInfo) {
        for tag in group.tags {
            modelContext.delete(tag)
        }
        if let tc = group.customCategory {
            modelContext.delete(tc)
        }
    }

    /// Add a new tag
    private func addTag(name: String, category: EmotionTagCategory, customCategoryId: UUID?) {
        let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1
        let icon: String
        if let customCategoryId, let tc = customCategories.first(where: { $0.id == customCategoryId }) {
            icon = tc.icon
        } else if category == .custom {
            icon = "star.fill"
        } else {
            icon = category.icon
        }
        let tag = EmotionTag(
            name: name,
            category: category,
            icon: icon,
            isDefault: false,
            sortOrder: nextOrder,
            customCategoryId: customCategoryId
        )
        modelContext.insert(tag)
        HapticManager.lightFeedback()
    }

    /// Add a new custom category
    private func addCategory(name: String, icon: String) {
        let nextOrder = (customCategories.map(\.sortOrder).max() ?? 0) + 1
        let category = TagCategory(name: name, icon: icon, sortOrder: nextOrder)
        modelContext.insert(category)
        HapticManager.lightFeedback()
    }
}

// MARK: - TagDeactivationSheet

/// プレミアム失効時にアクティブなカスタムタグを選択するシート
struct TagDeactivationSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]

    private var customTags: [EmotionTag] {
        allTags.filter { !$0.isDefault }
    }

    private var activeCount: Int {
        customTags.filter(\.isActive).count
    }

    private var tagLimit: Int {
        premiumManager.freeCustomTagLimit
    }

    var body: some View {
        let colors = themeManager.colors

        NavigationStack {
            ZStack {
                colors.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.largeTitle)
                            .foregroundStyle(colors.accent)

                        Text("アクティブにするタグを選んでください")
                            .font(.system(.headline, design: .rounded))

                        Text("無料プランではカスタムタグ\(tagLimit)個まで利用できます。\n残りのタグは休止中になりますが、データは保持されます。")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("\(activeCount) / \(tagLimit)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(activeCount <= tagLimit ? colors.accent : .red)
                            .padding(.top, 4)
                    }
                    .padding()

                    List {
                        ForEach(customTags, id: \.id) { tag in
                            Button {
                                let currentCount = activeCount
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if tag.isActive {
                                        tag.isActive = false
                                    } else if currentCount < tagLimit {
                                        tag.isActive = true
                                    }
                                }
                                HapticManager.lightFeedback()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: tag.isActive ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(tag.isActive ? colors.accent : .gray)
                                        .font(.title3)

                                    Image(systemName: tag.icon)
                                        .font(.body)
                                        .foregroundStyle(tag.isActive ? colors.accent : .gray)
                                        .frame(width: 28)

                                    Text(tag.name)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(tag.isActive ? .primary : .secondary)

                                    Spacer()

                                    if !tag.isActive {
                                        Text("休止中")
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color.gray))
                                    }
                                }
                                .opacity(tag.isActive ? 1.0 : 0.6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollContentBackground(.hidden)

                    Button {
                        dismiss()
                    } label: {
                        Text("確定")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(activeCount <= tagLimit ? colors.accent : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(activeCount > tagLimit)
                    .padding()
                }
            }
            .navigationTitle("タグの整理")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(activeCount > tagLimit)
        }
    }
}

// MARK: - AddTagSheet

/// タグ追加シート（組み込み + カスタムカテゴリ対応）
struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    let themeColors: ThemeColors
    let customCategories: [TagCategory]
    let onAdd: (String, EmotionTagCategory, UUID?) -> Void

    @State private var tagName = ""
    @State private var selectedBuiltIn: EmotionTagCategory? = .custom
    @State private var selectedCustomCategoryId: UUID?
    @FocusState private var isNameFocused: Bool
    @Query private var existingTags: [EmotionTag]

    private var isDuplicate: Bool {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return existingTags.contains { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
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
                    // Built-in categories
                    ForEach(EmotionTagCategory.builtIn) { category in
                        Button {
                            selectedBuiltIn = category
                            selectedCustomCategoryId = nil
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(themeColors.accent)
                                    .frame(width: 24)
                                Text(category.displayName)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedBuiltIn == category && selectedCustomCategoryId == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(themeColors.accent)
                                }
                            }
                        }
                    }

                    // "カスタム" (uncategorized)
                    Button {
                        selectedBuiltIn = .custom
                        selectedCustomCategoryId = nil
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: EmotionTagCategory.custom.icon)
                                .foregroundStyle(themeColors.accent)
                                .frame(width: 24)
                            Text(EmotionTagCategory.custom.displayName)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedBuiltIn == .custom && selectedCustomCategoryId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(themeColors.accent)
                            }
                        }
                    }

                    // Custom TagCategory entries
                    ForEach(customCategories, id: \.id) { tc in
                        Button {
                            selectedBuiltIn = nil
                            selectedCustomCategoryId = tc.id
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tc.icon)
                                    .foregroundStyle(themeColors.accent)
                                    .frame(width: 24)
                                Text(tc.name)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCustomCategoryId == tc.id {
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
                        guard !trimmed.isEmpty, !isDuplicate else { return }
                        if let customId = selectedCustomCategoryId {
                            onAdd(trimmed, .custom, customId)
                        } else {
                            onAdd(trimmed, selectedBuiltIn ?? .custom, nil)
                        }
                        dismiss()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - AddCategorySheet

/// カテゴリ追加シート
struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let themeColors: ThemeColors
    let onAdd: (String, String) -> Void

    @State private var categoryName = ""
    @State private var selectedIcon = "folder.fill"
    @FocusState private var isNameFocused: Bool
    @Query private var existingCategories: [TagCategory]

    private static let iconOptions = [
        "folder.fill", "heart.fill", "star.fill", "flag.fill",
        "bookmark.fill", "tag.fill", "bolt.fill", "flame.fill",
        "drop.fill", "leaf.fill", "pawprint.fill", "globe.americas.fill",
        "house.fill", "building.2.fill", "car.fill", "airplane",
        "cup.and.saucer.fill", "fork.knife", "figure.run", "sportscourt.fill",
        "music.note", "book.fill", "pencil.and.outline", "paintbrush.fill",
        "camera.fill", "gamecontroller.fill", "tv.fill", "headphones",
        "moon.fill", "sun.max.fill", "cloud.fill", "snowflake",
    ]

    private var isDuplicate: Bool {
        let trimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existsInBuiltIn = EmotionTagCategory.builtIn.contains {
            $0.displayName.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        let existsInCustom = existingCategories.contains {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        return existsInBuiltIn || existsInCustom
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("カテゴリ名", text: $categoryName)
                        .font(.system(.body, design: .rounded))
                        .focused($isNameFocused)

                    if isDuplicate {
                        Text("同じ名前のカテゴリが既に存在します")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("名前")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(Self.iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? themeColors.accent.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? themeColors.accent : Color.clear, lineWidth: 2)
                                    )
                                    .foregroundStyle(selectedIcon == icon ? themeColors.accent : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("アイコン")
                }
            }
            .navigationTitle("カテゴリを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let trimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !isDuplicate else { return }
                        onAdd(trimmed, selectedIcon)
                        dismiss()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        TagManagementView()
    }
    .modelContainer(for: [MoodEntry.self, EmotionTag.self, TagCategory.self], inMemory: true)
    .environment(\.themeManager, ThemeManager())
    .environment(\.premiumManager, PremiumManager())
}
