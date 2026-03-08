//
//  TagSelectionView.swift
//  Nami
//
//  感情タグ選択ビュー（記録シートのタグタブ用）
//

import SwiftData
import SwiftUI

/// 感情タグ選択ビュー
/// カテゴリ別にタグを表示し、タップで選択/解除する
struct TagSelectionView: View {
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]
    @Query(sort: \TagCategory.sortOrder) private var customCategories: [TagCategory]
    @Binding var selectedTags: Set<String>
    let themeColors: ThemeColors

    /// カテゴリ別にグループ化したタグ（アクティブなもののみ、動的カテゴリ対応）
    private var groupedTags: [TagGroupInfo] {
        var groups: [TagGroupInfo] = []

        // 1. Built-in categories
        for cat in EmotionTagCategory.builtIn {
            let tags = allTags.filter { $0.category == cat && $0.isActive }
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

        // 2. Custom TagCategory groups
        for tc in customCategories {
            let tags = allTags.filter { $0.category == .custom && $0.customCategoryId == tc.id && $0.isActive }
            if !tags.isEmpty {
                groups.append(TagGroupInfo(
                    id: tc.id.uuidString,
                    displayName: tc.name,
                    icon: tc.icon,
                    builtInCategory: nil,
                    customCategory: tc,
                    tags: tags
                ))
            }
        }

        // 3. Uncategorized custom tags (nil OR orphaned categoryId)
        let knownCategoryIds = Set(customCategories.map(\.id))
        let uncategorized = allTags.filter {
            $0.category == .custom &&
                ($0.customCategoryId == nil || !knownCategoryIds.contains($0.customCategoryId!)) &&
                $0.isActive
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if groupedTags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 36))
                            .foregroundStyle(themeColors.accent.opacity(0.3))
                        Text("タグがまだありません")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("スキップしてOK！\n設定 > タグを管理 からタグを追加できます")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }

                ForEach(groupedTags) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Category header
                        HStack(spacing: 6) {
                            Image(systemName: group.icon)
                                .font(.caption)
                                .foregroundStyle(themeColors.accent)
                            Text(group.displayName)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityAddTraits(.isHeader)

                        // Tag chips (FlowLayout)
                        FlowLayout(spacing: 8) {
                            ForEach(group.tags, id: \.id) { tag in
                                tagChip(tag: tag)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .onAppear {
            let activeNames = Set(allTags.filter(\.isActive).map(\.name))
            let inactive = selectedTags.subtracting(activeNames)
            if !inactive.isEmpty {
                selectedTags.subtract(inactive)
            }
        }
    }

    /// 個別のタグチップ
    @ViewBuilder
    private func tagChip(tag: EmotionTag) -> some View {
        let isSelected = selectedTags.contains(tag.name)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedTags.remove(tag.name)
                } else {
                    selectedTags.insert(tag.name)
                }
            }
            HapticManager.lightFeedback()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tag.icon)
                    .font(.system(size: 11))
                Text(tag.name)
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? themeColors.accent : themeColors.accent.opacity(0.08))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tag.name)タグ\(isSelected ? "（選択中）" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    TagSelectionView(
        selectedTags: .constant(["嬉しい", "仕事"]),
        themeColors: .ocean
    )
    .modelContainer(for: [EmotionTag.self, TagCategory.self], inMemory: true)
}
