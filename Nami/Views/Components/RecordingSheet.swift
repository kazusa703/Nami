//
//  RecordingSheet.swift
//  Nami
//
//  統合記録シート（メモ・写真・ボイスメモ）
//

import PhotosUI
import SwiftData
import SwiftUI

/// 記録シートのタブ（タグ → メモ の2タブ）
enum RecordingTab: String, CaseIterable {
    case tags = "タグ"
    case memo = "メモ"

    var iconName: String {
        switch self {
        case .tags: return "tag"
        case .memo: return "pencil"
        }
    }
}

/// 統合記録シート
/// メモ入力、写真撮影、ボイスメモ録音を1つのシートで提供する
/// isEditing=true の場合、ウィジェット記録の編集モードで動作する
struct RecordingSheet: View {
    let score: Int
    let maxScore: Int
    var scoreRangeMin: Int = 1
    let themeColors: ThemeColors
    /// 編集モード（ウィジェット記録の補完時にtrue）
    var isEditing: Bool = false
    /// オンボーディング中かどうか（説明吹き出し表示用）
    var isOnboarding: Bool = false
    /// 編集モード時の初期メモ
    var initialMemo: String = ""
    /// 編集モード時の初期タグ
    var initialTags: Set<String> = []
    let onSave: (_ memo: String, _ photo: UIImage?, _ voiceMemoURL: URL?, _ tags: [String], _ energyLevel: Int?) -> Void
    let onSkip: () -> Void

    @State private var selectedTab: RecordingTab = .tags
    @State private var memoText = ""
    @State private var selectedTags: Set<String> = []
    @State private var capturedPhoto: UIImage?
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var recorder = VoiceRecorderManager()
    @FocusState private var isMemoFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    // Sheet always opens at full height
    @State private var showRecordingHelp = false
    @State private var showOnboardingTip = false
    @State private var showAddTagSheet = false
    @State private var showCustomTagTooltip = false
    /// Onboarding save ripple effect
    @State private var showSaveRipple = false
    @State private var rippleScale: CGFloat = 0.1
    @State private var rippleOpacity: Double = 0.5
    /// Onboarding step: 0=tag tip, 1=memo tip, 2=done
    @State private var onboardingGuideStep = 0

    /// メモの最大文字数
    private let maxLength = 100

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // スコア表示
                scoreHeader

                // タブセレクタ
                tabSelector

                // タブコンテンツ（タグ → メモ）
                TabView(selection: $selectedTab) {
                    tagsTab.tag(RecordingTab.tags)
                    memoTab.tag(RecordingTab.memo)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("詳細を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        cleanupAndSkip()
                    } label: {
                        Image(systemName: isEditing ? "xmark" : "chevron.left")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showRecordingHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            if isOnboarding {
                                triggerSaveWithRipple()
                            } else {
                                onSave(memoText, capturedPhoto, recorder.recordedURL, Array(selectedTags), nil)
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(themeColors.accent)
                        }
                        .disabled(showSaveRipple)
                    }
                }
            }
            .sheet(isPresented: $showRecordingHelp) {
                FeatureHelpSheet(title: String(localized: "記録の補足"), items: HelpContent.recordingHelp, accentColor: themeColors.accent)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Onboarding save ripple overlay
        .overlay {
            if showSaveRipple {
                ZStack {
                    Circle()
                        .fill(themeColors.accent.opacity(rippleOpacity))
                        .scaleEffect(rippleScale)
                        .frame(width: 80, height: 80)

                    if rippleScale > 2 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(themeColors.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
        .animation(.easeOut(duration: 0.6), value: rippleScale)
        .animation(.easeOut(duration: 0.6), value: rippleOpacity)
        // Full-screen onboarding overlay (covers everything including toolbar)
        .overlay {
            if isOnboarding && showOnboardingTip && onboardingGuideStep < 3 {
                ZStack {
                    // Dim background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 24) {
                        if onboardingGuideStep == 0 {
                            // Step 1: Tag explanation
                            VStack(spacing: 20) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(themeColors.accent)

                                Text(String(localized: "当てはまるタグをタップ"))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                VStack(spacing: 10) {
                                    Text(String(localized: "いくつでも選べます"))
                                        .font(.system(.title3, design: .rounded, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(String(localized: "タグを付けると統計タブの分析が\nより正確になります"))
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                    Text(String(localized: "何も選ばなくても大丈夫です"))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        onboardingGuideStep = 1
                                        selectedTab = .memo
                                    }
                                } label: {
                                    Text(String(localized: "次へ"))
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(themeColors.accent)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(.white))
                                }
                            }
                        } else if onboardingGuideStep == 1 {
                            // Step 2: Memo explanation
                            VStack(spacing: 20) {
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white)

                                Text(String(localized: "メモを残す"))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                VStack(spacing: 10) {
                                    Text(String(localized: "任意"))
                                        .font(.system(.title3, design: .rounded, weight: .medium))
                                        .foregroundStyle(.orange)
                                    Text(String(localized: "統計には反映されませんが\n何があったか後から見返せます"))
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }

                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        onboardingGuideStep = 2
                                    }
                                } label: {
                                    Text(String(localized: "次へ"))
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(themeColors.accent)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(.white))
                                }
                            }
                        } else {
                            // Step 3: Check button guide with arrow
                            VStack(spacing: 20) {
                                // Arrow pointing to top-right
                                HStack {
                                    Spacer()
                                    VStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(themeColors.accent)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.trailing, 40)
                                }

                                Text(String(localized: "右上の ✓ をタップして保存"))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(String(localized: "タグやメモを追加してもしなくても\nここから保存できます"))
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        onboardingGuideStep = 3
                                    }
                                } label: {
                                    Text(String(localized: "OK"))
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(themeColors.accent)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(Capsule().fill(.white))
                                }
                            }
                        }
                    }
                    .padding(32)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: onboardingGuideStep)
            }
        }
        .onAppear {
            // 編集モード時は初期値を設定
            if isEditing {
                memoText = initialMemo
                selectedTags = initialTags
            }
            // オンボーディング中は説明吹き出しを表示
            if isOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { showOnboardingTip = true }
                }
            }
            // メモタブに切り替えた時に自動フォーカス
            // (タグが最初のタブなので、メモフォーカスは遅延させない)
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
                    .foregroundStyle(themeColors.color(for: score, minScore: scoreRangeMin, maxScore: maxScore))
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

    // MARK: - タグタブ

    private var tagsTab: some View {
        ZStack(alignment: .bottom) {
            TagSelectionView(
                selectedTags: $selectedTags,
                themeColors: themeColors,
                onCreateTag: { _ in
                    showAddTagSheet = true
                }
            )

            // Onboarding tooltip: custom tag preview hint
            if isOnboarding && showCustomTagTooltip {
                TooltipView(
                    text: String(localized: "あとで自分だけのタグも自由に作れます ✨"),
                    accentColor: themeColors.accent,
                    tailEdge: .bottom
                )
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            if isOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        showCustomTagTooltip = true
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTagSheet) {
            AddTagSheet(themeColors: themeColors) { name, category, icon in
                // Save the new tag to SwiftData
                let nextOrder = (try? modelContext.fetchCount(FetchDescriptor<EmotionTag>())) ?? 0
                let tagIcon = icon ?? (category == .custom ? "star.fill" : category.icon)
                let tag = EmotionTag(
                    name: name,
                    category: category,
                    icon: tagIcon,
                    isDefault: false,
                    sortOrder: nextOrder
                )
                modelContext.insert(tag)
                UserDefaults.standard.set(true, forKey: "hasCreatedCustomTag")
                HapticManager.lightFeedback()
                // Auto-select the newly created tag
                selectedTags.insert(name)
            }
        }
    }

    // MARK: - Onboarding Save Ripple

    /// Trigger a subtle ripple animation, then call onSave after the effect
    private func triggerSaveWithRipple() {
        // Soft haptic
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()

        showSaveRipple = true
        rippleScale = 0.1
        rippleOpacity = 0.4

        // Expand ripple
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 8
            rippleOpacity = 0
        }

        // Checkmark appears briefly, then save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                rippleScale = 2.5 // Trigger checkmark visibility
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onSave(memoText, capturedPhoto, recorder.recordedURL, Array(selectedTags), nil)
        }
    }

    // MARK: - メモタブ（写真・ボイス統合）

    private var memoTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // メモ入力フィールド
                VStack(alignment: .leading, spacing: 8) {
                    TextField("今の気持ちをひとこと...", text: $memoText, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .lineLimit(3 ... 5)
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

                // 写真・ボイス添付エリア（メモタブ内に統合）
                Divider().padding(.horizontal)

                HStack(spacing: 16) {
                    // 写真添付
                    if let photo = capturedPhoto {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button {
                                capturedPhoto = nil
                                HapticManager.lightFeedback()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .offset(x: 4, y: -4)
                        }
                    } else {
                        Menu {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCamera = true
                                    HapticManager.lightFeedback()
                                } label: {
                                    Label(String(localized: "撮影"), systemImage: "camera.fill")
                                }
                            }
                            Button {
                                // PhotosPicker is triggered via the binding below
                            } label: {
                                Label(String(localized: "ライブラリ"), systemImage: "photo.stack")
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(.title3))
                                Text(String(localized: "写真"))
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .foregroundStyle(themeColors.accent.opacity(0.6))
                            .frame(width: 60, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeColors.accent.opacity(0.08))
                            )
                        }
                    }

                    // PhotosPicker (hidden, triggered by menu)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.stack")
                                .font(.system(.title3))
                            Text(String(localized: "選択"))
                                .font(.system(.caption2, design: .rounded))
                        }
                        .foregroundStyle(themeColors.accent.opacity(0.6))
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeColors.accent.opacity(0.08))
                        )
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data)
                            {
                                capturedPhoto = image
                                HapticManager.lightFeedback()
                            }
                        }
                    }

                    // ボイスメモ
                    VStack(spacing: 4) {
                        if recorder.recordedURL != nil && recorder.state != .idle {
                            // Recorded indicator
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(.title3))
                                .foregroundStyle(.green)
                            Text(String(localized: "録音済"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                if recorder.state == .recording {
                                    recorder.stopRecording()
                                } else {
                                    recorder.startRecording()
                                }
                                HapticManager.lightFeedback()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: recorder.state == .recording ? "stop.circle.fill" : "mic.fill")
                                        .font(.system(.title3))
                                        .foregroundStyle(recorder.state == .recording ? .red : themeColors.accent.opacity(0.6))
                                    Text(recorder.state == .recording ? String(localized: "停止") : String(localized: "ボイス"))
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(recorder.state == .recording ? .red : themeColors.accent.opacity(0.6))
                                }
                            }
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeColors.accent.opacity(0.08))
                    )

                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
        }
    }

    // (Energy tab removed - energy data collected via HealthKit automatically)

    // MARK: - ヘルパー

    /// テンプレートをテキストフィールドに挿入する
    /// 指定タブにデータがあるかチェック
    private func hasData(for tab: RecordingTab) -> Bool {
        switch tab {
        case .tags: return !selectedTags.isEmpty
        case .memo: return !memoText.isEmpty || capturedPhoto != nil || (recorder.recordedURL != nil && recorder.state != .idle)
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
                onSave: { _, _, _, _, _ in },
                onSkip: {}
            )
        }
        .modelContainer(for: [MoodEntry.self, EmotionTag.self], inMemory: true)
}
