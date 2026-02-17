//
//  WatchConnectivityManager.swift
//  Nami
//
//  iPhone側のWatchConnectivity管理
//  Apple WatchアプリとSwiftDataデータを連携する
//

import Foundation
import WatchConnectivity
import SwiftData
import WidgetKit

/// iPhone側のWatchConnectivityマネージャー
/// Watch側からの気分記録メッセージを受信し、SwiftDataに保存する
class WatchConnectivityManager: NSObject {
    /// シングルトン
    static let shared = WatchConnectivityManager()

    /// SwiftDataのModelContainer（アプリから設定）
    var modelContainer: ModelContainer?

    private override init() {
        super.init()
    }

    /// WCSessionをアクティベートする
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// 最新のエントリ情報をWatchに送信する
    @MainActor
    func sendLatestEntry() {
        guard WCSession.default.isReachable,
              let container = modelContainer else { return }

        let context = container.mainContext
        var descriptor = FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1

        guard let latest = try? context.fetch(descriptor).first else { return }

        let message: [String: Any] = [
            "type": "latestEntry",
            "score": latest.score,
            "maxScore": latest.maxScore,
            "memo": latest.memo ?? "",
            "tags": latest.tags,
            "createdAt": latest.createdAt.timeIntervalSince1970
        ]

        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    /// タグ一覧をWatchに送信する
    @MainActor
    func sendTags() {
        guard WCSession.default.isReachable,
              let container = modelContainer else { return }

        let context = container.mainContext
        let descriptor = FetchDescriptor<EmotionTag>(sortBy: [SortDescriptor(\.sortOrder)])

        guard let tags = try? context.fetch(descriptor) else { return }

        let tagData = tags.map { [
            "name": $0.name,
            "category": $0.categoryRaw,
            "icon": $0.icon
        ] }

        let message: [String: Any] = [
            "type": "tagList",
            "tags": tagData
        ]

        WCSession.default.sendMessage(message, replyHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("WCSession activation error: \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // 再アクティベート
        session.activate()
    }

    /// Watch側からのメッセージ受信
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        Task { @MainActor in
            switch type {
            case "recordMood":
                handleRecordMood(message)
            case "fetchLatest":
                sendLatestEntry()
            case "fetchTags":
                sendTags()
            default:
                break
            }
        }
    }

    /// Watch側からのメッセージ受信（返信付き）
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler(["success": false])
            return
        }

        Task { @MainActor in
            switch type {
            case "recordMood":
                handleRecordMood(message)
                replyHandler(["success": true])
            case "fetchLatest":
                sendLatestEntry()
                replyHandler(["success": true])
            case "fetchTags":
                sendTags()
                replyHandler(["success": true])
            default:
                replyHandler(["success": false])
            }
        }
    }

    /// 気分記録メッセージを処理する
    @MainActor
    private func handleRecordMood(_ message: [String: Any]) {
        guard let score = message["score"] as? Int,
              let maxScore = message["maxScore"] as? Int,
              let container = modelContainer else { return }

        let context = container.mainContext
        let tags = message["tags"] as? [String] ?? []
        let memo = message["memo"] as? String

        let entry = MoodEntry(
            score: score,
            maxScore: maxScore,
            memo: memo,
            tags: tags
        )
        context.insert(entry)

        // ウィジェットのタイムラインを更新
        WidgetCenter.shared.reloadAllTimelines()
    }
}
