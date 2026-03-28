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

    /// 気分記録時のフィードバック（soft — 控えめで上品な振動）
    static func recordFeedback() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    /// 軽いタップフィードバック（UI操作確認用）
    static func lightFeedback() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.5)
    }

    /// 成功時のフィードバック
    static func successFeedback() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
