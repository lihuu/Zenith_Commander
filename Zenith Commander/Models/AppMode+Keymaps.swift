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
            AppModeKeyMaps.modal // No key maps for modal mode
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