//
//  Settings.swift
//  Zenith Commander
//
//  应用设置模型和管理器
//

import SwiftUI
import Combine
import os.log

// MARK: - 设置数据模型

/// 应用设置
struct AppSettings: Codable, Equatable {
    /// 外观设置
    var appearance: AppearanceSettings
    
    /// 终端设置
    var terminal: TerminalSettings
    
    /// Git 设置
    var git: GitSettings
    
    /// Rsync 设置
    var rsync: RsyncSettings
    
    /// 默认设置
    static var `default`: AppSettings {
        AppSettings(
            appearance: .default,
            terminal: .default,
            git: .default,
            rsync: .default
        )
    }
    
    // 自定义解码器，处理旧版设置文件缺少字段的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try container.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? .default
        terminal = try container.decodeIfPresent(TerminalSettings.self, forKey: .terminal) ?? .default
        git = try container.decodeIfPresent(GitSettings.self, forKey: .git) ?? .default
        rsync = try container.decodeIfPresent(RsyncSettings.self, forKey: .rsync) ?? .default
    }
    
    init(appearance: AppearanceSettings, terminal: TerminalSettings, git: GitSettings, rsync: RsyncSettings) {
        self.appearance = appearance
        self.terminal = terminal
        self.git = git
        self.rsync = rsync
    }
}

/// Git 设置
struct GitSettings: Codable, Equatable {
    /// 是否启用 Git 集成
    var enabled: Bool
    
    /// 是否显示未追踪文件
    var showUntrackedFiles: Bool
    
    /// 是否显示被忽略文件的状态
    var showIgnoredFiles: Bool
    
    /// 默认设置
    static var `default`: GitSettings {
        GitSettings(
            enabled: true,
            showUntrackedFiles: true,
            showIgnoredFiles: false
        )
    }
}

/// Rsync 设置
struct RsyncSettings: Codable, Equatable {
    /// 是否启用 Rsync 集成
    var enabled: Bool
    
    /// 默认设置
    static var `default`: RsyncSettings {
        // Default to enabled if rsync is installed
        RsyncSettings(
            enabled: RsyncService.shared.isRsyncInstalled()
        )
    }
}

/// 外观设置
struct AppearanceSettings: Codable, Equatable {
    /// 主题模式
    var themeMode: String  // "light", "dark", "auto"
    
    /// 字体大小
    var fontSize: Double
    
    /// 行高倍数
    var lineHeight: Double
    
    /// 默认设置
    static var `default`: AppearanceSettings {
        AppearanceSettings(
            themeMode: "auto",
            fontSize: 12.0,
            lineHeight: 1.4
        )
    }
    
    /// 获取 ThemeMode 枚举值
    var themeModeEnum: ThemeMode {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return .auto
        }
    }
}

/// 终端设置
struct TerminalSettings: Codable, Equatable {
    /// 默认终端应用
    var defaultTerminal: String
    
    /// 终端选项
    static let availableTerminals = [
        TerminalOption(id: "terminal", name: "Terminal", bundleId: "com.apple.Terminal"),
        TerminalOption(id: "iterm", name: "iTerm", bundleId: "com.googlecode.iterm2"),
        TerminalOption(id: "warp", name: "Warp", bundleId: "dev.warp.Warp-Stable"),
        TerminalOption(id: "alacritty", name: "Alacritty", bundleId: "org.alacritty"),
        TerminalOption(id: "kitty", name: "Kitty", bundleId: "net.kovidgoyal.kitty"),
        TerminalOption(id: "hyper", name: "Hyper", bundleId: "co.zeit.hyper")
    ]
    
    /// 默认设置
    static var `default`: TerminalSettings {
        TerminalSettings(defaultTerminal: "terminal")
    }
    
    /// 获取当前终端选项
    var currentTerminal: TerminalOption {
        TerminalSettings.availableTerminals.first { $0.id == defaultTerminal } 
            ?? TerminalSettings.availableTerminals[0]
    }
}

/// 终端选项
struct TerminalOption: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let bundleId: String
    
    /// 检查终端是否已安装
    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}

// MARK: - 设置管理器

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
    
    /// 设置文件路径
    private var settingsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ZenithCommander", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent("settings.json")
    }
    
    private init() {
        self.settings = AppSettings.default
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
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleId) else {
            // 如果首选终端未安装，尝试使用系统终端
            if let defaultTerminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.open(defaultTerminalURL)
            }
            return
        }
        
        if let path = path {
            // 打开终端并切换到指定目录
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = [path.path]
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        } else {
            NSWorkspace.shared.open(appURL)
        }
    }
}
