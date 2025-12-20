//
//  AppAction.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import SwiftUI

enum AppAction: Sendable {
    case none
    case pane(PaneAction)
    case paneAsync(PaneAsyncAction)
    case mode(ModeAction)
    case file(FileAction)
    case ui(UIAction)
    case command(CommandAction)
    case commandAsync(CommandAsyncAction)
    /// 光标移动
    case moveCursor(CursorDirection)
    case moveVisualCursor(CursorDirection)

    /// 鼠标操作 - 统一通过模式系统处理
    case mouseClick(index: Int, paneSide: PaneSide) // 普通单击
    case mouseCommandClick(index: Int, paneSide: PaneSide) // Command+Click 切换选择
    case mouseShiftClick(index: Int, paneSide: PaneSide) // Shift+Click 范围选择
    case mouseDoubleClick(fileId: String, paneSide: PaneSide) // 双击

    /// UI / 面板操作
    case toggleActivePane
    case newTab
    case closeTab
    case previousTab
    case nextTab
    case toggleBookmarkBar
    case addBookmark

    /// 文件操作
    case yank
    case cut
    case visualModeYank
    case paste
    case deleteSelectedFiles
    case batchRename
    case startRenamingFile(fileName: String, filePath: String) // 开始单个文件重命名
    case refreshCurrentPane

    /// 驱动器选择
    case moveDriveCursor(CursorDirection)
    case selectDrive

    /// 同步操作
    case openRsync

    /// 命令操作
    case deleteCommand
    case executeCommand
    case insertCommand(Character)

    /// 过滤操作
    case deleteFilterCharacter
    case inputFilterCharacter(Character)
    case doFilter

    case cycleTheme
    case showSheet(UIRequest)
    case dismissSheet
    case toast(String)
}

enum PaneAction {
    case toggleActivePane
    case closeTab
    case toggleBookmarkBar
    case addBookmark
    /// 鼠标操作 - 统一通过模式系统处理
    case mouseClick(index: Int, paneSide: PaneSide) // 普通单击
    case mouseCommandClick(index: Int, paneSide: PaneSide) // Command+Click 切换选择
    case mouseShiftClick(index: Int, paneSide: PaneSide) // Shift+Click 范围选择
    case jumpToTop
    case jumpToBottom
}

// split async actions and common actions to avoid Sendable issues
enum PaneAsyncAction {
    case newTab
    case nextTab
    case previousTab
    case enterDirectory
    case leaveDirectory
    case refreshCurrentPane
    case mouseDoubleClick(fileId: String, paneSide: PaneSide) // 双击
}

enum UIAction {
    case toast(String)
}

enum ModeAction {
    case enterMode(AppMode)
    case exitMode
}

enum FileAction {
    case yank
    case cut
    case visualModeYank
    case paste
    case deleteSelectedFiles
    case batchRename
    case startRenamingFile(fileName: String, filePath: String) // 开始单个文件重命名
}

enum CommandAction {
    case deleteCommand
    case insertCommand(Character)
}

enum CommandAsyncAction {
    case executeCommand
}

enum FilterAction {
    case deleteFilterCharacter
    case inputFilterCharacter(Character)
    case doFilter
}
