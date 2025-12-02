//
//  AppMode.swift
//  Zenith Commander
//
//  应用模式定义
//

import SwiftUI

enum CursorDirection {
    case up, down, left, right
}
/// Vim 风格的模态枚举
enum AppMode: String, CaseIterable {
    case normal = "NORMAL"
    case visual = "VISUAL"
    case command = "COMMAND"
    case filter = "FILTER"
    case driveSelect = "DRIVES"
    case aiAnalysis = "AI"
    case rename = "RENAME"  // 重命名模式 - 阻止键盘事件传播
    case settings = "SETTINGS"  // 设置模式 - 阻止键盘事件传播
    case help = "HELP"  // 帮助模式 - 阻止键盘事件传播

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

struct KeyChord: Hashable {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    init(_ key: KeyEquivalent, _ modifiers: EventModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    init(from keyPress: KeyPress) {
        self.key = keyPress.key
        self.modifiers = keyPress.modifiers
    }

    static func == (lhs: KeyChord, rhs: KeyChord) -> Bool {
        lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        // 如果 KeyEquivalent 本身是 Hashable（SwiftUI 里的就是），可以直接 combine
        hasher.combine(key)
        // EventModifiers 是 OptionSet，有 rawValue
        hasher.combine(modifiers.rawValue)
    }

}

enum AppAction {
    case none
    /// 模式相关
    case enterMode(AppMode)
    case exitMode

    /// 光标移动
    case moveCursor(CursorDirection)
    case moveVisualCursor(CursorDirection)
    case jumpToTop
    case jumpToBottom

    /// 目录操作
    case enterDirectory
    case leaveDirectory

    /// UI / 面板操作
    case toggleActivePane
    case newTab
    case closeTab
    case previousTab
    case nextTab
    case toggleBookmarkBar
    case openSettings
    case openHelp

    /// 文件操作
    case yank
    case paste
    case delete
    case batchRename
    case refreshCurrentPane

    /// 驱动器选择
    case enterDriveSelection
    case moveDriveCursor(CursorDirection)
    case selectDrive

    case cycleTheme

}

enum AppModeKeyMaps {
    static let normal: [KeyChord: AppAction] = [
        /// Vim 风格导航
        KeyChord("k"): .moveCursor(.up),
        KeyChord("j"): .moveCursor(.down),
        KeyChord("h"): .leaveDirectory,
        KeyChord("l"): .enterDirectory,

        /// 方向键导航
        KeyChord(.upArrow): .moveCursor(.up),
        KeyChord(.downArrow): .moveCursor(.down),
        KeyChord(.leftArrow): .leaveDirectory,
        KeyChord(.rightArrow): .enterDirectory,

        /// 模式切换
        KeyChord("v"): .enterMode(.visual),
        KeyChord(":"): .enterMode(.command),
        KeyChord("/"): .enterMode(.filter),

        /// Pane / Tab
        KeyChord(.tab): .toggleActivePane,
        KeyChord("H", [.shift]): .previousTab,
        KeyChord("L", [.shift]): .nextTab,
        KeyChord("t"): .newTab,
        KeyChord("w"): .closeTab,

        /// Theme
        KeyChord("t", [.control]): .cycleTheme,

        KeyChord("?"): .openHelp,

        KeyChord("b"): .toggleBookmarkBar,
        KeyChord("r"): .refreshCurrentPane,

        KeyChord("y"): .yank,
        KeyChord("p"): .paste,

        KeyChord("g"): .jumpToTop,
        KeyChord("G", [.shift]): .jumpToBottom,

    ]

    static let visual: [KeyChord: AppAction] = [
        KeyChord("y"): .yank
    ]
}

extension AppMode {

}
