//
//  SettingsManager.swift
//  Zenith Commander
//
//  设置管理器 - 负责加载、保存和管理应用设置
//

import AppKit
import Combine
import Foundation
import os.log
import SwiftUI

/// 设置管理器 - 负责加载、保存和管理应用设置
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    /// 当前设置
    @Published var settings: AppSettings {
        didSet {
            saveSettings()
            applySettings()
        }
    }

    /// 设置存储目录
    private let storageDirectory: URL

    /// 设置文件路径
    private var settingsFileURL: URL {
        storageDirectory.appendingPathComponent("settings.json")
    }

    /// 初始化
    /// - Parameter storageDirectory: 可选的存储目录，默认使用 Application Support
    private init(storageDirectory: URL? = nil) {
        if let storageDirectory = storageDirectory {
            self.storageDirectory = storageDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            self.storageDirectory = appSupport.appendingPathComponent(
                "ZenithCommander", isDirectory: true)
        }

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: self.storageDirectory, withIntermediateDirectories: true)

        // 使用 _settings 直接设置初始值，避免触发 didSet 和 @Published 通知
        _settings = Published(initialValue: AppSettings.default)

        loadSettings()

        // 启动期一次性迁移：把老 settings.json 里的 themeMode 同步到 ThemeManager（单一运行时源）。
        // 之后主题模式的唯一持久化是 ThemeManager 的 UserDefaults（key `themeMode`），
        // settings.appearance.themeMode 仅保留用于 Codable 兼容，不再被任何视图绑定。
        migrateThemeModeIfNeeded()

        applySettings()
    }

    /// 加载设置
    private func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let decoder = JSONDecoder()
            settings = try decoder.decode(AppSettings.self, from: data)
        } catch {
            Logger.settings.error("Failed to load settings: \(error.localizedDescription)")
        }
    }

    /// 保存设置
    private func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL)
        } catch {
            Logger.settings.error("Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// 应用设置
    private func applySettings() {
        // 主题模式不再在此处覆盖 ThemeManager.mode：ThemeManager.shared.mode 是主题模式的
        // 单一运行时源（见 AGENTS.md §6），由 ThemeManager 自行持久化到 UserDefaults。
        // 字体大小/行高等其他外观设置由各视图直接读取 settings.appearance，无需在此强制应用。
    }

    /// 启动期把老 settings.json 中的 themeMode 一次性迁移到 ThemeManager.shared.mode。
    ///
    /// 仅在 ThemeManager 尚未持有有效持久化值时迁移，避免覆盖用户通过 Ctrl+T 或 Settings
    /// 最新设置的主题模式。迁移完成后 ThemeManager 的 UserDefaults 成为唯一持久化源，
    /// `settings.appearance.themeMode` 仅保留以兼容老 settings.json 的解码。
    private func migrateThemeModeIfNeeded() {
        let defaults = UserDefaults.standard
        let hasPersistedTheme = defaults.object(forKey: "themeMode") != nil
        guard !hasPersistedTheme else { return }

        let migrated = settings.appearance.themeModeEnum
        defaults.set(migrated.rawValue, forKey: "themeMode")
        // ThemeManager 是 @MainActor 单例，通过主线程异步访问以符合 Swift 并发约束。
        DispatchQueue.main.async {
            ThemeManager.shared.mode = migrated
        }
    }

    /// 重置为默认设置
    func resetToDefaults() {
        settings = AppSettings.default
    }

    /// 打开终端
    func openTerminal(at path: URL? = nil) {
        let terminal = settings.terminal.currentTerminal

        guard
            let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: terminal.bundleId)
        else {
            // 如果首选终端未安装，尝试使用系统终端
            if let defaultTerminalURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Terminal")
            {
                NSWorkspace.shared.open(defaultTerminalURL)
            }
            return
        }

        if let path {
            // 打开终端并切换到指定目录
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = [path.path]
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        } else {
            NSWorkspace.shared.open(appURL)
        }
    }
}
