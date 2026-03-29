//
//  LanguageManager.swift
//  Nami
//
//  App-level language override without restart.
//  Uses SwiftUI .environment(\.locale) for dynamic switching.
//

import SwiftUI

/// Supported app languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ja
    case en

    var id: String {
        rawValue
    }

    /// Display name in the language itself (for selection UI)
    var nativeName: String {
        switch self {
        case .system: return String(localized: "システム設定に従う")
        case .ja: return "日本語"
        case .en: return "English"
        }
    }

    /// Flag emoji
    var flag: String {
        switch self {
        case .system: return "🌐"
        case .ja: return "🇯🇵"
        case .en: return "🇺🇸"
        }
    }

    /// Resolve to actual Locale
    var locale: Locale {
        switch self {
        case .system: return .current
        case .ja: return Locale(identifier: "ja")
        case .en: return Locale(identifier: "en")
        }
    }
}

/// Manages app language preference with dynamic switching
@Observable
@MainActor
final class LanguageManager {
    /// UserDefaults key for language override
    private static let languageKey = "appLanguageOverride"

    /// Current language setting
    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageKey)
            AppConstants.sharedUserDefaults.set(currentLanguage.rawValue, forKey: Self.languageKey)
        }
    }

    /// Resolved locale for SwiftUI .environment(\.locale)
    var locale: Locale {
        currentLanguage.locale
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey) ?? "system"
        currentLanguage = AppLanguage(rawValue: saved) ?? .system
    }
}

// MARK: - Environment Key

private struct LanguageManagerKey: EnvironmentKey {
    static let defaultValue = LanguageManager()
}

extension EnvironmentValues {
    var languageManager: LanguageManager {
        get { self[LanguageManagerKey.self] }
        set { self[LanguageManagerKey.self] = newValue }
    }
}
