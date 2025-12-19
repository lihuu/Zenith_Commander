//
//  AppMode+Keymaps.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import SwiftUI

/// 不同模式下的键盘映射扩展
extension AppMode {
    var keyMaps: [KeyChord: AppAction] {
        switch self {
        case .normal:
            AppModeKeyMaps.normal
        case .visual:
            AppModeKeyMaps.visual
        case .command:
            AppModeKeyMaps.command
        case .filter:
            AppModeKeyMaps.filter
        case .driveSelect:
            AppModeKeyMaps.driver
        case .rename:
            AppModeKeyMaps.rename
        case .batchRename:
            AppModeKeyMaps.batchRename
        case .settings:
            AppModeKeyMaps.settings
        case .help:
            AppModeKeyMaps.help
        case .modal:
            AppModeKeyMaps.modal  // No key maps for modal mode
        default:
            [:]
        }
    }

    func action(for keyPress: KeyPress) -> AppAction? {
        let chord = KeyChord(from: keyPress)
        let action: AppAction? = keyMaps[chord]
        if self == .command, action == nil {
            return .insertCommand(keyPress.key.character)
        }

        if self == .filter, action == nil {
            return .inputFilterCharacter(keyPress.key.character)
        }

        return action
    }

    func action(for pointer: PointerButton) -> AppAction? {
        switch self {
        case .normal:
            switch pointer {
            case .back:
                // should return back action
                nil

            case .forward:
                // should return forward action
                nil
            }
        default:
            nil
        }
    }
}

enum AppModeKeyMaps {
    static let defaultMap: [KeyChord: AppAction] = [
        KeyChord(.escape): .mode(.exitMode),
        KeyChord(",", [.command]): .mode(.enterMode(.settings)),
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
            KeyChord("v"): .mode(.enterMode(.visual)),
            KeyChord(":", [.shift]): .mode(.enterMode(.command)),
            KeyChord("/"): .mode(.enterMode(.filter)),

            /// Pane / Tab
            KeyChord(.tab): .toggleActivePane,
            KeyChord("H", [.shift]): .previousTab,
            KeyChord("L", [.shift]): .nextTab,
            KeyChord("t"): .newTab,
            KeyChord("w"): .closeTab,

            /// Theme
            KeyChord("t", [.control]): .cycleTheme,

            KeyChord("?", [.shift]): .mode(.enterMode(.help)),

            KeyChord("b"): .toggleBookmarkBar,
            KeyChord("b", [.command]): .addBookmark,
            KeyChord("r"): .refreshCurrentPane,

            /// 文件操作 (Vim 风格)
            KeyChord("y"): .yank,
            KeyChord("p"): .paste,

            /// 文件操作 (macOS 标准)
            KeyChord("c", [.command]): .yank,
            KeyChord("v", [.command]): .paste,
            KeyChord("x", [.command]): .cut,

            KeyChord("g"): .jumpToTop,
            KeyChord("G", [.shift]): .jumpToBottom,
            KeyChord("D", [.shift]): .mode(.enterMode(.driveSelect)),
            KeyChord("S", [.shift]): .openRsync,
        ]

        return normalOverrides.merging(defaultMap) { current, _ in
            current
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

            /// 文件操作 (Vim 风格)
            KeyChord("y"): .visualModeYank,
            KeyChord("d"): .deleteSelectedFiles,
            KeyChord("r"): .mode(.enterMode(.batchRename)),
            KeyChord("v"): .mode(.exitMode),
        ]

        return visualOverrides.merging(defaultMap) { current, _ in
            current
        }

    }()

    static let batchRename: [KeyChord: AppAction] = {
        let batchRenameOverrides: [KeyChord: AppAction] = [:]
        // 批量重命名模式只需要 Escape 退出即可，其他输入由 TextField 处理

        return batchRenameOverrides.merging(defaultMap) { current, _ in
            current
        }

    }()

    static let command: [KeyChord: AppAction] = {
        let commandOverrides: [KeyChord: AppAction] = [
            KeyChord(.delete): .deleteCommand,
            KeyChord(.deleteForward): .deleteCommand,
            KeyChord(.return): .executeCommand,
        ]

        return commandOverrides.merging(defaultMap) { current, _ in
            current
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
            _ in current
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
            current
        }
    }()

    static let rename: [KeyChord: AppAction] = defaultMap

    static let settings: [KeyChord: AppAction] = [
        KeyChord(.escape): .mode(.exitMode)
    ]

    static let help: [KeyChord: AppAction] = {
        let helpOverrides: [KeyChord: AppAction] = [
            KeyChord(.escape): .mode(.exitMode)
        ]

        return helpOverrides.merging(defaultMap) { current, _ in
            current
        }
    }()

    static let modal: [KeyChord: AppAction] = defaultMap
}

struct KeyChord: Hashable {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    init(_ key: KeyEquivalent, _ modifiers: EventModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    init(from keyPress: KeyPress) {
        key = keyPress.key
        modifiers = keyPress.modifiers
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
