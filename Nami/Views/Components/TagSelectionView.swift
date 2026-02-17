//
//  TagSelectionView.swift
//  Nami
//
//  感情タグ選択ビュー（記録シートのタグタブ用）
//

import SwiftUI
import SwiftData

/// 感情タグ選択ビュー
/// カテゴリ別にタグを表示し、タップで選択/解除する
struct TagSelectionView: View {
    @Query(sort: \EmotionTag.sortOrder) private var allTags: [EmotionTag]
    @Binding var selectedTags: Set<String>
    let themeColors: ThemeColors

    /// カテゴリ別にグループ化したタグ
    private var groupedTags: [(category: EmotionTagCategory, tags: [EmotionTag])] {
        let displayOrder: [EmotionTagCategory] = [.positive, .negative, .factor, .custom]
        return displayOrder.compactMap { category in
            let tags = allTags.filter { $0.category == category }
            return tags.isEmpty ? nil : (category, tags)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groupedTags, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // カテゴリヘッダー
                        HStack(spacing: 6) {
                            Image(systemName: group.category.icon)
                                .font(.caption)
                                .foregroundStyle(themeColors.accent)
                            Text(group.category.displayName)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        // タグチップ（FlowLayout）
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
    }
}

#Preview {
    TagSelectionView(
        selectedTags: .constant(["嬉しい", "仕事"]),
        themeColors: .ocean
    )
    .modelContainer(for: [EmotionTag.self], inMemory: true)
}
