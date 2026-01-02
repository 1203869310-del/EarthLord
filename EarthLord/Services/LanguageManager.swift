//
//  LanguageManager.swift
//  EarthLord
//
//  Created by feixiang yang on 2025/12/31.
//

import SwiftUI
import Combine

// MARK: - 语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "跟随系统")
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 获取对应的 Locale
    var locale: Locale? {
        switch self {
        case .system:
            return nil  // 返回 nil 表示使用系统语言
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }
}

// MARK: - 语言管理器
@MainActor
final class LanguageManager: ObservableObject {

    // MARK: - 单例
    static let shared = LanguageManager()

    // MARK: - 存储键
    private let languageKey = "app_language"

    // MARK: - 发布属性

    /// 当前选择的语言选项
    @Published var currentLanguage: AppLanguage {
        didSet {
            // 保存到 UserDefaults
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            // 更新实际使用的 Locale
            updateActiveLocale()
        }
    }

    /// 当前实际使用的 Locale（用于绑定到视图）
    @Published private(set) var activeLocale: Locale

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }

        // 初始化 activeLocale
        self.activeLocale = Locale.current

        // 更新实际使用的 Locale
        updateActiveLocale()
    }

    // MARK: - 私有方法

    /// 更新实际使用的 Locale
    private func updateActiveLocale() {
        if let locale = currentLanguage.locale {
            activeLocale = locale
        } else {
            // 跟随系统
            activeLocale = Locale.current
        }
    }

    // MARK: - 公开方法

    /// 设置语言
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }

    /// 获取当前语言的标识符（用于显示）
    var currentLanguageIdentifier: String {
        if currentLanguage == .system {
            return Locale.current.identifier
        }
        return currentLanguage.rawValue
    }
}

// MARK: - 环境键
private struct LocaleKey: EnvironmentKey {
    static let defaultValue: Locale = .current
}

extension EnvironmentValues {
    var appLocale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
}

// MARK: - View 扩展
extension View {
    /// 应用 App 语言设置
    func applyAppLanguage(_ languageManager: LanguageManager) -> some View {
        self.environment(\.locale, languageManager.activeLocale)
    }
}
