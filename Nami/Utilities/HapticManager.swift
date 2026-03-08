//
//  HapticManager.swift
//  Nami
//
//  ハプティックフィードバック管理
//

import UIKit

/// ハプティックフィードバックを管理するユーティリティ
enum HapticManager {
    /// ハプティクスが有効かどうか
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
    }

    /// 気分記録時のフィードバック（medium impact）
    static func recordFeedback() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// 軽いタップフィードバック
    static func lightFeedback() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// 成功時のフィードバック
    static func successFeedback() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// エラー時のフィードバック
    static func errorFeedback() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
