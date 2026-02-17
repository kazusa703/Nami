//
//  WatchPhoneConnector.swift
//  NamiWatch
//
//  Watch側のWCSession管理（iPhone側との通信）
//

import Foundation
import WatchConnectivity

/// Watch側のWCSessionデリゲート
/// iPhoneアプリにメッセージを送信し、気分記録を同期する
@Observable
class WatchPhoneConnector: NSObject, @unchecked Sendable {
    /// 接続済みかどうか
    var isConnected = false
    /// 最新のタグ一覧（iPhone側から受信）
    var availableTags: [WatchTag] = []
    /// 最新のスコア（iPhone側から受信）
    var latestScore: Int?
    /// 最新のメモ（iPhone側から受信）
    var latestMemo: String?

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// iPhoneに気分を記録するメッセージを送信する
    func recordMood(score: Int, maxScore: Int, memo: String? = nil, tags: [String] = []) {
        guard WCSession.default.isReachable else { return }

        var message: [String: Any] = [
            "type": "recordMood",
            "score": score,
            "maxScore": maxScore,
            "tags": tags
        ]
        if let memo, !memo.isEmpty {
            message["memo"] = memo
        }

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Watch: recordMood error: \(error)")
        }
    }

    /// iPhoneに最新エントリをリクエストする
    func fetchLatest() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "fetchLatest"], replyHandler: nil)
    }

    /// iPhoneにタグ一覧をリクエストする
    func fetchTags() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "fetchTags"], replyHandler: nil)
    }
}

/// Watch側で使うタグの軽量モデル
struct WatchTag: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    let icon: String
}

// MARK: - WCSessionDelegate

extension WatchPhoneConnector: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isConnected = activationState == .activated
        }
        if activationState == .activated {
            // アクティベート後にタグ一覧を取得
            fetchTags()
            fetchLatest()
        }
    }

    /// iPhoneからのメッセージ受信
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        // Sendableな値を隔離境界の前に抽出
        let score = message["score"] as? Int
        let memo = message["memo"] as? String
        let tagData = message["tags"] as? [[String: String]]

        Task { @MainActor in
            switch type {
            case "latestEntry":
                self.latestScore = score
                self.latestMemo = memo

            case "tagList":
                if let tagData {
                    self.availableTags = tagData.compactMap { dict in
                        guard let name = dict["name"],
                              let category = dict["category"],
                              let icon = dict["icon"] else { return nil }
                        return WatchTag(name: name, category: category, icon: icon)
                    }
                }

            default:
                break
            }
        }
    }
}
