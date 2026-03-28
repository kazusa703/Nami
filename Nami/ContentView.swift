//
//  ContentView.swift
//  Nami
//
//  上部タブナビゲーション + 下部広告のメインレイアウト
//

import Charts
import SwiftData
import SwiftUI

/// タブ種別
enum AppTab: Int, CaseIterable {
    case record = 0
    case graph = 1
    case stats = 2
    case pro = 3
    case settings = 4

    var label: String {
        switch self {
        case .record: return String(localized: "記録")
        case .graph: return String(localized: "グラフ")
        case .stats: return String(localized: "統計")
        case .pro: return String(localized: "PRO")
        case .settings: return String(localized: "設定")
        }
    }

    var icon: String {
        switch self {
        case .record: return "pencil.circle"
        case .graph: return "chart.xyaxis.line"
        case .stats: return "chart.bar"
        case .pro: return "crown.fill"
        case .settings: return "gearshape"
        }
    }
}

/// メインコンテンツビュー
/// 初回起動時はオンボーディング、完了後は上部タブ+コンテンツ+広告を表示する
struct ContentView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .record
    /// 訪問済みタブ（初回アクセス時にのみビューを生成し、@Queryの無駆な実行を防ぐ）
    @State private var loadedTabs: Set<AppTab> = [.record]
    /// Track if this is first launch after onboarding (to open graph tab)
    @AppStorage("hasShownPostOnboarding") private var hasShownPostOnboarding = false
    /// 全画面チャート表示モード（nilなら非表示）
    @State private var fullscreenChartMode: GraphMode? = nil
    @State private var fullscreenDateMode: DateSelectionMode = .week
    @State private var fullscreenTargetDate: Date = .init()
    /// フルスクリーン解除時にレイアウトを強制再描画するためのID
    @State private var contentRefreshID = UUID()
    /// Monthly report banner + sheet
    @State private var showMonthlyReportBanner = false
    @State private var showMonthlyReport = false
    @AppStorage("lastSeenReportMonth") private var lastSeenReportMonth: String = ""

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
                            if loadedTabs.contains(.pro) {
                                ProView()
                                    .opacity(selectedTab == .pro ? 1 : 0)
                                    .allowsHitTesting(selectedTab == .pro)
                            }
                            if loadedTabs.contains(.settings) {
                                SettingsView()
                                    .opacity(selectedTab == .settings ? 1 : 0)
                                    .allowsHitTesting(selectedTab == .settings)
                            }
                        }
                        .frame(maxHeight: .infinity)

                        // 下部タブバー
                        topTabBar(colors: colors)
                    }
                    // 明示的に現在のジオメトリサイズに制約（横幅キャッシュ問題を防止）
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .overlay {
                // Fullscreen chart as ZStack overlay (not .fullScreenCover — avoids rotation layout corruption)
                if fullscreenChartMode != nil {
                    FullscreenChartView(
                        graphMode: fullscreenChartMode ?? .line,
                        dateMode: fullscreenDateMode,
                        targetDate: fullscreenTargetDate,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                fullscreenChartMode = nil
                            }
                            NamiAppDelegate.allowLandscape = false
                            if let windowScene = UIApplication.shared.connectedScenes
                                .first as? UIWindowScene
                            {
                                windowScene.requestGeometryUpdate(
                                    .iOS(interfaceOrientations: .portrait)
                                )
                            }
                        }
                    )
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
                    .onAppear {
                        NamiAppDelegate.allowLandscape = true
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: fullscreenChartMode != nil)
            .id(contentRefreshID)
            .tint(colors.accent)
            .onChange(of: selectedTab) { _, newTab in
                loadedTabs.insert(newTab)
            }
            // Monthly report banner (top of screen)
            .overlay(alignment: .top) {
                if showMonthlyReportBanner {
                    monthlyReportBanner(colors: colors)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                        .zIndex(50)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showMonthlyReportBanner)
            .sheet(isPresented: $showMonthlyReport) {
                MonthlyReportView()
            }
            .onAppear {
                checkMonthlyReportAvailability()
                checkPendingDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkPendingDeepLink()
            }
        } else {
            OnboardingView()
                .onChange(of: hasCompletedOnboarding) { _, completed in
                    if completed, !hasShownPostOnboarding {
                        hasShownPostOnboarding = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            loadedTabs.insert(.stats)
                            selectedTab = .stats
                        }
                    }
                }
        }
    }

    // MARK: - Monthly Report Banner

    private func monthlyReportBanner(colors: ThemeColors) -> some View {
        Button {
            showMonthlyReportBanner = false
            markReportAsSeen()
            showMonthlyReport = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "\(previousMonthName)のレポートが届きました"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(String(localized: "1ヶ月の心の波を振り返ってみましょう"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: colors.accent.opacity(0.15), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height < -20 {
                        // Swipe up to dismiss
                        withAnimation { showMonthlyReportBanner = false }
                        markReportAsSeen()
                    }
                }
        )
    }

    /// Previous month name for display
    private var previousMonthName: String {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "M月"
        return formatter.string(from: lastMonth)
    }

    /// Check if monthly report should be shown
    private func checkMonthlyReportAvailability() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        let currentMonthKey = formatter.string(from: .now)
        guard lastSeenReportMonth != currentMonthKey else { return }

        // Check if previous month has entries
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        let lastMonthKey = formatter.string(from: lastMonth)

        // Use AppStorage to check if we already showed for this month
        // We show banner only if current month key != last seen
        // and there's likely data (we can't query @Query here, so just show it)
        guard lastSeenReportMonth != currentMonthKey else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showMonthlyReportBanner = true
            }
        }
    }

    private func markReportAsSeen() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        lastSeenReportMonth = formatter.string(from: .now)
    }

    /// Check for pending deep link from notification tap
    private func checkPendingDeepLink() {
        if NamiAppDelegate.pendingMonthlyReport {
            NamiAppDelegate.pendingMonthlyReport = false
            markReportAsSeen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showMonthlyReport = true
            }
        }
    }

    // MARK: - 上部タブバー

    @ViewBuilder
    private func topTabBar(colors: ThemeColors) -> some View {
        let isCompact = verticalSizeClass == .compact

        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                let tabColor: Color = proTabColor(tab: tab, isSelected: isSelected, colors: colors)
                let tabIcon = proTabIcon(tab: tab)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.lightFeedback()
                } label: {
                    if isCompact {
                        // Landscape: icon + text side by side, compact
                        HStack(spacing: 4) {
                            proTabIconView(tab: tab, icon: tabIcon, size: 13, isSelected: isSelected)
                            Text(tab.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(tabColor)
                    } else {
                        // Portrait: icon above text
                        VStack(spacing: 3) {
                            proTabIconView(tab: tab, icon: tabIcon, size: 16, isSelected: isSelected)
                            Text(tab.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(tabColor)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - PRO Tab Styling Helpers

    /// Determine the foreground color for a tab
    private func proTabColor(tab: AppTab, isSelected: Bool, colors: ThemeColors) -> Color {
        if tab == .pro {
            if premiumManager.isPremium {
                return isSelected ? colors.accent : .secondary
            } else {
                return isSelected ? .orange : .orange.opacity(0.7)
            }
        }
        return isSelected ? colors.accent : .secondary
    }

    /// Determine the icon name for a tab (premium checkmark for PRO when purchased)
    private func proTabIcon(tab: AppTab) -> String {
        if tab == .pro && premiumManager.isPremium {
            return "checkmark.seal.fill"
        }
        return tab.icon
    }

    /// Build the icon view, adding a badge dot for unpurchased PRO tab
    @ViewBuilder
    private func proTabIconView(tab: AppTab, icon: String, size: CGFloat, isSelected: Bool) -> some View {
        if tab == .pro && !premiumManager.isPremium {
            Image(systemName: icon)
                .font(.system(size: size, weight: isSelected ? .semibold : .regular))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .offset(x: 3, y: -2)
                }
        } else {
            Image(systemName: icon)
                .font(.system(size: size, weight: isSelected ? .semibold : .regular))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
