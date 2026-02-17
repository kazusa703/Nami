//
//  ThemeManager.swift
//  Nami
//
//  テーマ管理（@AppStorageで永続化）
//

import SwiftUI

/// テーマ管理クラス
/// アプリ全体で共有し、テーマの切り替えと永続化を担当する
@Observable
class ThemeManager {
    /// 現在選択されているテーマ（UserDefaultsに永続化）
    var currentTheme: AppTheme {
        didSet {
            // 標準UserDefaultsに保存（メインアプリ用）
            UserDefaults.standard.set(currentTheme.rawValue, forKey: AppConstants.themeKey)
            // App Group UserDefaultsにも保存（ウィジェット用）
            AppConstants.sharedUserDefaults.set(currentTheme.rawValue, forKey: AppConstants.themeKey)
        }
    }

    /// 現在のテーマカラー（便利アクセサ）
    var colors: ThemeColors {
        currentTheme.colors
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: AppConstants.themeKey) ?? ""
        let theme = AppTheme(rawValue: savedTheme) ?? .ocean
        self.currentTheme = theme
        // App Group UserDefaultsにも初期値を同期
        AppConstants.sharedUserDefaults.set(theme.rawValue, forKey: AppConstants.themeKey)
    }
}

// MARK: - Environment Key

/// テーママネージャーの環境キー
struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
