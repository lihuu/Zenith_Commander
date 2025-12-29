//
//  AppState+Modes.swift
//  Zenith Commander
//
//  App 模式管理扩展
//

import Foundation
import SwiftUI

extension AppState {
    /// 进入模式
    func enterMode(_ newMode: AppMode) {
        previousMode = mode
        mode = newMode

        switch newMode {
        case .command:
            commandInput = ""
        case .batchRename:
            showRenameModal = true
        case .filter:
            filterUseRegex = false
            filterInput = ""
        case .visual:
            // 进入 Visual 模式时选中当前文件
            currentPane.startVisualSelection()
        case .driveSelect:
            showDriveSelector = true
        default:
            break
        }
    }

    func exitMode() {
        if mode == .visual {
            currentPane.clearSelections()
        }
        if mode == .driveSelect {
            showDriveSelector = false
        }
        // 退出 Filter 模式时，恢复未过滤的文件列表
        if mode == .filter {
            restoreUnfilteredFiles()
        }

        if mode == .batchRename {
            // 关闭重命名模态窗口
            showRenameModal = false
        }

        if mode == .modal {
            showConnectionManager = false
        }

        if mode == .batchRename {
            // Rename mode exit,should return visual mode if there are selections
            mode = .visual
        } else {
            mode = .normal
        }

        commandInput = ""
        filterInput = ""
        filterUseRegex = false
    }
}


enum ModeAction {
    case enterMode(AppMode)
    case exitMode
}
