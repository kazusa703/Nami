//
//  ContentView.swift
//  Nami
//
//  TabViewによるメインナビゲーション
//

import SwiftData
import SwiftUI

/// メインコンテンツビュー
/// TabViewで画面を切り替える
struct ContentView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.premiumManager) private var premiumManager
    @State private var selectedTab = 0
    /// PRO tab: show paywall sheet when user taps PRO tab while already premium
    @State private var showPaywall = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 記録タブ
            MainView()
                .tabItem {
                    Label("記録", systemImage: "pencil.circle")
                }
                .tag(0)

            // グラフタブ
            GraphView()
                .tabItem {
                    Label("グラフ", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            // 統計タブ
            StatsView()
                .tabItem {
                    Label("統計", systemImage: "chart.bar")
                }
                .tag(2)

            // PROタブ
            PremiumPaywallView(isInline: true)
                .tabItem {
                    Label("PRO", systemImage: "crown.fill")
                }
                .tag(3)

            // 設定タブ
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(themeManager.colors.accent)
        .onOpenURL { url in
            // nami://tab/graph → グラフタブを開く
            if url.host == "tab" {
                switch url.lastPathComponent {
                case "record": selectedTab = 0
                case "graph": selectedTab = 1
                case "stats": selectedTab = 2
                case "pro": selectedTab = 3
                case "settings": selectedTab = 4
                default: break
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
        .environment(\.themeManager, ThemeManager())
}
