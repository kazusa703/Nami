//
//  RecordingSheet.swift
//  Nami
//
//  統合記録シート（メモ・写真・ボイスメモ）
//

import SwiftUI
import SwiftData
import PhotosUI

/// 記録シートのタブ
enum RecordingTab: String, CaseIterable {
    case memo = "メモ"
    case tags = "タグ"
    case photo = "写真"
    case voice = "ボイス"

    var iconName: String {
        switch self {
        case .memo: return "pencil"
        case .tags: return "tag"
        case .photo: return "camera"
        case .voice: return "mic"
        }
    }
}

/// 統合記録シート
/// メモ入力、写真撮影、ボイスメモ録音を1つのシートで提供する
/// isEditing=true の場合、ウィジェット記録の編集モードで動作する
struct RecordingSheet: View {
    let score: Int
    let maxScore: Int
    let themeColors: ThemeColors
    /// 編集モード（ウィジェット記録の補完時にtrue）
    var isEditing: Bool = false
    /// 編集モード時の初期メモ
    var initialMemo: String = ""
    /// 編集モード時の初期タグ
    var initialTags: Set<String> = []
    let onSave: (_ memo: String, _ photo: UIImage?, _ voiceMemoURL: URL?, _ tags: [String]) -> Void
    let onSkip: () -> Void

    @State private var selectedTab: RecordingTab = .memo
    @State private var memoText = ""
    @State private var selectedTags: Set<String> = []
    @State private var capturedPhoto: UIImage?
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var recorder = VoiceRecorderManager()
    @FocusState private var isMemoFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    /// シートの表示サイズ（初期値は中サイズ）
    @State private var sheetDetent: PresentationDetent = .medium

    /// メモの最大文字数
    private let maxLength = 100

    /// クイックメモテンプレート
    private let templates = [
        "仕事がんばった", "リラックスした", "疲れた",
        "楽しかった", "不安だった", "感謝"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // スコア表示
                scoreHeader

                // タブセレクタ
                tabSelector

                // タブコンテンツ
                TabView(selection: $selectedTab) {
                    memoTab.tag(RecordingTab.memo)
                    tagsTab.tag(RecordingTab.tags)
                    photoTab.tag(RecordingTab.photo)
                    voiceTab.tag(RecordingTab.voice)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // ボタン群
                actionButtons
            }
            .navigationTitle("詳細を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        cleanupAndSkip()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            // 編集モード時は初期値を設定
            if isEditing {
                memoText = initialMemo
                selectedTags = initialTags
            }
            // メモ欄に自動フォーカス
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isMemoFocused = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            PhotoCaptureView(
                onCapture: { image in
                    capturedPhoto = image
                    showCamera = false
                    HapticManager.lightFeedback()
                },
                onCancel: {
                    showCamera = false
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - スコアヘッダー

    private var scoreHeader: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if isEditing {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(.caption))
                        .foregroundStyle(.orange)
                }
                Text("\(score)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColors.color(for: score, maxScore: maxScore))
                Text("/ \(maxScore)")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(isEditing ? "ウィジェットから記録 — メモやタグを追加できます" : "記録しました — メモやタグを追加できます")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - タブセレクタ

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(RecordingTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.lightFeedback()
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.system(.caption, design: .rounded, weight: .medium))

                            // インジケータ（データがある場合）
                            if tab == .tags && !selectedTags.isEmpty {
                                Text("\(selectedTags.count)")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Circle().fill(themeColors.accent))
                            } else if hasData(for: tab) {
                                Circle()
                                    .fill(themeColors.accent)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? themeColors.accent : .secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? themeColors.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - メモタブ

    private var memoTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // テンプレートチップ
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
                    TextField("今の気持ちをひとこと...", text: $memoText, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(3...5)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        )
                        .focused($isMemoFocused)
                        .onChange(of: memoText) { _, newValue in
                            if newValue.count > maxLength {
                                memoText = String(newValue.prefix(maxLength))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(memoText.count)/\(maxLength)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - 写真タブ

    private var photoTab: some View {
        VStack(spacing: 16) {
            if let photo = capturedPhoto {
                // プレビュー
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                HStack(spacing: 20) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("撮り直し", systemImage: "camera")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(themeColors.accent)
                    }

                    Button {
                        capturedPhoto = nil
                        HapticManager.lightFeedback()
                    } label: {
                        Label("削除", systemImage: "trash")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Spacer()

                // 写真選択ボタン群
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 52))
                        .foregroundStyle(themeColors.accent.opacity(0.4))

                    // カメラボタン
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                            HapticManager.lightFeedback()
                        } label: {
                            Label("撮影する", systemImage: "camera.fill")
                                .font(.system(.headline, design: .rounded))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(themeColors.accent)
                                )
                                .foregroundStyle(.white)
                        }
                    }

                    // ライブラリから選択
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("ライブラリから選択", systemImage: "photo.stack")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(themeColors.accent)
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                capturedPhoto = image
                                HapticManager.lightFeedback()
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.top, 12)
    }

    // MARK: - タグタブ

    private var tagsTab: some View {
        TagSelectionView(
            selectedTags: $selectedTags,
            themeColors: themeColors
        )
    }

    // MARK: - ボイスタブ

    private var voiceTab: some View {
        VStack {
            Spacer()
            VoiceRecorderView(themeColors: themeColors, recorder: recorder)
            Spacer()
        }
    }

    // MARK: - ボタン群

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 保存ボタン
            Button {
                onSave(memoText, capturedPhoto, recorder.recordedURL, Array(selectedTags))
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

            // 詳細なしで閉じる / キャンセル
            Button {
                cleanupAndSkip()
            } label: {
                Text(isEditing ? "キャンセル" : "詳細なしで閉じる")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    // MARK: - ヘルパー

    /// テンプレートをテキストフィールドに挿入する
    private func insertTemplate(_ template: String) {
        if memoText.isEmpty {
            memoText = template
        } else {
            let newText = memoText + " " + template
            memoText = String(newText.prefix(maxLength))
        }
        HapticManager.lightFeedback()
    }

    /// 指定タブにデータがあるかチェック
    private func hasData(for tab: RecordingTab) -> Bool {
        switch tab {
        case .memo: return !memoText.isEmpty
        case .tags: return !selectedTags.isEmpty
        case .photo: return capturedPhoto != nil
        case .voice: return recorder.recordedURL != nil && recorder.state != .idle
        }
    }

    /// クリーンアップしてスキップ
    private func cleanupAndSkip() {
        recorder.deleteRecording()
        onSkip()
    }
}

#Preview {
    Text("")
        .sheet(isPresented: .constant(true)) {
            RecordingSheet(
                score: 7,
                maxScore: 10,
                themeColors: .ocean,
                onSave: { _, _, _, _ in },
                onSkip: { }
            )
        }
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
}
