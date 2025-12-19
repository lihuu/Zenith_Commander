//
//  AppState.swift
//  Zenith Commander
//
//  全局应用状态管理 (使用 ObservableObject + Combine)
//

import Combine
import Foundation
import os.log
import SwiftUI

/// 全局应用状态
@MainActor
class AppState: ObservableObject {
    // MARK: - 面板状态

    @Published var leftPane: PaneState
    @Published var rightPane: PaneState
    @Published var activePane: PaneSide = .left

    // MARK: - 订阅管理

    private var paneCancellables: Set<AnyCancellable> = []

    // MARK: - 模态状态

    @Published var mode: AppMode = .normal
    var previousMode: AppMode = .normal

    // MARK: - 输入状态

    @Published var commandInput = ""
    @Published var filterInput = ""
    @Published var filterUseRegex = false
    @Published var inputBuffer = ""

    // MARK: - 剪贴板

    @Published var clipboard: [FileItem] = []
    @Published var clipboardOperation: ClipboardOperation = .copy

    // MARK: - UI 状态

    @Published var toastMessage: String?
    @Published var showBookmarkBar = true
    @Published var showDriveSelector = false
    @Published var availableDrives: [DriveInfo] = []

    // MARK: - AI 状态

    @Published var aiResult = ""
    @Published var isAiLoading = false

    // MARK: - 批量重命名状态

    @Published var showRenameModal = false
    @Published var renameFindText = ""
    @Published var renameReplaceText = ""
    @Published var renameUseRegex = false

    // MARK: - 单个文件内联编辑状态

    @Published var editingFileId: String? = nil // 当前正在编辑的文件ID
    @Published var editingFileName = "" // 编辑中的文件名

    @Published var activeSheet: UIRequest?

    var driveSelectorCursor: Int {
        get {
            let index = availableDrives.firstIndex(where: {
                $0.id == self.currentPane.activeTab.drive.id
            }) ?? 0

            Logger.app.debug("Current selected Index: \(index)")

            return index
        }
        set {
            if newValue >= 0, newValue < availableDrives.count {
                Logger.app.debug("Current Selected newValue: \(newValue)")
                let selectedDrive = availableDrives[newValue]
                currentPane.activeTab.drive = selectedDrive
            }
        }
    }

    // MARK: - Connection Manager 状态

    @Published var showConnectionManager = false

    // MARK: - Git History 状态

    @Published var showGitHistory = false
    @Published var gitHistoryFile: FileItem?
    @Published var gitHistoryCommits: [GitCommit] = []
    @Published var gitHistoryLoading = false

    // MARK: - 右键菜单状态

    @Published var contextMenuPosition: CGPoint?
    @Published var contextMenuFile: FileItem?

    // MARK: - Rsync 状态

    @Published var rsyncUIState = RsyncUIState()

    init(testDirectory: URL? = nil) {
        // 获取默认驱动器
        let defaultDrive = DriveInfo(
            id: "macintosh-hd",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 0,
            availableCapacity: 0
        )

        // 如果提供了测试目录，使用测试目录；否则使用用户主目录
        if let testDir = testDirectory {
            leftPane = PaneState(
                side: .left,
                initialPath: testDir,
                drive: defaultDrive
            )
            rightPane = PaneState(
                side: .right,
                initialPath: testDir,
                drive: defaultDrive
            )
        } else {
            // 尝试恢复上次的路径
            let (leftPath, rightPath) = Self.restoreLastPaths()

            leftPane = PaneState(
                side: .left,
                initialPath: leftPath,
                drive: defaultDrive
            )
            rightPane = PaneState(
                side: .right,
                initialPath: rightPath,
                drive: defaultDrive
            )
        }

        // 订阅两个面板的变化，转发到 AppState
        subscribeToPaneChanges()
    }

    // MARK: - Undo Support

    var undoManager: UndoManager? {
        // Access the undoManager from the key window, which is typically the main window.
        // This is a common pattern in AppKit apps for undo/redo functionality.
        NSApp.keyWindow?.undoManager
    }

    /// 订阅面板状态变化
    private func subscribeToPaneChanges() {
        leftPane.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &paneCancellables)

        rightPane.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &paneCancellables)
    }

    // MARK: - 路径持久化

    /// 保存当前路径到 UserDefaults
    func saveCurrentPaths() {
        let leftPath = leftPane.activeTab.currentPath.path
        let rightPath = rightPane.activeTab.currentPath.path

        UserDefaults.standard.set(leftPath, forKey: "lastLeftPanePath")
        UserDefaults.standard.set(rightPath, forKey: "lastRightPanePath")

        Logger.app.debug("Saved paths - Left: \(leftPath, privacy: .public), Right: \(rightPath, privacy: .public)")
    }

    /// 从 UserDefaults 恢复上次的路径
    /// - Returns: (左面板路径, 右面板路径)
    private static func restoreLastPaths() -> (URL, URL) {
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let defaultLeftPath = homePath
        let defaultRightPath = homePath.appendingPathComponent("Downloads")

        // 读取保存的路径
        guard let leftPathString = UserDefaults.standard.string(forKey: "lastLeftPanePath"),
              let rightPathString = UserDefaults.standard.string(forKey: "lastRightPanePath")
        else {
            Logger.app.debug("No saved paths found, using defaults")
            return (defaultLeftPath, defaultRightPath)
        }

        let leftURL = URL(fileURLWithPath: leftPathString)
        let rightURL = URL(fileURLWithPath: rightPathString)

        // 验证路径是否仍然存在
        let fileManager = FileManager.default
        let leftPathExists = fileManager.fileExists(atPath: leftPathString)
        let rightPathExists = fileManager.fileExists(atPath: rightPathString)

        let finalLeftPath = leftPathExists ? leftURL : defaultLeftPath
        let finalRightPath = rightPathExists ? rightURL : defaultRightPath

        Logger.app.debug("Restored paths - Left: \(finalLeftPath.path, privacy: .public) (exists: \(leftPathExists)), Right: \(finalRightPath.path, privacy: .public) (exists: \(rightPathExists))")

        return (finalLeftPath, finalRightPath)
    }

    // MARK: - 计算属性

    /// 当前活动面板
    var currentPane: PaneState {
        activePane == .left ? leftPane : rightPane
    }

    /// 非活动面板
    var inactivePane: PaneState {
        activePane == .left ? rightPane : leftPane
    }

    /// 状态栏显示文本
    var statusText: String {
        switch mode {
        case .command:
            return ":\(commandInput)"
        case .filter:
            let prefix = filterUseRegex ? "/regex: " : "/"
            return "\(prefix)\(filterInput)"
        default:
            let pane = currentPane
            let tab = pane.activeTab
            let currentFile =
                tab.files.isEmpty
                    ? "" : tab.files[safe: pane.cursorIndex]?.name ?? ""
            return "\(tab.drive.name) | \(currentFile)"
        }
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
        await currentPane.refreshActiveTab()
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

    // MARK: - Action Dispatch

    func dispatch(_ action: AppAction) async {
        switch action {
        case .none:
            break
        case .enterMode(let mode):
            enterMode(mode)
        case .exitMode:
            exitMode()
        case .moveCursor(let direction):
            await moveCursor(direction)
        case .moveVisualCursor(let direction):
            await moveVisualCursor(direction)
        case .jumpToTop:
            jumpToTop()
        case .jumpToBottom:
            jumpToBottom()

        // MARK: - 鼠标操作
        case .mouseClick(let index, let paneSide):
            handleMouseClick(at: index, paneSide: paneSide)
        case .mouseCommandClick(let index, let paneSide):
            handleMouseCommandClick(at: index, paneSide: paneSide)
        case .mouseShiftClick(let index, let paneSide):
            handleMouseShiftClick(at: index, paneSide: paneSide)
        case .mouseDoubleClick(let fileId, let paneSide):
            await handleMouseDoubleClick(
                fileId: fileId,
                paneSide: paneSide
            )
        case .enterDirectory:
            await enterDirectory()
        case .leaveDirectory:
            await leaveDirectory()
        case .toggleActivePane:
            toggleActivePane()
        case .newTab:
            await newTab()
        case .closeTab:
            closeTab()
        case .previousTab:
            currentPane.previousTab()
            await refreshCurrentPane()
        case .nextTab:
            currentPane.nextTab()
            await refreshCurrentPane()
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
        case .addBookmark:
            addCurrentToBookmark()
        case .openHelp:
            enterMode(.help)
        case .closeHelp:
            exitMode()
        case .openSettings:
            enterMode(.settings)
        case .yank:
            yankSelectedFiles()
        case .cut:
            cutSelectedFiles()
        case .visualModeYank:
            let pane = currentPane
            yankSelectedFiles()
            exitMode()
            pane.clearSelections()
        case .paste:
            await pasteFiles()
        case .deleteSelectedFiles:
            await deleteSelectedFiles()
            exitMode()
        case .batchRename:
            enterMode(.batchRename)
        case .startRenamingFile(let fileName, let filePath):
            // 创建临时 FileItem 用于启动编辑
            let fileItem = FileItem(
                id: UUID().uuidString,
                name: fileName,
                path: URL(fileURLWithPath: filePath),
                type: .file,
                size: 0,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: fileName.hasPrefix("."),
                permissions: "",
                fileExtension: (fileName as NSString).pathExtension
            )
            startEditingFile(fileItem)
        case .refreshCurrentPane:
            await refreshCurrentPane()
        case .enterDriveSelection:
            enterMode(.driveSelect)
        case .moveDriveCursor(let direction):
            if direction == .up {
                if driveSelectorCursor > 0 {
                    driveSelectorCursor -= 1
                    objectWillChange.send()
                }
            }

            if direction == .down {
                if driveSelectorCursor < availableDrives.count
                    - 1
                {
                    driveSelectorCursor += 1
                    objectWillChange.send()
                }
            }
        case .selectDrive:
            if let drive = availableDrives[
                safe: driveSelectorCursor
            ] {
                await selectDrive(drive)
            }
        case .cycleTheme:
            let themeManager = ThemeManager.shared
            themeManager.cycleTheme()
            showToast(
                LocalizationManager.shared.localized(
                    .toastTheme,
                    themeManager.mode.displayName
                )
            )
        case .deleteCommand:
            if !commandInput.isEmpty {
                commandInput.removeLast()
            }
        case .executeCommand:
            await executeCommand()
        case .insertCommand(let char):
            if char.isLetter || char.isNumber || char.isWhitespace
                || char.isPunctuation
            {
                commandInput.append(char)
            }
        case .deleteFilterCharacter:
            if !filterInput.isEmpty {
                filterInput.removeLast()
                // 实时更新过滤
                applyFilter()
            }
        case .inputFilterCharacter(let char):
            // 普通过滤支持常用字符，正则表达式支持更多特殊字符
            let isValidChar: Bool =
                if filterUseRegex {
                    // 正则表达式模式：支持更多字符
                    char.isLetter || char.isNumber || char.isWhitespace
                        || "._-*+?^$[](){}|\\".contains(char)
                } else {
                    // 普通模式：支持基本字符
                    char.isLetter || char.isNumber || "._- ".contains(char)
                }

            if isValidChar {
                filterInput.append(char)
                // 实时过滤
                applyFilter()
            }
        case .doFilter:
            doFilter()
        case .openRsync:
            // Open rsync sync sheet with left pane as source
            presentRsyncSheet(sourceIsLeft: true)
        case .showSheet:
            break
        case .dismissSheet:
            break
        case .toast:
            break
        }
    }

    // MARK: - Toast 通知

    /// 显示 Toast 消息
    func showToast(_ message: String) {
        // 使用异步更新避免在视图更新期间修改 @Published 属性
        DispatchQueue.main.async { [weak self] in
            self?.toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
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
            pane.visualAnchor = nil // 清除锚点，因为 Command+Click 是独立选择
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
            let files = await FileSystemService.shared.loadDirectory(
                at: newPath
            )

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
            FileSystemService.shared.openFile(file)
        }
    }

    // MARK: - 剪贴板操作

    /// 复制选中的文件
    func yankSelectedFiles() {
        let selections = currentPane.selections
        if selections.isEmpty {
            // 如果没有选择，复制当前光标文件
            if let file = currentPane.currentFiles[
                safe: currentPane.cursorIndex
            ] {
                // 父目录项 (..) 不能被复制
                guard !file.isParentDirectory else {
                    showToast("Cannot copy parent directory item")
                    return
                }
                clipboard = [file]
            }
        } else {
            // 排除父目录项
            clipboard = currentPane.currentFiles.filter {
                selections.contains($0.id) && !$0.isParentDirectory
            }
        }
        if clipboard.isEmpty {
            showToast("No files to yank")
            return
        }
        clipboardOperation = .copy
        showToast("\(clipboard.count) file(s) yanked")
    }

    /// 剪切选中的文件
    func cutSelectedFiles() {
        yankSelectedFiles()
        clipboardOperation = .cut
        showToast("\(clipboard.count) file(s) cut")
    }

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
                return // leaveDirectory 已经处理了光标，直接返回
            case .right:
                await enterDirectory()
                return // enterDirectory 已经处理了光标，直接返回
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

    func newTab() async {
        let pane = currentPane
        pane.addTab()
        await refreshCurrentPane()
        showToast("New tab created")
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

    func enterDirectory() async {
        let pane = currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex] else {
            return
        }

        guard file.isFolder else {
            FileSystemService.shared.openFile(file)
            return
        }

        let newPath = file.path
        let files = await FileSystemService.shared.loadDirectory(at: newPath)

        pane.activeTab.currentPath = newPath
        pane.activeTab.files = files
        pane.cursorIndex = 0
        pane.clearSelections()
    }

    func leaveDirectory() async {
        let pane = currentPane
        let currentPath = pane.activeTab.currentPath
        let parent = FileSystemService.shared.parentDirectory(of: currentPath)

        // 检查是否已经在根目录
        if currentPath.path != "/" {
            // 记住当前目录名，用于返回后定位
            let currentDirName = currentPath.lastPathComponent

            let files = await FileSystemService.shared.loadDirectory(
                at: parent
            )
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

    func pasteFiles() async {
        guard !clipboard.isEmpty else { return }

        do {
            let destination = currentPane.activeTab.currentPath

            if clipboardOperation == .copy {
                try await FileSystemService.shared.copyFiles(
                    clipboard,
                    to: destination
                )
                showToast("\(clipboard.count) file(s) copied")
            } else {
                try await FileSystemService.shared.moveFiles(
                    clipboard,
                    to: destination
                )
                showToast("\(clipboard.count) file(s) moved")
                clipboard.removeAll()
            }

            await refreshCurrentPane()
            // 如果是移动操作，还需要刷新另一个面板（源文件可能在那里）
            if clipboardOperation == .cut {
                await refreshOtherPane()
            }
        } catch {
            showToast("Error: \(error.localizedDescription)")
        }
    }

    private func refreshOtherPane() async {
        let otherPane =
            activePane == .left
                ? rightPane : leftPane
        let files = await FileSystemService.shared.loadDirectory(
            at: otherPane.activeTab.currentPath
        )
        otherPane.activeTab.files = files
    }

    func selectDrive(_ drive: DriveInfo) async {
        driveSelectorCursor = availableDrives.firstIndex(of: drive) ?? 0
        Logger.app.debug("Selected drive: \(drive.name, privacy: .public)")
        Logger.app.debug("Delected drive index: \(self.driveSelectorCursor)")
        let pane = currentPane
        pane.activeTab.drive = drive
        pane.activeTab.currentPath = drive.path
        pane.cursorIndex = 0
        pane.clearSelections()
        await refreshCurrentPane()
        exitMode()
    }

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

    func closeTab() {
        let pane = currentPane
        if pane.tabs.count > 1 {
            pane.closeTab(at: pane.activeTabIndex)
        }
    }

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

    // MARK: - 批量重命名

    /// 执行批量重命名
    func performBatchRename() async {
        let selectedFiles = selectedFiles()
        guard !selectedFiles.isEmpty else {
            showToast(
                LocalizationManager.shared.localized(.toastNoFilesForRename)
            )
            return
        }

        let findText = renameFindText
        let replaceText = renameReplaceText
        let useRegex = renameUseRegex

        guard !findText.isEmpty else {
            showToast(
                LocalizationManager.shared.localized(.toastFindTextEmpty)
            )
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
        renameFindText = ""
        renameReplaceText = ""
        renameUseRegex = false

        // 退出 Visual 模式并刷新
        currentPane.clearSelections()
        exitMode()
        await refreshCurrentPane()

        // 显示结果
        if errorMessages.isEmpty {
            showToast(
                LocalizationManager.shared.localized(
                    .toastFilesRenamed,
                    successCount
                )
            )
        } else {
            showToast(
                LocalizationManager.shared.localized(
                    .toastRenamedWithErrors,
                    successCount,
                    errorMessages.count
                )
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

        let processedReplace =
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
}

/// 剪贴板操作类型
enum ClipboardOperation {
    case copy
    case cut
}

// MARK: - 安全数组访问扩展

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
