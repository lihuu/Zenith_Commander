//
//  MainView.swift
//  Zenith Commander
//
//  主视图 - 双面板布局
//

import Combine
import SwiftUI

struct MainView: View {
    @StateObject private var appState = AppState()
    @StateObject private var bookmarkManager = BookmarkManager()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showSettings = false
    @State private var showHelp = false  // 帮助视图显示状态
    @State private var showBookmarkBar = true  // 书签栏显示状态

    var body: some View {
        VStack(spacing: 0) {
            // 书签栏
            if showBookmarkBar {
                BookmarkBarView(
                    bookmarkManager: bookmarkManager,
                    onBookmarkClicked: { bookmark in
                        navigateToBookmark(bookmark)
                    }
                )
            }

            // 双面板区域
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // 左面板
                        PaneView(
                            pane: appState.leftPane,
                            bookmarkManager: bookmarkManager,
                            side: .left
                        )
                        .frame(width: geometry.size.width / 2)

                        // 分隔线
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 1)

                        // 右面板
                        PaneView(
                            pane: appState.rightPane,
                            bookmarkManager: bookmarkManager,
                            side: .right
                        )
                        .frame(width: geometry.size.width / 2 - 1)
                    }
                    
                    // Git History 底部面板
                    if appState.showGitHistory {
                        ResizableBottomPanel(
                            height: $appState.gitHistoryPanelHeight,
                            isVisible: $appState.showGitHistory,
                            minHeight: 100,
                            maxHeight: geometry.size.height * 0.6
                        ) {
                            GitHistoryPanelView(
                                fileName: appState.gitHistoryFile?.name ?? "",
                                commits: appState.gitHistoryCommits,
                                isLoading: appState.gitHistoryLoading,
                                onClose: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.closeGitHistory()
                                    }
                                },
                                onCommitSelected: { commit in
                                    // TODO: 显示 commit 详情或 diff
                                }
                            )
                        }
                    }
                }
            }
            .environmentObject(appState)

            // 状态栏
            StatusBarView(
                mode: appState.mode,
                statusText: appState.statusText,
                driveName: appState.currentPane.activeTab.drive.name,
                itemCount: appState.currentPane.activeTab.files.count,
                selectedCount: appState.currentPane.selections.count,
                gitInfo: appState.currentPane.gitInfo,
                onDriveClick: {
                    appState.enterMode(.driveSelect)
                }
            )
        }
        .background(Theme.background)
        .toast(message: appState.toastMessage)
        .overlay {
            // 驱动器选择器
            if appState.showDriveSelector {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.exitMode()
                    }

                DriveSelectorView(
                    drives: appState.availableDrives,
                    cursorIndex: appState.driveSelectorCursor,
                    onSelect: { drive in
                        selectDrive(drive)
                    },
                    onDismiss: {
                        appState.exitMode()
                    }
                )
            }

            // 批量重命名模态窗口
            if appState.showRenameModal {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.showRenameModal = false
                        appState.exitMode()  // 退出 RENAME 模式
                    }

                BatchRenameView(
                    isPresented: $appState.showRenameModal,
                    findText: $appState.renameFindText,
                    replaceText: $appState.renameReplaceText,
                    useRegex: $appState.renameUseRegex,
                    selectedFiles: getSelectedFiles(),
                    onApply: {
                        performBatchRename()
                    },
                    onDismiss: {
                        appState.exitMode()  // 退出 RENAME 模式
                    }
                )
            }
        }
        .sheet(
            isPresented: $showSettings,
            onDismiss: {
                // 关闭设置时退出 SETTINGS 模式
                appState.exitMode()
            }
        ) {
            SettingsView()
        }
        .sheet(
            isPresented: $showHelp,
            onDismiss: {
                // 关闭帮助时退出 HELP 模式
                appState.exitMode()
            }
        ) {
            HelpView()
        }
        .focusable()
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .onAppear {
            // 加载可用驱动器 - 使用异步更新避免在视图更新期间修改 @Published 属性
            DispatchQueue.main.async {
                appState.availableDrives = FileSystemService.shared
                    .getMountedVolumes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) {
            _ in
            appState.enterMode(.settings)  // 进入 SETTINGS 模式
            showSettings = true
        }
    }

    // MARK: - 键盘处理

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let key = keyPress.key
        let modifiers = keyPress.modifiers

        // ESC - 退出当前模式
        if key == .escape {
            Task { @MainActor in
                // 如果在 Visual 模式，清除选中状态
                if appState.mode == .visual {
                    appState.currentPane.clearSelections()
                }
                appState.exitMode()
            }
            return .handled
        }

        // Cmd+, - 打开设置
        if key == KeyEquivalent(",") && modifiers.contains(.command) {
            Task { @MainActor in
                appState.enterMode(.settings)  // 进入 SETTINGS 模式
                showSettings = true
            }
            return .handled
        }

        // 模态模式：忽略所有键盘事件，让模态窗口/视图处理
        if appState.mode.isModalMode {
            return .ignored
        }

        // 根据模式处理按键
        switch appState.mode {
        case .normal:
            return handleNormalModeKey(key, modifiers: modifiers)
        case .visual:
            return handleVisualModeKey(key, modifiers: modifiers)
        case .command:
            return handleCommandModeKey(keyPress)
        case .filter:
            return handleFilterModeKey(keyPress)
        case .driveSelect:
            return handleDriveSelectModeKey(key)
        default:
            // 其他未处理的模式
            return .ignored
        }
    }

    // MARK: - Normal 模式

    private func handleNormalModeKey(
        _ key: KeyEquivalent,
        modifiers: EventModifiers
    ) -> KeyPress.Result {
        let pane = appState.currentPane
        let isGridView = pane.viewMode == .grid

        switch key {
        // 方向键导航
        case .upArrow:
            moveCursor(direction: .up)
            return .handled

        case .downArrow:
            moveCursor(direction: .down)
            return .handled

        case .leftArrow:
            if isGridView {
                moveCursor(direction: .left)
            } else {
                Task { @MainActor in leaveDirectory() }
            }
            return .handled

        case .rightArrow:
            if isGridView {
                moveCursor(direction: .right)
            } else {
                Task { @MainActor in enterDirectory() }
            }
            return .handled

        // Vim 风格导航
        case KeyEquivalent("j"):
            moveCursor(direction: .down)
            return .handled

        case KeyEquivalent("k"):
            moveCursor(direction: .up)
            return .handled

        case KeyEquivalent("h"):
            if isGridView {
                moveCursor(direction: .left)
            } else {
                Task { @MainActor in leaveDirectory() }
            }
            return .handled

        case KeyEquivalent("l"):
            if isGridView {
                moveCursor(direction: .right)
            } else {
                Task { @MainActor in enterDirectory() }
            }
            return .handled

        case .return:
            Task { @MainActor in enterDirectory() }
            return .handled

        // 切换面板
        case .tab:
            Task { @MainActor in appState.toggleActivePane() }
            return .handled

        // 模式切换
        case KeyEquivalent("v"):
            Task { @MainActor in
                appState.enterMode(.visual)
                appState.currentPane.startVisualSelection()
            }
            return .handled

        case KeyEquivalent(":"):
            Task { @MainActor in appState.enterMode(.command) }
            return .handled

        case KeyEquivalent("/"):
            Task { @MainActor in
                appState.enterMode(.filter)
                appState.filterUseRegex = false
            }
            return .handled

        // 帮助 (?)
        case KeyEquivalent("?"):
            Task { @MainActor in
                appState.enterMode(.help)
                showHelp = true
            }
            return .handled

        // 驱动器选择 (Shift + D)
        case KeyEquivalent("D"):
            if modifiers.contains(.shift) {
                Task { @MainActor in appState.enterMode(.driveSelect) }
                return .handled
            }
            return .ignored

        // 关闭标签页
        case KeyEquivalent("w"):
            Task { @MainActor in
                let pane = appState.currentPane
                if pane.tabs.count > 1 {
                    pane.closeTab(at: pane.activeTabIndex)
                }
            }
            return .handled

        // Shift + H/L 切换标签页
        case KeyEquivalent("H"):
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    appState.currentPane.previousTab()
                    refreshCurrentPane()
                }
                return .handled
            }
            return .ignored

        case KeyEquivalent("L"):
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    appState.currentPane.nextTab()
                    refreshCurrentPane()
                }
                return .handled
            }
            return .ignored

        // 复制/粘贴
        case KeyEquivalent("y"):
            Task { @MainActor in appState.yankSelectedFiles() }
            return .handled

        case KeyEquivalent("p"):
            Task { @MainActor in pasteFiles() }
            return .handled

        // 跳转到顶部/底部
        case KeyEquivalent("g"):
            Task { @MainActor in appState.currentPane.cursorIndex = 0 }
            return .handled

        case KeyEquivalent("G"):
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    let pane = appState.currentPane
                    pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
                }
                return .handled
            }
            return .ignored

        // 主题切换 (Ctrl+T)
        case KeyEquivalent("t"):
            if modifiers.contains(.control) {
                Task { @MainActor in
                    themeManager.cycleTheme()
                    appState.showToast(
                        "Theme: \(themeManager.mode.displayName)"
                    )
                }
                return .handled
            }
            // 没有 Ctrl 修饰符时，创建新标签页
            Task { @MainActor in
                let pane = appState.currentPane
                pane.addTab()
                refreshCurrentPane()
                appState.showToast("New tab created")
            }
            return .handled

        // 刷新当前目录 (R 或 Cmd+R)
        case KeyEquivalent("r"):
            Task { @MainActor in
                refreshCurrentPane()
                appState.showToast("Refreshed")
            }
            return .handled

        // 切换书签栏显示 (B)
        case KeyEquivalent("b"):
            if modifiers.contains(.command) {
                // Cmd+B 添加当前选中项到书签
                Task { @MainActor in
                    addCurrentToBookmark()
                }
            } else {
                // B 切换书签栏显示
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBookmarkBar.toggle()
                    }
                    appState.showToast(
                        showBookmarkBar
                            ? "Bookmark bar shown" : "Bookmark bar hidden"
                    )
                }
            }
            return .handled

        default:
            return .ignored
        }
    }

    // MARK: - Visual 模式

    private func handleVisualModeKey(
        _ key: KeyEquivalent,
        modifiers: EventModifiers
    ) -> KeyPress.Result {
        let pane = appState.currentPane
        let isGridView = pane.viewMode == .grid

        switch key {
        // 方向键导航
        case .upArrow:
            moveVisualCursor(direction: .up)
            return .handled

        case .downArrow:
            moveVisualCursor(direction: .down)
            return .handled

        case .leftArrow:
            if isGridView {
                moveVisualCursor(direction: .left)
            }
            return .handled

        case .rightArrow:
            if isGridView {
                moveVisualCursor(direction: .right)
            }
            return .handled

        // Vim 风格导航
        case KeyEquivalent("j"):
            moveVisualCursor(direction: .down)
            return .handled

        case KeyEquivalent("k"):
            moveVisualCursor(direction: .up)
            return .handled

        case KeyEquivalent("h"):
            if isGridView {
                moveVisualCursor(direction: .left)
            }
            return .handled

        case KeyEquivalent("l"):
            if isGridView {
                moveVisualCursor(direction: .right)
            }
            return .handled

        case KeyEquivalent("g"):
            // 跳到顶部
            Task { @MainActor in
                let pane = appState.currentPane
                pane.cursorIndex = 0
                pane.updateVisualSelection()
                pane.objectWillChange.send()
            }
            return .handled

        case KeyEquivalent("G"):
            // 跳到底部
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    let pane = appState.currentPane
                    pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
                    pane.updateVisualSelection()
                    pane.objectWillChange.send()
                }
                return .handled
            }
            return .ignored

        case KeyEquivalent("y"):
            Task { @MainActor in
                let pane = appState.currentPane
                appState.yankSelectedFiles()
                appState.exitMode()
                pane.clearSelections()
            }
            return .handled

        case KeyEquivalent("d"):
            // 删除选中文件
            Task { @MainActor in
                let pane = appState.currentPane
                deleteSelectedFiles()
                appState.exitMode()
                pane.clearSelections()
            }
            return .handled

        case KeyEquivalent("r"):
            // 批量重命名 - 进入 RENAME 模式
            Task { @MainActor in
                appState.enterMode(.rename)
                appState.showRenameModal = true
            }
            return .handled

        case KeyEquivalent("v"), .escape:
            // 退出 Visual 模式
            Task { @MainActor in
                appState.currentPane.clearSelections()
                appState.exitMode()
            }
            return .handled

        default:
            return .ignored
        }
    }

    // MARK: - Command 模式

    private func handleCommandModeKey(_ keyPress: KeyPress) -> KeyPress.Result {
        let key = keyPress.key

        switch key {
        case .return:
            Task { @MainActor in
                executeCommand()
            }
            return .handled

        case .delete:
            Task { @MainActor in
                if !appState.commandInput.isEmpty {
                    appState.commandInput.removeLast()
                }
            }
            return .handled

        default:
            let char = key.character
            if char.isLetter || char.isNumber || char.isWhitespace
                || char.isPunctuation
            {
                Task { @MainActor in
                    appState.commandInput.append(char)
                }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Filter 模式

    private func handleFilterModeKey(_ keyPress: KeyPress) -> KeyPress.Result {
        let key = keyPress.key

        switch key {
        case .return:
            // 按 Enter 确认过滤，保持当前过滤结果，清空 unfilteredFiles
            Task { @MainActor in
                let pane = appState.currentPane
                pane.activeTab.unfilteredFiles = []
                appState.mode = .normal
                appState.filterInput = ""
                appState.filterUseRegex = false
            }
            return .handled

        case .delete:
            Task { @MainActor in
                if !appState.filterInput.isEmpty {
                    appState.filterInput.removeLast()
                    // 实时更新过滤
                    applyFilter()
                }
            }
            return .handled

        default:
            let char = key.character
            // 普通过滤支持常用字符，正则表达式支持更多特殊字符
            let isValidChar: Bool
            if appState.filterUseRegex {
                // 正则表达式模式：支持更多字符
                isValidChar =
                    char.isLetter || char.isNumber || char.isWhitespace
                    || "._-*+?^$[](){}|\\".contains(char)
            } else {
                // 普通模式：支持基本字符
                isValidChar =
                    char.isLetter || char.isNumber || "._- ".contains(char)
            }

            if isValidChar {
                Task { @MainActor in
                    appState.filterInput.append(char)
                    // 实时过滤
                    applyFilter()
                }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Drive Select 模式

    private func handleDriveSelectModeKey(_ key: KeyEquivalent)
        -> KeyPress.Result
    {
        switch key {
        case KeyEquivalent("j"):
            Task { @MainActor in
                if appState.driveSelectorCursor < appState.availableDrives.count
                    - 1
                {
                    appState.driveSelectorCursor += 1
                }
            }
            return .handled

        case KeyEquivalent("k"):
            Task { @MainActor in
                if appState.driveSelectorCursor > 0 {
                    appState.driveSelectorCursor -= 1
                }
            }
            return .handled

        case .return:
            Task { @MainActor in
                if let drive = appState.availableDrives[
                    safe: appState.driveSelectorCursor
                ] {
                    selectDrive(drive)
                }
            }
            return .handled

        default:
            return .ignored
        }
    }

    // MARK: - 辅助方法

    enum CursorDirection {
        case up, down, left, right
    }

    private func moveCursor(direction: CursorDirection) {
        let pane = appState.currentPane
        let fileCount = pane.activeTab.files.count
        guard fileCount > 0 else { return }

        // 使用 Task 延迟执行，避免在视图更新期间修改状态
        Task { @MainActor in
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
                case .left, .right:
                    // List 模式不处理左右导航
                    return
                }
            }

            pane.activeTab.cursorFileId = pane.activeTab.files[currentIndex].id
        }
    }

    private func moveVisualCursor(direction: CursorDirection) {
        let pane = appState.currentPane
        let fileCount = pane.activeTab.files.count
        guard fileCount > 0 else { return }

        Task { @MainActor in
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

            pane.activeTab.cursorFileId = pane.activeTab.files[currentIndex].id
            pane.updateVisualSelection()
            pane.objectWillChange.send()
        }
    }

    private func enterDirectory() {
        let pane = appState.currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex] else {
            return
        }

        if file.type == .folder {
            pane.activeTab.currentPath = file.path
            pane.cursorIndex = 0
            pane.clearSelections()
            refreshCurrentPane()
        } else {
            FileSystemService.shared.openFile(file)
        }
    }

    private func leaveDirectory() {
        let pane = appState.currentPane
        let currentPath = pane.activeTab.currentPath
        let parent = FileSystemService.shared.parentDirectory(of: currentPath)

        // 检查是否已经在根目录
        if parent.path != currentPath.path {
            // 记住当前目录名，用于返回后定位
            let currentDirName = currentPath.lastPathComponent

            pane.activeTab.currentPath = parent
            pane.clearSelections()
            refreshCurrentPane()

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

    private func refreshCurrentPane() {
        let pane = appState.currentPane
        let files = FileSystemService.shared.loadDirectory(
            at: pane.activeTab.currentPath
        )
        pane.activeTab.files = files
        // 手动触发 UI 刷新
        pane.objectWillChange.send()
    }

    // MARK: - 书签操作

    /// 导航到书签位置
    private func navigateToBookmark(_ bookmark: BookmarkItem) {
        let pane = appState.currentPane

        if bookmark.type == .folder {
            // 如果是文件夹，导航到该目录
            pane.activeTab.currentPath = bookmark.path
            let files = FileSystemService.shared.loadDirectory(
                at: bookmark.path
            )
            pane.activeTab.files = files
            pane.cursorIndex = 0
            pane.objectWillChange.send()
            appState.showToast("Navigated to \(bookmark.name)")
        } else {
            // 如果是文件，导航到其父目录并选中该文件
            let parentPath = bookmark.path.deletingLastPathComponent()
            pane.activeTab.currentPath = parentPath
            let files = FileSystemService.shared.loadDirectory(at: parentPath)
            pane.activeTab.files = files

            // 查找并选中该文件
            if let index = files.firstIndex(where: { $0.path == bookmark.path })
            {
                pane.cursorIndex = index
            } else {
                pane.cursorIndex = 0
            }

            pane.objectWillChange.send()
            appState.showToast("Navigated to \(bookmark.name)")
        }
    }

    /// 添加当前选中项到书签
    private func addCurrentToBookmark() {
        let pane = appState.currentPane

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
            if addedCount > 0 {
                appState.showToast("\(addedCount) bookmark(s) added")
            } else {
                appState.showToast("Already bookmarked")
            }
        } else {
            // 否则添加当前光标所在的文件
            let files = pane.activeTab.files
            guard pane.cursorIndex < files.count else { return }

            let file = files[pane.cursorIndex]
            if bookmarkManager.contains(path: file.path) {
                appState.showToast("Already bookmarked")
            } else {
                bookmarkManager.addBookmark(for: file)
                appState.showToast("Bookmark added: \(file.name)")
            }
        }
    }

    private func pasteFiles() {
        guard !appState.clipboard.isEmpty else { return }

        do {
            let destination = appState.currentPane.activeTab.currentPath

            if appState.clipboardOperation == .copy {
                try FileSystemService.shared.copyFiles(
                    appState.clipboard,
                    to: destination
                )
                appState.showToast("\(appState.clipboard.count) file(s) copied")
            } else {
                try FileSystemService.shared.moveFiles(
                    appState.clipboard,
                    to: destination
                )
                appState.showToast("\(appState.clipboard.count) file(s) moved")
                appState.clipboard.removeAll()
            }

            refreshCurrentPane()
            // 如果是移动操作，还需要刷新另一个面板（源文件可能在那里）
            if appState.clipboardOperation == .cut {
                refreshOtherPane()
            }
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
        }
    }

    private func refreshOtherPane() {
        let otherPane =
            appState.activePane == .left
            ? appState.rightPane : appState.leftPane
        let files = FileSystemService.shared.loadDirectory(
            at: otherPane.activeTab.currentPath
        )
        otherPane.activeTab.files = files
        otherPane.objectWillChange.send()
    }

    private func selectDrive(_ drive: DriveInfo) {
        let pane = appState.currentPane
        pane.activeTab.drive = drive
        pane.activeTab.currentPath = drive.path
        pane.cursorIndex = 0
        pane.clearSelections()
        refreshCurrentPane()
        appState.exitMode()
        appState.showToast("Switched to \(drive.name)")
    }

    private func executeCommand() {
        let commandInput = appState.commandInput.trimmingCharacters(
            in: .whitespaces
        )
        guard !commandInput.isEmpty else {
            appState.exitMode()
            return
        }

        // 使用 CommandParser 解析命令
        let command = CommandParser.parse(commandInput)
        let currentPath = appState.currentPane.activeTab.currentPath

        switch command.type {
        case .mkdir:
            // mkdir <name> - 在当前目录创建文件夹
            let (_, folderName) = CommandParser.validateMkdir(command)
            do {
                let newDir = try FileSystemService.shared.createDirectory(
                    at: currentPath,
                    name: folderName
                )
                refreshCurrentPane()
                appState.showToast(
                    "Created directory: \(newDir.lastPathComponent)"
                )
            } catch {
                appState.showToast(
                    "Failed to create directory: \(error.localizedDescription)"
                )
            }

        case .touch:
            // touch <name> - 在当前目录创建文件
            let (_, fileName) = CommandParser.validateTouch(command)
            do {
                let newFile = try FileSystemService.shared.createFile(
                    at: currentPath,
                    name: fileName
                )
                refreshCurrentPane()
                appState.showToast("Created file: \(newFile.lastPathComponent)")
            } catch {
                appState.showToast(
                    "Failed to create file: \(error.localizedDescription)"
                )
            }

        case .move, .mv:
            // move <src> <dest> 或 move <dest> (使用选中文件作为源)
            executeMove(command: command, currentPath: currentPath)

        case .copy, .cp:
            // copy <src> <dest> 或 copy <dest> (使用选中文件作为源)
            executeCopy(command: command, currentPath: currentPath)

        case .delete, .rm:
            // delete [name] - 删除指定文件或当前选中文件
            executeDelete(command: command, currentPath: currentPath)

        case .cd:
            // cd <path> - 切换目录
            let result = CommandParser.validateCd(
                command,
                currentPath: currentPath
            )
            if result.valid, let targetPath = result.targetPath {
                appState.currentPane.activeTab.currentPath = targetPath
                refreshCurrentPane()
            } else if let error = result.error {
                appState.showToast(error)
            }

        case .open:
            // open - 打开当前选中的文件
            if let file = getCurrentFile() {
                NSWorkspace.shared.open(file.path)
            }

        case .term, .terminal:
            // term - 在当前目录打开终端
            FileSystemService.shared.openInTerminal(path: currentPath)

        case .q, .quit:
            NSApp.terminate(nil)

        case .unknown:
            appState.showToast("Unknown command: \(command.rawInput)")
        }

        appState.exitMode()
    }

    /// 获取当前光标所在的文件
    private func getCurrentFile() -> FileItem? {
        let pane = appState.currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex],
            !file.isParentDirectory
        else {
            return nil
        }
        return file
    }

    /// 执行移动命令
    private func executeMove(command: ParsedCommand, currentPath: URL) {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: currentPath
        )

        guard result.valid else {
            if let error = result.error {
                appState.showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // move <src> <dest>
            do {
                try FileManager.default.moveItem(at: srcPath, to: destPath)
                refreshCurrentPane()
                appState.showToast("Moved to: \(destPath.lastPathComponent)")
            } catch {
                appState.showToast("Move failed: \(error.localizedDescription)")
            }
        } else if let destPath = result.destination {
            // move <dest> - 移动当前选中文件
            let selectedFiles = getSelectedFiles()
            guard !selectedFiles.isEmpty else {
                appState.showToast("No file selected")
                return
            }

            do {
                try FileSystemService.shared.moveFiles(
                    selectedFiles,
                    to: destPath
                )
                refreshCurrentPane()
                appState.showToast("Moved \(selectedFiles.count) item(s)")
            } catch {
                appState.showToast("Move failed: \(error.localizedDescription)")
            }
        }
    }

    /// 执行复制命令
    private func executeCopy(command: ParsedCommand, currentPath: URL) {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: currentPath
        )

        guard result.valid else {
            if let error = result.error {
                appState.showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // copy <src> <dest>
            do {
                try FileManager.default.copyItem(at: srcPath, to: destPath)
                refreshCurrentPane()
                appState.showToast("Copied to: \(destPath.lastPathComponent)")
            } catch {
                appState.showToast("Copy failed: \(error.localizedDescription)")
            }
        } else if let destPath = result.destination {
            // copy <dest> - 复制当前选中文件
            let selectedFiles = getSelectedFiles()
            guard !selectedFiles.isEmpty else {
                appState.showToast("No file selected")
                return
            }

            do {
                try FileSystemService.shared.copyFiles(
                    selectedFiles,
                    to: destPath
                )
                refreshCurrentPane()
                appState.showToast("Copied \(selectedFiles.count) item(s)")
            } catch {
                appState.showToast("Copy failed: \(error.localizedDescription)")
            }
        }
    }

    /// 执行删除命令
    private func executeDelete(command: ParsedCommand, currentPath: URL) {
        let result = CommandParser.validateDelete(
            command,
            currentPath: currentPath
        )

        if let targetPath = result.targetPath {
            // delete <name> - 删除指定文件
            do {
                try FileManager.default.trashItem(
                    at: targetPath,
                    resultingItemURL: nil
                )
                refreshCurrentPane()
                appState.showToast("Deleted: \(targetPath.lastPathComponent)")
            } catch {
                appState.showToast(
                    "Delete failed: \(error.localizedDescription)"
                )
            }
        } else {
            // delete - 删除当前选中文件
            let selectedFiles = getSelectedFiles()
            guard !selectedFiles.isEmpty else {
                appState.showToast("No file selected")
                return
            }

            do {
                try FileSystemService.shared.trashFiles(selectedFiles)
                refreshCurrentPane()
                appState.showToast("Deleted \(selectedFiles.count) item(s)")
            } catch {
                appState.showToast(
                    "Delete failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private func applyFilter() {
        let pane = appState.currentPane
        let tab = pane.activeTab
        let filter = appState.filterInput

        // 首次过滤时保存原始文件列表
        if tab.unfilteredFiles.isEmpty && !tab.files.isEmpty {
            tab.unfilteredFiles = tab.files
        }

        if filter.isEmpty {
            // 过滤词为空时，恢复原始列表
            if !tab.unfilteredFiles.isEmpty {
                tab.files = tab.unfilteredFiles
            }
        } else {
            // 从原始列表过滤
            let sourceFiles =
                tab.unfilteredFiles.isEmpty ? tab.files : tab.unfilteredFiles

            if appState.filterUseRegex {
                // 正则表达式过滤
                do {
                    let regex = try NSRegularExpression(
                        pattern: filter,
                        options: [.caseInsensitive]
                    )
                    tab.files = sourceFiles.filter { file in
                        let range = NSRange(
                            file.name.startIndex...,
                            in: file.name
                        )
                        return regex.firstMatch(
                            in: file.name,
                            options: [],
                            range: range
                        ) != nil
                    }
                } catch {
                    // 正则表达式无效时，不过滤
                    tab.files = sourceFiles
                }
            } else {
                // 普通字符串匹配（大小写不敏感）
                let lowerFilter = filter.lowercased()
                tab.files = sourceFiles.filter {
                    $0.name.lowercased().contains(lowerFilter)
                }
            }
        }
        pane.cursorIndex = 0
    }

    // MARK: - 批量重命名

    /// 获取当前选中的文件列表
    private func getSelectedFiles() -> [FileItem] {
        let pane = appState.currentPane
        let selections = pane.selections

        if selections.isEmpty {
            // 如果没有选中，返回当前光标所在的文件
            if let file = pane.activeTab.files[safe: pane.cursorIndex],
                !file.isParentDirectory
            {
                return [file]
            }
            return []
        } else {
            // 返回选中的文件，排除父目录项
            return pane.activeTab.files.filter {
                selections.contains($0.id) && !$0.isParentDirectory
            }
        }
    }

    /// 执行批量重命名
    private func performBatchRename() {
        let selectedFiles = getSelectedFiles()
        guard !selectedFiles.isEmpty else {
            appState.showToast("No files selected for rename")
            return
        }

        let findText = appState.renameFindText
        let replaceText = appState.renameReplaceText
        let useRegex = appState.renameUseRegex

        guard !findText.isEmpty else {
            appState.showToast("Find text cannot be empty")
            return
        }

        var successCount = 0
        var errorMessages: [String] = []

        for (index, file) in selectedFiles.enumerated() {
            let newName = generateNewName(
                originalName: file.name,
                findText: findText,
                replaceText: replaceText,
                useRegex: useRegex,
                index: index
            )

            // 如果新名称与原名称相同，跳过
            if newName == file.name {
                continue
            }

            let newPath = file.path.deletingLastPathComponent()
                .appendingPathComponent(newName)

            do {
                try FileManager.default.moveItem(at: file.path, to: newPath)
                successCount += 1
            } catch {
                errorMessages.append(
                    "\(file.name): \(error.localizedDescription)"
                )
            }
        }

        // 清空重命名状态
        appState.renameFindText = ""
        appState.renameReplaceText = ""
        appState.renameUseRegex = false

        // 退出 Visual 模式并刷新
        appState.currentPane.clearSelections()
        appState.exitMode()
        refreshCurrentPane()

        // 显示结果
        if errorMessages.isEmpty {
            appState.showToast("\(successCount) file(s) renamed successfully")
        } else {
            appState.showToast(
                "\(successCount) renamed, \(errorMessages.count) failed"
            )
        }
    }

    /// 生成新文件名
    private func generateNewName(
        originalName: String,
        findText: String,
        replaceText: String,
        useRegex: Bool,
        index: Int
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())

        var processedReplace =
            replaceText
            .replacingOccurrences(
                of: "{n}",
                with: String(format: "%03d", index + 1)
            )
            .replacingOccurrences(of: "{date}", with: dateString)

        if useRegex {
            if let regex = try? NSRegularExpression(
                pattern: findText,
                options: []
            ) {
                let range = NSRange(
                    originalName.startIndex...,
                    in: originalName
                )
                return regex.stringByReplacingMatches(
                    in: originalName,
                    options: [],
                    range: range,
                    withTemplate: processedReplace
                )
            }
            return originalName
        } else {
            return originalName.replacingOccurrences(
                of: findText,
                with: processedReplace
            )
        }
    }

    // MARK: - 删除文件

    private func deleteSelectedFiles() {
        let pane = appState.currentPane
        let selections = pane.selections
        var filesToDelete: [FileItem]

        if selections.isEmpty {
            guard let file = pane.activeTab.files[safe: pane.cursorIndex] else {
                return
            }
            // 父目录项 (..) 不能被删除
            guard !file.isParentDirectory else {
                appState.showToast("Cannot delete parent directory item")
                return
            }
            filesToDelete = [file]
        } else {
            // 排除父目录项
            filesToDelete = pane.activeTab.files.filter {
                selections.contains($0.id) && !$0.isParentDirectory
            }
        }

        guard !filesToDelete.isEmpty else {
            appState.showToast("No files to delete")
            return
        }

        do {
            try FileSystemService.shared.trashFiles(filesToDelete)
            appState.showToast("\(filesToDelete.count) file(s) moved to Trash")
            pane.clearSelections()
            refreshCurrentPane()
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    MainView()
        .frame(width: 1200, height: 800)
        .environmentObject(AppState())
}
