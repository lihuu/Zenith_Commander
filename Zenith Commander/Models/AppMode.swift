//
//  AppMode.swift
//  Zenith Commander
//
//  应用模式定义
//

import SwiftUI

/// Vim 风格的模态枚举
enum AppMode: String, CaseIterable {
    case normal = "NORMAL"
    case visual = "VISUAL"
    case command = "COMMAND"
    case filter = "FILTER"
    case driveSelect = "DRIVES"
    case aiAnalysis = "AI"
    case rename = "RENAME"      // 重命名模式 - 阻止键盘事件传播
    case settings = "SETTINGS"  // 设置模式 - 阻止键盘事件传播
    case help = "HELP"          // 帮助模式 - 阻止键盘事件传播
    
    /// 模式显示颜色
    var color: Color {
        switch self {
        case .normal:
            return .gray
        case .visual:
            return .orange
        case .command:
            return .blue
        case .filter:
            return .green
        case .driveSelect:
            return .purple
        case .aiAnalysis:
            return .pink
        case .rename:
            return .cyan
        case .settings:
            return .teal
        case .help:
            return .indigo
        }
    }
    
    /// 模式背景色
    var backgroundColor: Color {
        color.opacity(0.15)
    }
    
    /// 是否为模态模式（需要阻止全局键盘事件）
    /// 这些模式下，键盘事件应该由模态窗口/视图处理，而不是全局快捷键
    var isModalMode: Bool {
        switch self {
        case .rename, .settings, .aiAnalysis, .help:
            return true
        default:
            return false
        }
    }
    
    /// 模式描述
    var description: String {
        switch self {
        case .normal:
            return "Normal mode - navigate and operate"
        case .visual:
            return "Visual mode - select multiple items"
        case .command:
            return "Command mode - enter commands"
        case .filter:
            return "Filter mode - filter file list"
        case .driveSelect:
            return "Drive selection mode"
        case .aiAnalysis:
            return "AI analysis mode"
        case .rename:
            return "Rename mode - batch rename files"
        case .settings:
            return "Settings mode - configure application"
        case .help:
            return "Help mode - view keyboard shortcuts"
        }
    }
}

/// 面板侧边枚举
enum PaneSide: String, CaseIterable {
    case left
    case right
    
    var opposite: PaneSide {
        self == .left ? .right : .left
    }
}

/// 视图模式
enum ViewMode: String, CaseIterable {
    case list
    case grid
}
