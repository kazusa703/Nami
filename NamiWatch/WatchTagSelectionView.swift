//
//  WatchTagSelectionView.swift
//  NamiWatch
//
//  Watch用タグ選択画面 - フラットリスト + チェックマーク
//

import SwiftUI

/// Watch用のタグ選択画面
/// iPhone側から受信したタグ一覧をリスト表示し、チェックマークで選択する
struct WatchTagSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let connector: WatchPhoneConnector
    @Binding var selectedTags: Set<String>

    var body: some View {
        NavigationStack {
            List {
                if connector.availableTags.isEmpty {
                    Section {
                        Text("iPhoneアプリでタグを設定してください")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(connector.availableTags) { tag in
                        Button {
                            toggleTag(tag.name)
                        } label: {
                            HStack {
                                Image(systemName: tag.icon)
                                    .font(.caption)
                                    .frame(width: 20)

                                Text(tag.name)
                                    .font(.system(.body, design: .rounded))

                                Spacer()

                                if selectedTags.contains(tag.name) {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// タグの選択/解除を切り替える
    private func toggleTag(_ name: String) {
        if selectedTags.contains(name) {
            selectedTags.remove(name)
        } else {
            selectedTags.insert(name)
        }
    }
}
