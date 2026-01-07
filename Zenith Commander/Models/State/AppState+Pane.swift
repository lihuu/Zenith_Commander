//
//  AppState+Pane.swift
//  Zenith Commander
//
//  面板操作相关的 AppState 扩展
//

import Combine
import Foundation
import SwiftUI

extension AppState {
    // MARK: - 计算属性

    /// 当前活动面板
    var currentPane: PaneState {
        activePane == .left ? leftPane : rightPane
    }

    /// 非活动面板
    var inactivePane: PaneState {
        activePane == .left ? rightPane : leftPane
    }

    // MARK: - 面板操作

    /// 切换活动面板
    func toggleActivePane() {
        activePane = activePane.opposite
    }

    /// 设置活动面板
    func setActivePane(_ side: PaneSide) {
        activePane = side
    }

    func refreshCurrentPane() async {
        await currentPane.refresh(using: env.fileSystem)
    }

    /// 恢复未过滤的文件列表
    func restoreUnfilteredFiles() {
        let tab = currentPane.activeTab
        if !tab.unfilteredFiles.isEmpty {
            tab.files = tab.unfilteredFiles
            tab.unfilteredFiles = []
            currentPane.cursorIndex = min(
                currentPane.cursorIndex,
                tab.files.count - 1
            )
            if currentPane.cursorIndex < 0 {
                currentPane.cursorIndex = 0
            }
        }
    }

    // MARK: - Action Handlers

    func handleAction(_ action: PaneAction) {
        switch action {
        case .toggleActivePane:
            toggleActivePane()
        case .closeTab:
            closeTab()
        case .addBookmark:
            addCurrentToBookmark()
        case .toggleBookmarkBar:
            withAnimation(.easeInOut(duration: 0.2)) {
                showBookmarkBar.toggle()
            }
            showToast(
                showBookmarkBar
                    ? LocalizationManager.shared.localized(
                        .toastBookmarkBarShown
                    )
                    : LocalizationManager.shared.localized(
                        .toastBookmarkBarHidden
                    )
            )
        case .mouseClick(let index, let paneSide):
            handleMouseClick(at: index, paneSide: paneSide)
        case .mouseCommandClick(let index, let paneSide):
            handleMouseCommandClick(at: index, paneSide: paneSide)
        case .mouseShiftClick(let index, let paneSide):
            handleMouseShiftClick(at: index, paneSide: paneSide)
        case .jumpToTop:
            jumpToTop()
        case .jumpToBottom:
            jumpToBottom()
        case .updatePane(let files):
            updatePaneFiles(files)
        }
    }

    // MARK: - 鼠标操作（统一通过模式系统处理）

    /// 处理普通单击
    /// - 在 Normal 模式下：移动光标
    /// - 在 Visual 模式下：移动光标并更新选择范围
    func handleMouseClick(at index: Int, paneSide: PaneSide) {
        // 切换活动面板
        setActivePane(paneSide)
        let pane = paneSide == .left ? leftPane : rightPane

        // 移动光标
        pane.cursorIndex = index

        // 如果在 Visual 模式下，更新选择范围
        if mode == .visual {
            pane.updateVisualSelection()
        }
    }

    /// 处理 Command+Click（切换选择）
    /// - 自动进入 Visual 模式
    /// - 切换点击项的选择状态
    func handleMouseCommandClick(at index: Int, paneSide: PaneSide) {
        setActivePane(paneSide)
        let pane = paneSide == .left ? leftPane : rightPane

        // 获取目标文件
        guard let file = pane.activeTab.files[safe: index] else { return }

        // 父目录项不能被选中
        guard !file.isParentDirectory else { return }

        // 如果不在 Visual 模式，先进入 Visual 模式
        if mode != .visual {
            // 进入 Visual 模式但不设置锚点（因为我们要做切换选择）
            mode = .visual
            pane.visualAnchor = nil  // 清除锚点，因为 Command+Click 是独立选择
        }

        // 移动光标到点击位置
        pane.cursorIndex = index

        // 切换选择状态
        pane.toggleSelection(for: file.id)

        // 如果没有选中项了，退出 Visual 模式
        if pane.selections.isEmpty {
            exitMode()
        }
    }

    /// 处理 Shift+Click（范围选择）
    /// - 自动进入 Visual 模式
    /// - 从锚点（或当前光标）到点击位置进行范围选择
    func handleMouseShiftClick(at index: Int, paneSide: PaneSide) {
        setActivePane(paneSide)
        let pane = paneSide == .left ? leftPane : rightPane

        // 如果不在 Visual 模式，先进入 Visual 模式
        if mode != .visual {
            // 设置当前光标位置为锚点
            pane.visualAnchor = pane.cursorIndex
            mode = .visual
        }

        // 如果没有锚点，以当前光标为锚点
        if pane.visualAnchor == nil {
            pane.visualAnchor = pane.cursorIndex
        }

        // 移动光标到点击位置
        pane.cursorIndex = index

        // 更新范围选择
        pane.updateVisualSelection()
    }

    // MARK: - 光标操作

    func moveCursor(_ direction: CursorDirection) async {
        let pane = currentPane
        let files = pane.activeTab.files
        let fileCount = files.count
        guard fileCount > 0 else { return }

        var currentIndex = pane.cursorIndex

        if pane.viewMode == .grid {
            // Grid View 模式：支持四向导航
            let columnCount = pane.gridColumnCount
            switch direction {
            case .up:
                // 向上移动一行
                currentIndex = max(0, currentIndex - columnCount)
            case .down:
                // 向下移动一行
                currentIndex = min(
                    fileCount - 1,
                    currentIndex + columnCount
                )
            case .left:
                // 向左移动一格
                currentIndex = max(0, currentIndex - 1)
            case .right:
                // 向右移动一格
                currentIndex = min(fileCount - 1, currentIndex + 1)
            }
        } else {
            // List View 模式：只支持上下导航
            switch direction {
            case .up:
                currentIndex = max(0, currentIndex - 1)
            case .down:
                currentIndex = min(fileCount - 1, currentIndex + 1)
            case .left:
                await leaveDirectory()
                return  // leaveDirectory 已经处理了光标，直接返回
            case .right:
                await enterDirectory()
                return  // enterDirectory 已经处理了光标，直接返回
            }
        }

        // 重新获取当前文件数量，防止执行期间文件列表发生变化
        let currentFiles = pane.activeTab.files
        let actualFileCount = currentFiles.count

        guard actualFileCount > 0 else { return }

        // 确保索引在有效范围内
        let safeIndex = min(max(0, currentIndex), actualFileCount - 1)

        pane.activeTab.cursorFileId = currentFiles[safeIndex].id
    }

    func moveVisualCursor(_ direction: CursorDirection) async {
        let pane = currentPane
        let files = pane.activeTab.files
        let fileCount = files.count
        guard fileCount > 0 else { return }

        var currentIndex = pane.cursorIndex

        if pane.viewMode == .grid {
            // Grid View 模式：支持四向导航
            let columnCount = pane.gridColumnCount
            switch direction {
            case .up:
                currentIndex = max(0, currentIndex - columnCount)
            case .down:
                currentIndex = min(
                    fileCount - 1,
                    currentIndex + columnCount
                )
            case .left:
                currentIndex = max(0, currentIndex - 1)
            case .right:
                currentIndex = min(fileCount - 1, currentIndex + 1)
            }
        } else {
            // List View 模式：只支持上下导航
            switch direction {
            case .up:
                currentIndex = max(0, currentIndex - 1)
            case .down:
                currentIndex = min(fileCount - 1, currentIndex + 1)
            case .left, .right:
                return
            }
        }

        // 重新获取当前文件数量，防止执行期间文件列表发生变化
        let currentFiles = pane.activeTab.files
        let actualFileCount = currentFiles.count

        guard actualFileCount > 0 else { return }

        // 确保索引在有效范围内
        let safeIndex = min(max(0, currentIndex), actualFileCount - 1)

        pane.activeTab.cursorFileId = currentFiles[safeIndex].id
        pane.updateVisualSelection()
        pane.objectWillChange.send()
    }

    // MARK: - 目录导航

    func enterDirectory() async {
        let pane = currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex] else {
            return
        }

        guard file.isFolder else {
            env.fileSystem.openFile(file)
            return
        }

        let newPath = file.path
        let files = await env.fileSystem.loadDirectory(at: newPath)

        pane.activeTab.currentPath = newPath
        pane.activeTab.files = files
        pane.cursorIndex = 0
        pane.clearSelections()
    }

    func leaveDirectory() async {
        let pane = currentPane
        let currentPath = pane.activeTab.currentPath
        let parent = env.fileSystem.parentDirectory(of: currentPath)

        // 检查是否已经在根目录
        if currentPath.path != "/" {
            // 记住当前目录名，用于返回后定位
            let currentDirName = currentPath.lastPathComponent

            let files = await env.fileSystem.loadDirectory(at: parent)
            pane.activeTab.files = files

            pane.activeTab.currentPath = parent
            pane.clearSelections()

            // 在上级目录中找到之前所在的目录并选中
            if let index = pane.activeTab.files.firstIndex(where: {
                $0.name == currentDirName
            }) {
                pane.activeTab.cursorFileId = pane.activeTab.files[index].id
            } else {
                pane.cursorIndex = 0
            }
        }
    }

    // MARK: - 标签页操作

    func newTab() async {
        let pane = currentPane
        pane.addTab()
        await refreshCurrentPane()
        showToast("New tab created")
    }

    func previousTab() async {
        currentPane.previousTab()
        await refreshCurrentPane()
    }

    func nextTab() async {
        currentPane.nextTab()
        await refreshCurrentPane()
    }

    func closeTab() {
        let pane = currentPane
        if pane.tabs.count > 1 {
            pane.closeTab(at: pane.activeTabIndex)
        }
    }

    // MARK: - 书签操作

    /// 添加当前选中项到书签
    func addCurrentToBookmark() {
        let pane = currentPane
        let bookmarkManager = BookmarkManager.shared

        // 如果有选中的文件，添加所有选中项
        if !pane.selections.isEmpty {
            var addedCount = 0
            for fileId in pane.selections {
                if let file = pane.activeTab.files.first(where: {
                    $0.id == fileId
                }) {
                    if !bookmarkManager.contains(path: file.path) {
                        bookmarkManager.addBookmark(for: file)
                        addedCount += 1
                    }
                }
            }
            if addedCount <= 0 {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastAlreadyBookmarked
                    )
                )
            }
        } else {
            // 否则添加当前光标所在的文件
            let files = pane.activeTab.files
            guard pane.cursorIndex < files.count else { return }

            let file = files[pane.cursorIndex]
            if bookmarkManager.contains(path: file.path) {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastAlreadyBookmarked
                    )
                )
            } else {
                bookmarkManager.addBookmark(for: file)
                showToast(
                    LocalizationManager.shared.localized(.toastBookmarkAdded)
                )
            }
        }
    }

    // MARK: - 光标跳转

    func jumpToTop() {
        let pane = currentPane
        pane.cursorIndex = 0

        if mode == .visual {
            pane.updateVisualSelection()
        }
    }

    func jumpToBottom() {
        let pane = currentPane
        pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
        if mode == .visual {
            pane.updateVisualSelection()
        }
    }

    /// 更新面板的文件列表（用于搜索结果等场景）
    func updatePaneFiles(_ files: [FileItem]) {
        let pane = currentPane

        // 保存未过滤的文件列表（如果还没有保存）
        if pane.activeTab.unfilteredFiles.isEmpty {
            pane.activeTab.unfilteredFiles = pane.activeTab.files
        }

        // 更新文件列表
        pane.activeTab.files = files

        // 重置光标到第一个文件
        pane.cursorIndex = files.isEmpty ? 0 : 0

        // 清除选择
        pane.clearSelections()

        // 退出 Visual 模式
        if mode == .visual {
            exitMode()
        }
    }

    /// 处理双击
    /// - 文件夹：进入目录
    /// - 文件：使用默认应用打开
    func handleMouseDoubleClick(fileId: String, paneSide: PaneSide) async {
        setActivePane(paneSide)
        let pane = paneSide == .left ? leftPane : rightPane

        guard let file = pane.activeTab.files.first(where: { $0.id == fileId })
        else { return }

        if file.isFolder {
            // 进入目录
            let newPath = file.path
            let files = await env.fileSystem.loadDirectory(at: newPath)

            pane.activeTab.currentPath = newPath
            pane.activeTab.files = files
            pane.cursorIndex = 0
            pane.clearSelections()

            // 如果在 Visual 模式，退出
            if mode == .visual {
                exitMode()
            }
        } else {
            // 打开文件
            env.fileSystem.openFile(file)
        }
    }

    func handleAction(_ action: PaneAsyncAction) async {
        switch action {
        case .newTab:
            await newTab()
        case .nextTab:
            await nextTab()
        case .previousTab:
            await previousTab()
        case .enterDirectory:
            await enterDirectory()
        case .leaveDirectory:
            await leaveDirectory()
        case .refreshCurrentPane:
            await refreshCurrentPane()
        case .mouseDoubleClick(let fileId, let paneSide):
            await handleMouseDoubleClick(
                fileId: fileId,
                paneSide: paneSide
            )
        }
    }
}

enum PaneAction {
    case toggleActivePane
    case closeTab
    case toggleBookmarkBar
    case addBookmark
    /// 鼠标操作 - 统一通过模式系统处理
    case mouseClick(index: Int, paneSide: PaneSide)  // 普通单击
    case mouseCommandClick(index: Int, paneSide: PaneSide)  // Command+Click 切换选择
    case mouseShiftClick(index: Int, paneSide: PaneSide)  // Shift+Click 范围选择
    case jumpToTop
    case jumpToBottom
    case updatePane(files: [FileItem])  // 更新面板文件列表
}

// split async actions and common actions to avoid Sendable issues
enum PaneAsyncAction {
    case newTab
    case nextTab
    case previousTab
    case enterDirectory
    case leaveDirectory
    case refreshCurrentPane
    case mouseDoubleClick(fileId: String, paneSide: PaneSide)  // 双击
}
