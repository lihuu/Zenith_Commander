//
//  AppMode.swift
//  Zenith Commander
//
//  应用模式定义
//  定义了各种应用模式（类似 Vim 风格的 NORMAL, VISUAL, COMMAND 等）及其相关属性和行为
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
    case rename = "RENAME" // 单个文件重命名模式 - 阻止键盘事件传播
    case batchRename = "BATCH_RENAME" // 批量重命名模式 - 阻止键盘事件传播
    case settings = "SETTINGS" // 设置模式 - 阻止键盘事件传播
    case help = "HELP" // 帮助模式 - 阻止键盘事件传播
    case modal = "MODAL" // 模态模式 - 阻止键盘事件传播

    /// 模式显示颜色
    var color: Color {
        switch self {
        case .normal:
            .gray
        case .visual:
            .orange
        case .command:
            .blue
        case .filter:
            .green
        case .driveSelect:
            .purple
        case .aiAnalysis:
            .pink
        case .rename:
            .cyan
        case .batchRename:
            .yellow
        case .settings:
            .teal
        case .help:
            .indigo
        case .modal:
            .gray.opacity(0.5)
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
        case .rename, .batchRename, .settings, .aiAnalysis, .help, .modal:
            true
        default:
            false
        }
    }

    /// 模式描述
    var description: String {
        switch self {
        case .normal:
            "Normal mode - navigate and operate"
        case .visual:
            "Visual mode - select multiple items"
        case .command:
            "Command mode - enter commands"
        case .filter:
            "Filter mode - filter file list"
        case .driveSelect:
            "Drive selection mode"
        case .aiAnalysis:
            "AI analysis mode"
        case .rename:
            "Rename mode - rename single file inline"
        case .batchRename:
            "Batch rename mode - rename multiple files"
        case .settings:
            "Settings mode - configure application"
        case .help:
            "Help mode - view keyboard shortcuts"
        case .modal:
            "Modal mode - interacting with dialog"
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


enum PointerButton {
    case back
    case forward
}

enum CursorDirection {
    case up, down, left, right
}
