//
//  AppSettings.swift
//  Zenith Commander
//
//  应用设置数据模型
//

import AppKit
import Foundation

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

    /// Fzf 设置
    var fzf: FzfSettings

    /// AI 设置
    var ai: AISettings

    /// 默认设置
    static var `default`: AppSettings {
        AppSettings(
            appearance: .default,
            terminal: .default,
            git: .default,
            rsync: .default,
            fzf: .default,
            ai: .default
        )
    }

    // 自定义解码器，处理旧版设置文件缺少字段的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearance =
            try container.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? .default
        terminal =
            try container.decodeIfPresent(TerminalSettings.self, forKey: .terminal) ?? .default
        git = try container.decodeIfPresent(GitSettings.self, forKey: .git) ?? .default
        rsync = try container.decodeIfPresent(RsyncSettings.self, forKey: .rsync) ?? .default
        fzf = try container.decodeIfPresent(FzfSettings.self, forKey: .fzf) ?? .default
        ai = try container.decodeIfPresent(AISettings.self, forKey: .ai) ?? .default
    }

    init(
        appearance: AppearanceSettings, terminal: TerminalSettings, git: GitSettings,
        rsync: RsyncSettings, fzf: FzfSettings, ai: AISettings
    ) {
        self.appearance = appearance
        self.terminal = terminal
        self.git = git
        self.rsync = rsync
        self.fzf = fzf
        self.ai = ai
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
        case "light": .light
        case "dark": .dark
        default: .auto
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
        TerminalOption(id: "ghostty", name: "Ghostty", bundleId: "com.mitchellh.ghostty"),
        TerminalOption(id: "hyper", name: "Hyper", bundleId: "co.zeit.hyper"),
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
