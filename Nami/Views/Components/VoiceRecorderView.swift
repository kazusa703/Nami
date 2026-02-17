//
//  VoiceRecorderView.swift
//  Nami
//
//  ボイスメモ録音・再生UI（Apple Voice Memos風デザイン）
//

import SwiftUI
import AVFoundation

/// ボイスメモ録音・再生を管理するマネージャー
@Observable
class VoiceRecorderManager: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    /// 録音状態
    enum State {
        case idle       // 未録音
        case recording  // 録音中
        case recorded   // 録音完了
        case playing    // 再生中
        case paused     // 再生一時停止
    }

    var state: State = .idle
    /// 録音時間（秒）
    var recordingDuration: TimeInterval = 0
    /// 再生位置（秒）
    var playbackPosition: TimeInterval = 0
    /// 録音ファイルのURL（一時ディレクトリ）
    var recordedURL: URL?
    /// 現在の音量レベル（0.0〜1.0）
    var currentLevel: CGFloat = 0
    /// 録音中の音量レベル履歴（波形表示用）
    var audioLevels: [CGFloat] = []

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    /// 最大録音時間（秒）
    private let maxDuration: TimeInterval = 60
    /// 波形のサンプル数
    private let maxLevelSamples = 50

    /// 録音を開始する
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("オーディオセッション設定エラー: \(error)")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_temp_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            recordedURL = url
            state = .recording
            recordingDuration = 0
            audioLevels = []
            currentLevel = 0

            // タイマーで録音時間とメータリングを更新
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                self.recordingDuration = recorder.currentTime

                // 音量レベルを正規化（-160dB〜0dBを0.0〜1.0に）
                let power = recorder.averagePower(forChannel: 0)
                let normalizedLevel = max(0, (power + 50) / 50)
                self.currentLevel = CGFloat(normalizedLevel)

                // 波形サンプルを蓄積
                let sampleInterval = self.maxDuration / Double(self.maxLevelSamples)
                let expectedSamples = Int(recorder.currentTime / sampleInterval) + 1
                if expectedSamples > self.audioLevels.count {
                    self.audioLevels.append(CGFloat(normalizedLevel))
                }

                // 最大時間に達したら自動停止
                if self.recordingDuration >= self.maxDuration {
                    self.stopRecording()
                }
            }
        } catch {
            print("録音開始エラー: \(error)")
        }
    }

    /// 録音を停止する
    func stopRecording() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        currentLevel = 0
        state = .recorded
    }

    /// 録音を再生する
    func play() {
        guard let url = recordedURL else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            state = .playing

            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.playbackPosition = self.audioPlayer?.currentTime ?? 0
            }
        } catch {
            print("再生エラー: \(error)")
        }
    }

    /// 再生を一時停止する
    func pause() {
        audioPlayer?.pause()
        timer?.invalidate()
        timer = nil
        state = .paused
    }

    /// 再生を停止する
    func stopPlaying() {
        audioPlayer?.stop()
        timer?.invalidate()
        timer = nil
        playbackPosition = 0
        state = .recorded
    }

    /// 再生位置をシークする
    func seek(to position: TimeInterval) {
        audioPlayer?.currentTime = position
        playbackPosition = position
    }

    /// 録音を削除してリセットする
    func deleteRecording() {
        stopPlaying()
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedURL = nil
        recordingDuration = 0
        playbackPosition = 0
        audioLevels = []
        currentLevel = 0
        state = .idle
    }

    /// 録音時間を「M:SS」形式の文字列にフォーマットする
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer?.invalidate()
        timer = nil
        playbackPosition = 0
        state = .recorded
    }
}

/// ボイスメモ録音UIビュー（Apple Voice Memos風）
struct VoiceRecorderView: View {
    let themeColors: ThemeColors
    @Bindable var recorder: VoiceRecorderManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            switch recorder.state {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .recorded, .paused:
                recordedView
            case .playing:
                playingView
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: recorder.state)
    }

    // MARK: - 未録音状態

    private var idleView: some View {
        VStack(spacing: 20) {
            // 説明テキスト
            VStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(themeColors.accent.opacity(0.3))

                Text("ボイスメモを録音")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("最大60秒")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // 録音ボタン
            recordButton(isRecording: false)
        }
    }

    // MARK: - 録音中状態

    private var recordingView: some View {
        VStack(spacing: 16) {
            // ライブ波形
            liveWaveform
                .frame(height: 60)

            // 録音時間
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)

                Text(recorder.formatTime(recorder.recordingDuration))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            // 残り時間バー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.red.opacity(0.8))
                        .frame(width: geo.size.width * (recorder.recordingDuration / 60.0), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 8)

            // 停止ボタン
            recordButton(isRecording: true)
        }
    }

    // MARK: - 録音完了・一時停止状態

    private var recordedView: some View {
        VStack(spacing: 16) {
            // 静的波形
            staticWaveform
                .frame(height: 50)

            // 再生コントロール
            playbackControls

            // 操作ボタン
            HStack(spacing: 32) {
                // 再生ボタン
                Button {
                    recorder.play()
                    HapticManager.lightFeedback()
                } label: {
                    playbackCircleButton(
                        icon: "play.fill",
                        size: 48,
                        color: themeColors.accent
                    )
                }

                // 録り直し
                Button {
                    recorder.deleteRecording()
                    HapticManager.lightFeedback()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .medium))
                        Text("録り直し")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }

                // 削除
                Button {
                    recorder.deleteRecording()
                    HapticManager.lightFeedback()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .medium))
                        Text("削除")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - 再生中状態

    private var playingView: some View {
        VStack(spacing: 16) {
            // 再生中波形（プレイヘッド付き）
            playbackWaveform
                .frame(height: 50)

            // 再生コントロール
            playbackControls

            // 操作ボタン
            HStack(spacing: 32) {
                // 一時停止ボタン
                Button {
                    recorder.pause()
                    HapticManager.lightFeedback()
                } label: {
                    playbackCircleButton(
                        icon: "pause.fill",
                        size: 48,
                        color: themeColors.accent
                    )
                }

                // 停止
                Button {
                    recorder.stopPlaying()
                    HapticManager.lightFeedback()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20, weight: .medium))
                        Text("停止")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - コンポーネント

    /// 録音/停止ボタン（大きな丸ボタン）
    private func recordButton(isRecording: Bool) -> some View {
        Button {
            if isRecording {
                recorder.stopRecording()
            } else {
                recorder.startRecording()
            }
            HapticManager.lightFeedback()
        } label: {
            ZStack {
                // 外側リング
                Circle()
                    .stroke(isRecording ? Color.red.opacity(0.3) : themeColors.accent.opacity(0.2), lineWidth: 3)
                    .frame(width: 68, height: 68)

                // パルスアニメーション（録音中）
                if isRecording {
                    Circle()
                        .fill(.red.opacity(0.1))
                        .frame(width: 68, height: 68)
                        .scaleEffect(1.0 + recorder.currentLevel * 0.3)
                        .animation(.easeOut(duration: 0.1), value: recorder.currentLevel)
                }

                // 内側ボタン
                if isRecording {
                    // 停止 = 角丸四角
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.red)
                        .frame(width: 24, height: 24)
                } else {
                    // 録音 = 赤丸
                    Circle()
                        .fill(.red)
                        .frame(width: 52, height: 52)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 再生用丸ボタン
    private func playbackCircleButton(icon: String, size: CGFloat, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    /// 再生位置 + 時間表示
    private var playbackControls: some View {
        VStack(spacing: 6) {
            // プログレスバー（スクラブ可能）
            GeometryReader { geo in
                let progress = recorder.recordingDuration > 0
                    ? recorder.playbackPosition / recorder.recordingDuration
                    : 0

                ZStack(alignment: .leading) {
                    // 背景トラック
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(height: 4)

                    // 再生済みトラック
                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeColors.accent)
                        .frame(width: geo.size.width * progress, height: 4)

                    // スクラブノブ
                    Circle()
                        .fill(themeColors.accent)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, geo.size.width * progress - 7))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = max(0, min(1, value.location.x / geo.size.width))
                            let newPosition = ratio * recorder.recordingDuration
                            recorder.seek(to: newPosition)
                        }
                )
            }
            .frame(height: 14)

            // 時間表示
            HStack {
                Text(recorder.formatTime(recorder.playbackPosition))
                    .font(.system(.caption, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer()

                Text(recorder.formatTime(recorder.recordingDuration))
                    .font(.system(.caption, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 波形表示

    /// ライブ波形（録音中）
    private var liveWaveform: some View {
        GeometryReader { geo in
            let barCount = 30
            let barWidth: CGFloat = 3
            let spacing = (geo.size.width - barWidth * CGFloat(barCount)) / CGFloat(barCount - 1)

            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let level: CGFloat = {
                        if index < recorder.audioLevels.count {
                            // 既に記録されたレベル
                            let mappedIndex = Int(Double(index) / Double(barCount) * Double(recorder.audioLevels.count))
                            return recorder.audioLevels[min(mappedIndex, recorder.audioLevels.count - 1)]
                        } else if index == recorder.audioLevels.count {
                            // 現在の入力レベル
                            return recorder.currentLevel
                        } else {
                            return 0
                        }
                    }()

                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(
                            index <= recorder.audioLevels.count
                                ? Color.red.opacity(0.6 + Double(level) * 0.4)
                                : Color(.systemGray5)
                        )
                        .frame(width: barWidth, height: max(3, geo.size.height * level))
                        .frame(height: geo.size.height, alignment: .center)
                        .animation(.easeOut(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 静的波形（録音後）
    private var staticWaveform: some View {
        GeometryReader { geo in
            let barCount = min(recorder.audioLevels.count, 40)
            guard barCount > 0 else {
                return AnyView(EmptyView())
            }

            let barWidth: CGFloat = 3
            let spacing = max(1, (geo.size.width - barWidth * CGFloat(barCount)) / CGFloat(max(barCount - 1, 1)))

            return AnyView(
                HStack(spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let mappedIndex = Int(Double(index) / Double(barCount) * Double(recorder.audioLevels.count))
                        let level = recorder.audioLevels[min(mappedIndex, recorder.audioLevels.count - 1)]

                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(themeColors.accent.opacity(0.5))
                            .frame(width: barWidth, height: max(3, geo.size.height * level))
                            .frame(height: geo.size.height, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity)
            )
        }
    }

    /// 再生中波形（プレイヘッド付き）
    private var playbackWaveform: some View {
        GeometryReader { geo in
            let barCount = min(recorder.audioLevels.count, 40)
            guard barCount > 0 else {
                return AnyView(EmptyView())
            }

            let barWidth: CGFloat = 3
            let spacing = max(1, (geo.size.width - barWidth * CGFloat(barCount)) / CGFloat(max(barCount - 1, 1)))
            let progress = recorder.recordingDuration > 0
                ? recorder.playbackPosition / recorder.recordingDuration
                : 0
            let playedBars = Int(Double(barCount) * progress)

            return AnyView(
                HStack(spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let mappedIndex = Int(Double(index) / Double(barCount) * Double(recorder.audioLevels.count))
                        let level = recorder.audioLevels[min(mappedIndex, recorder.audioLevels.count - 1)]
                        let isPlayed = index <= playedBars

                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(isPlayed ? themeColors.accent : themeColors.accent.opacity(0.25))
                            .frame(width: barWidth, height: max(3, geo.size.height * level))
                            .frame(height: geo.size.height, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity)
            )
        }
    }
}

#Preview {
    VoiceRecorderView(themeColors: .ocean, recorder: VoiceRecorderManager())
        .frame(height: 200)
        .padding()
}
