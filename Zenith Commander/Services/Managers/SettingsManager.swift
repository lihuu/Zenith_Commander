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
        // 应用主题 - 使用异步更新避免在视图更新期间修改 @Published 属性
        DispatchQueue.main.async {
            ThemeManager.shared.mode = self.settings.appearance.themeModeEnum
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
