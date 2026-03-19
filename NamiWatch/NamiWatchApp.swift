//
//  NamiWatchApp.swift
//  NamiWatch
//
//  Apple Watch アプリのエントリポイント
//

import SwiftUI

@main
struct NamiWatchApp: App {
    /// iPhone側との通信マネージャー
    @State private var connector = WatchPhoneConnector()

    var body: some Scene {
        WindowGroup {
            WatchMainView(connector: connector)
        }
    }
}
