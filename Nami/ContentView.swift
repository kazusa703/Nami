//
//  ContentView.swift
//  Nami
//
//  上部タブナビゲーション + 下部広告のメインレイアウト
//

import SwiftUI
import SwiftData
import Charts

/// タブ種別
enum AppTab: Int, CaseIterable {
    case record = 0
    case graph = 1
    case stats = 2
    case settings = 3

    var label: String {
        switch self {
        case .record: return String(localized: "記録")
        case .graph: return String(localized: "グラフ")
        case .stats: return String(localized: "統計")
        case .settings: return String(localized: "設定")
        }
    }

    var icon: String {
        switch self {
        case .record: return "pencil.circle"
        case .graph: return "chart.xyaxis.line"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

/// メインコンテンツビュー
/// 初回起動時はオンボーディング、完了後は上部タブ+コンテンツ+広告を表示する
struct ContentView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .record
    /// 訪問済みタブ（初回アクセス時にのみビューを生成し、@Queryの無駄な実行を防ぐ）
    @State private var loadedTabs: Set<AppTab> = [.record]
    /// 全画面チャート表示モード（nilなら非表示）
    @State private var fullscreenChartMode: GraphMode? = nil
    @State private var fullscreenDateMode: DateSelectionMode = .week
    @State private var fullscreenTargetDate: Date = Date()
    /// フルスクリーン解除時にレイアウトを強制再描画するためのID
    @State private var contentRefreshID = UUID()

    var body: some View {
        if hasCompletedOnboarding {
            let colors = themeManager.colors

            // GeometryReaderで常に現在の画面サイズを取得し、明示的にサイズを制約する
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // 背景
                    colors.backgroundGradient(for: colorScheme)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // 上部タブバー
                        topTabBar(colors: colors)

                        // タブコンテンツ（訪問済みタブのみ生成）
                        ZStack {
                            MainView()
                                .opacity(selectedTab == .record ? 1 : 0)
                                .allowsHitTesting(selectedTab == .record)
                            if loadedTabs.contains(.graph) {
                                GraphView(onShowFullscreen: { mode, dateMode, targetDate in
                                    fullscreenChartMode = mode
                                    fullscreenDateMode = dateMode
                                    fullscreenTargetDate = targetDate
                                })
                                    .opacity(selectedTab == .graph ? 1 : 0)
                                    .allowsHitTesting(selectedTab == .graph)
                            }
                            if loadedTabs.contains(.stats) {
                                StatsView()
                                    .opacity(selectedTab == .stats ? 1 : 0)
                                    .allowsHitTesting(selectedTab == .stats)
                            }
                            if loadedTabs.contains(.settings) {
                                SettingsView()
                                    .opacity(selectedTab == .settings ? 1 : 0)
                                    .allowsHitTesting(selectedTab == .settings)
                            }
                        }
                        .frame(maxHeight: .infinity)

                        // 広告を一番下に配置
                        BannerAdView()
                    }
                    // 明示的に現在のジオメトリサイズに制約（横幅キャッシュ問題を防止）
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .id(contentRefreshID)
            .fullScreenCover(isPresented: Binding(
                get: { fullscreenChartMode != nil },
                set: { if !$0 { fullscreenChartMode = nil } }
            )) {
                FullscreenChartView(
                    graphMode: fullscreenChartMode ?? .line,
                    dateMode: fullscreenDateMode,
                    targetDate: fullscreenTargetDate,
                    onDismiss: {
                        fullscreenChartMode = nil
                    }
                )
                .interactiveDismissDisabled()
                .onAppear {
                    // フルスクリーン表示中はランドスケープを許可
                    NamiAppDelegate.allowLandscape = true
                }
                .onDisappear {
                    // 1. ランドスケープを禁止に戻す
                    NamiAppDelegate.allowLandscape = false
                    // 2. ポートレートへの回転を強制リクエスト
                    if let windowScene = UIApplication.shared.connectedScenes
                        .first as? UIWindowScene {
                        windowScene.requestGeometryUpdate(
                            .iOS(interfaceOrientations: .portrait)
                        )
                    }
                    // 3. IDを更新してコンテンツ全体を再描画し、レイアウトをリセット
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        contentRefreshID = UUID()
                    }
                }
            }
            .tint(colors.accent)
            .onChange(of: selectedTab) { _, newTab in
                loadedTabs.insert(newTab)
            }
        } else {
            OnboardingView()
        }
    }

    // MARK: - 上部タブバー

    @ViewBuilder
    private func topTabBar(colors: ThemeColors) -> some View {
        let isCompact = verticalSizeClass == .compact

        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.lightFeedback()
                } label: {
                    if isCompact {
                        // 横画面: アイコン + テキスト横並び、コンパクト
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            Text(tab.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(isSelected ? colors.accent : .secondary)
                    } else {
                        // 縦画面: アイコン上 + テキスト下
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                            Text(tab.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? colors.accent : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
