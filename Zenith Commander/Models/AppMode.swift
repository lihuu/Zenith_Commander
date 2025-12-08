//
//  AppMode.swift
//  Zenith Commander
//
//  应用模式定义
//  定义了各种应用模式（类似 Vim 风格的 NORMAL, VISUAL, COMMAND 等）及其相关属性和行为
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
    case modal = "MODAL" // 模态模式 - 阻止键盘事件传播

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
        case .modal:
            return .gray.opacity(0.5)
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
        case .rename, .settings, .aiAnalysis, .help, .modal:
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
        case .modal:
            return "Modal mode - interacting with dialog"
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

    /// 鼠标操作 - 统一通过模式系统处理
    case mouseClick(index: Int, paneSide: PaneSide)  // 普通单击
    case mouseCommandClick(index: Int, paneSide: PaneSide)  // Command+Click 切换选择
    case mouseShiftClick(index: Int, paneSide: PaneSide)  // Shift+Click 范围选择
    case mouseDoubleClick(fileId: String, paneSide: PaneSide)  // 双击

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
    case addBookmark
    case openSettings
    case openHelp
    case closeHelp

    /// 文件操作
    case yank
    case visualModeYank
    case paste
    case deleteSelectedFiles
    case batchRename
    case refreshCurrentPane

    /// 驱动器选择
    case enterDriveSelection
    case moveDriveCursor(CursorDirection)
    case selectDrive

    /// 命令操作
    case deleteCommand
    case executeCommand
    case insertCommand(Character)

    /// 过滤操作
    case deleteFilterCharacter
    case inputFilterCharacter(Character)
    case doFilter

    case cycleTheme

}

/// 按键映射表，把按键和动作关联起来，方便支持不同模式的快捷键
/// 动作的处理逻辑，暂时在 MainView 和 AppState 里面
/// 后面如果，再添加新的按键映射，可以不用修改MainView和AppState的代码，只需要在这里添加新的映射即可，后面可能会在设置里面添加自定义按键映射的功能
enum AppModeKeyMaps {

    static let defaultMap: [KeyChord: AppAction] = [
        KeyChord(.escape): .exitMode,
        KeyChord(",", [.command]): .enterMode(.settings),
    ]

    static let normal: [KeyChord: AppAction] = {
        let normalOverrides: [KeyChord: AppAction] = [
            /// Vim 风格导航
            KeyChord("k"): .moveCursor(.up),
            KeyChord("j"): .moveCursor(.down),
            KeyChord("h"): .moveCursor(.left),
            KeyChord("l"): .moveCursor(.right),

            /// 方向键导航
            KeyChord(.upArrow): .moveCursor(.up),
            KeyChord(.downArrow): .moveCursor(.down),
            KeyChord(.leftArrow): .moveCursor(.left),
            KeyChord(.rightArrow): .moveCursor(.right),

            KeyChord(.return): .enterDirectory,

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

            KeyChord("?", [.shift]): .openHelp,

            KeyChord("b"): .toggleBookmarkBar,
            KeyChord("b", [.command]): .addBookmark,
            KeyChord("r"): .refreshCurrentPane,

            KeyChord("y"): .yank,
            KeyChord("p"): .paste,

            KeyChord("g"): .jumpToTop,
            KeyChord("G", [.shift]): .jumpToBottom,
            KeyChord("D", [.shift]): .enterDriveSelection,
        ]

        return normalOverrides.merging(defaultMap) { current, _ in
            return current
        }

    }()

    static let visual: [KeyChord: AppAction] = {
        let visualOverrides: [KeyChord: AppAction] = [
            KeyChord("j"): .moveVisualCursor(.down),
            KeyChord("k"): .moveVisualCursor(.up),
            // Grid 模式的特殊处理
            KeyChord("h"): .moveVisualCursor(.left),
            KeyChord("l"): .moveVisualCursor(.right),
            KeyChord(.downArrow): .moveVisualCursor(.down),
            KeyChord(.upArrow): .moveVisualCursor(.up),
            KeyChord(.leftArrow): .moveVisualCursor(.left),
            KeyChord(.rightArrow): .moveVisualCursor(.right),
            KeyChord("y"): .visualModeYank,
            KeyChord("d"): .deleteSelectedFiles,
            KeyChord("r"): .enterMode(.rename),
            KeyChord("v"): .exitMode,
        ]

        return visualOverrides.merging(defaultMap) { current, _ in
            return current
        }

    }()

    static let command: [KeyChord: AppAction] = {
        let commandOverrides: [KeyChord: AppAction] = [
            KeyChord(.delete): .deleteCommand,
            KeyChord(.deleteForward): .deleteCommand,
            KeyChord(.return): .executeCommand,
        ]

        return commandOverrides.merging(defaultMap) { current, _ in
            return current
        }
    }()

    static let filter: [KeyChord: AppAction] = {
        let filterOverrides: [KeyChord: AppAction] = [
            KeyChord(.delete): .deleteFilterCharacter,
            KeyChord(.deleteForward): .deleteFilterCharacter,
            // 这里的输入字符，交给默认处理，然后通过绑定更新过滤字符串
            KeyChord(.return): .doFilter,
        ]

        return filterOverrides.merging(defaultMap) {
            current,
            _ in return current
        }
    }()

    static let driver: [KeyChord: AppAction] = {
        let driverOverrides: [KeyChord: AppAction] = [
            KeyChord("j"): .moveDriveCursor(.down),
            KeyChord("k"): .moveDriveCursor(.up),
            KeyChord(.downArrow): .moveDriveCursor(.down),
            KeyChord(.upArrow): .moveDriveCursor(.up),
            KeyChord(.return): .selectDrive,
        ]

        return driverOverrides.merging(defaultMap) { current, _ in
            return current
        }
    }()

    static let rename: [KeyChord: AppAction] = defaultMap

    static let settings: [KeyChord: AppAction] = [
        KeyChord(.escape): .exitMode
    ]

    static let help: [KeyChord: AppAction] = {
        let helpOverrides: [KeyChord: AppAction] = [
            KeyChord(.escape): .closeHelp
        ]

        return helpOverrides.merging(defaultMap) { current, _ in
            return current
        }
    }()
    
    static let modal: [KeyChord: AppAction] = defaultMap

}

/// 不同模式下的键盘映射扩展
extension AppMode {
    var keyMaps: [KeyChord: AppAction] {
        switch self {
        case .normal:
            return AppModeKeyMaps.normal
        case .visual:
            return AppModeKeyMaps.visual
        case .command:
            return AppModeKeyMaps.command
        case .filter:
            return AppModeKeyMaps.filter
        case .driveSelect:
            return AppModeKeyMaps.driver
        case .rename:
            return AppModeKeyMaps.rename
        case .settings:
            return AppModeKeyMaps.settings
        case .help:
            return AppModeKeyMaps.help
        case .modal:
            return AppModeKeyMaps.modal // No key maps for modal mode
        default:
            return [:]
        }
    }

    func action(for keyPress: KeyPress) -> AppAction? {
        let chord = KeyChord(from: keyPress)
        let action: AppAction? = keyMaps[chord]
        if self == .command && action == nil {
            return .insertCommand(keyPress.key.character)
        }

        if self == .filter && action == nil {
            return .inputFilterCharacter(keyPress.key.character)
        }

        return action
    }
    
    func action(for pointer: PointerButton) -> AppAction? {
        switch self{
        case .normal:
            switch pointer{
            case .back:
                // should return back action
                return nil
                
            case .forward:
                // should return forward action
                return nil
            }
        default:
            return nil
        }
    }
}



enum PointerButton{
    case back
    case forward
}


