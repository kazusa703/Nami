//
//  ContentView.swift
//  Nami
//
//  TabViewによるメインナビゲーション
//

import SwiftUI
import SwiftData

/// メインコンテンツビュー
/// TabViewで4つの画面を切り替える
struct ContentView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var selectedTab = 0

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

            // 設定タブ
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(themeManager.colors.accent)
        .onOpenURL { url in
            // nami://tab/graph → グラフタブを開く
            if url.host == "tab" {
                switch url.lastPathComponent {
                case "record": selectedTab = 0
                case "graph": selectedTab = 1
                case "stats": selectedTab = 2
                case "settings": selectedTab = 3
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
