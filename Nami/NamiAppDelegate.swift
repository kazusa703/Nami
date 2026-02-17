//
//  NamiAppDelegate.swift
//  Nami
//
//  画面回転の動的制御を担当するAppDelegate
//

import UIKit

/// 画面回転を動的に制御するためのAppDelegate
/// フルスクリーンチャート表示時のみランドスケープを許可する
class NamiAppDelegate: NSObject, UIApplicationDelegate {
    /// フルスクリーン表示中にランドスケープを許可するフラグ
    static var allowLandscape = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.allowLandscape
            ? [.portrait, .landscapeLeft, .landscapeRight]
            : .portrait
    }
}
