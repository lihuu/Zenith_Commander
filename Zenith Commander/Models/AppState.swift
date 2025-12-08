//
//  AppState.swift
//  Zenith Commander
//
//  全局应用状态管理 (使用 ObservableObject + Combine)
//

import Combine
import Foundation
import SwiftUI
import os.log

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
    @Published var commandInput: String = ""
    @Published var filterInput: String = ""
    @Published var filterUseRegex: Bool = false
    @Published var inputBuffer: String = ""

    // MARK: - 剪贴板
    @Published var clipboard: [FileItem] = []
    @Published var clipboardOperation: ClipboardOperation = .copy

    // MARK: - UI 状态
    @Published var toastMessage: String?
    @Published var showDriveSelector: Bool = false
    @Published var availableDrives: [DriveInfo] = []

    // MARK: - AI 状态
    @Published var aiResult: String = ""
    @Published var isAiLoading: Bool = false

    // MARK: - 批量重命名状态
    @Published var showRenameModal: Bool = false
    @Published var renameFindText: String = ""
    @Published var renameReplaceText: String = ""
    @Published var renameUseRegex: Bool = false

    var driveSelectorCursor: Int {
        get {
            let index =  availableDrives.firstIndex(where: {
                $0.id == currentPane.activeTab.drive.id
            }) ?? 0
            
            Logger.app.debug("Current selected Index: \(index)")
            
            return index
        }
        set {
            if newValue >= 0 && newValue < availableDrives.count {
                Logger.app.debug("Current Selected newValue: \(newValue)")
                let selectedDrive = availableDrives[newValue]
                currentPane.activeTab.drive = selectedDrive
            }
        }
    }

    // MARK: - Connection Manager 状态
    @Published var showConnectionManager: Bool = false

    // MARK: - Git History 状态
    @Published var showGitHistory: Bool = false
    @Published var gitHistoryFile: FileItem?
    @Published var gitHistoryCommits: [GitCommit] = []
    @Published var gitHistoryLoading: Bool = false

    // MARK: - 右键菜单状态
    @Published var contextMenuPosition: CGPoint?
    @Published var contextMenuFile: FileItem?

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
            // 初始化面板，默认路径为用户主目录
            // TODO 这里可以从配置文件中读取，如果没有配置则使用默认路径，两边默认都应该使用home目录
            /// 应该记录上次使用的路径吧，其他的软件都是这样做的
            ///
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            leftPane = PaneState(
                side: .left,
                initialPath: homePath,
                drive: defaultDrive
            )
            rightPane = PaneState(
                side: .right,
                initialPath: homePath.appendingPathComponent("Downloads"),
                drive: defaultDrive
            )
        }

        // 订阅两个面板的变化，转发到 AppState
        subscribeToPaneChanges()
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

    // MARK: - Git History 方法

    /// 显示文件的 Git 历史
    func showGitHistoryForFile(_ file: FileItem) {

        // 先在主线程复制需要的值，避免在后台线程访问可能触发 UI 更新的属性
        let filePath = file.path

        gitHistoryFile = file
        gitHistoryLoading = true
        showGitHistory = true

        // 异步加载历史
        Task {
            let commits = await GitService.shared.getFileHistory(for: filePath)

            self.gitHistoryCommits = commits
            self.gitHistoryLoading = false
        }
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

    /// 显示当前选中文件的 Git 历史
    func showGitHistoryForCurrentFile() {
        Logger.git.debug("showGitHistoryForCurrentFile called")

        let files = currentPane.currentFiles
        let cursorIndex = currentPane.cursorIndex

        Logger.git.debug(
            "cursorIndex: \(cursorIndex), files.count: \(files.count)"
        )

        guard cursorIndex >= 0 && cursorIndex < files.count else {
            Logger.git.warning(
                "Invalid cursor index: \(cursorIndex) for files count: \(files.count)"
            )
            return
        }

        let file = files[cursorIndex]
        Logger.git.debug(
            "Selected file: \(file.name, privacy: .public), type: \(String(describing: file.type), privacy: .public)"
        )

        // 不显示文件夹和父目录的历史
        if file.type == .folder || file.isParentDirectory {
            Logger.git.info(
                "Cannot show history for folder or parent directory"
            )
            showToast("Select a file to view Git history")
            return
        }

        showGitHistoryForFile(file)
    }

    /// 显示仓库的 Git 历史
    func showGitHistoryForRepo(at path: URL) {
        Logger.git.info(
            "showGitHistoryForRepo called for: \(path.path, privacy: .public)"
        )

        // 清除文件引用，表示是仓库级别的历史
        gitHistoryFile = nil
        gitHistoryLoading = true
        showGitHistory = true

        Logger.git.debug(
            "State updated: showGitHistory=true, gitHistoryLoading=true"
        )

        // 异步加载历史
        Task {
            let commits = await GitService.shared.getRepositoryHistory(at: path)

            self.gitHistoryCommits = commits
            self.gitHistoryLoading = false
            Logger.git.debug(
                "State updated: gitHistoryLoading=false, commits: \(commits.count)"
            )
        }
    }

    /// 关闭 Git 历史面板
    func closeGitHistory() {
        Logger.git.debug("closeGitHistory called")
        showGitHistory = false
        gitHistoryFile = nil
        gitHistoryCommits = []
        Logger.git.debug("Git history panel closed and state cleared")
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
        self.driveSelectorCursor = availableDrives.firstIndex(of: drive) ?? 0
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

    func doFilter() {
        let pane = currentPane
        pane.activeTab.unfilteredFiles = []
        mode = .normal
        filterInput = ""
        filterUseRegex = false
    }

}

extension AppState {
    // MARK: - 模式操作

    /// 进入模式
    func enterMode(_ newMode: AppMode) {
        previousMode = mode
        mode = newMode

        switch newMode {
        case .command:
            commandInput = ""
        case .rename:
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

        if mode == .rename {
            // 关闭重命名模态窗口
            showRenameModal = false
        }

        if mode == .modal {
            showConnectionManager = false
        }

        if mode == .rename {
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

// MARK: - 过滤功能扩展

extension AppState {
    func applyFilter() {
        let pane = currentPane
        let tab = pane.activeTab
        let filter = filterInput

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

            if filterUseRegex {
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
}

/// 剪贴板操作类型
enum ClipboardOperation {
    case copy
    case cut
}

// MARK: - 安全数组访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// For command mode process
extension AppState {
    func executeCommand() async {
        let commandInput = commandInput.trimmingCharacters(
            in: .whitespaces
        )
        guard !commandInput.isEmpty else {
            exitMode()
            return
        }

        // 使用 CommandParser 解析命令
        let command = CommandParser.parse(commandInput)
        let currentPath = currentPane.activeTab.currentPath

        switch command.type {
        case .mkdir:
            // mkdir <name> - 在当前目录创建文件夹
            let (_, folderName) = CommandParser.validateMkdir(command)
            do {
                let _ = try await FileSystemService.shared.createDirectory(
                    at: currentPath,
                    name: folderName
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastFailedToCreateDirectory,
                        error.localizedDescription
                    )
                )
            }

        case .touch:
            // touch <name> - 在当前目录创建文件
            let (_, fileName) = CommandParser.validateTouch(command)
            do {
                let _ = try await FileSystemService.shared.createFile(
                    at: currentPath,
                    name: fileName
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastFailedToCreateFile,
                        error.localizedDescription
                    )
                )
            }

        case .move, .mv:
            // move <src> <dest> 或 move <dest> (使用选中文件作为源)
            await executeMove(command: command, currentPath: currentPath)

        case .copy, .cp:
            // copy <src> <dest> 或 copy <dest> (使用选中文件作为源)
            await executeCopy(command: command, currentPath: currentPath)

        case .delete, .rm:
            // delete [name] - 删除指定文件或当前选中文件
            await executeDelete(command: command, currentPath: currentPath)

        case .cd:
            // cd <path> - 切换目录
            let result = CommandParser.validateCd(
                command,
                currentPath: currentPath
            )
            if result.valid, let targetPath = result.targetPath {
                currentPane.activeTab.currentPath = targetPath
                await refreshCurrentPane()
            } else if let error = result.error {
                showToast(error)
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
            showToast(
                LocalizationManager.shared.localized(
                    .toastUnknownCommand,
                    command.rawInput
                )
            )
        }

        exitMode()
    }

    private func executeMove(command: ParsedCommand, currentPath: URL) async {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: currentPath
        )

        guard result.valid else {
            if let error = result.error {
                showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // move <src> <dest>
            do {
                try FileManager.default.moveItem(at: srcPath, to: destPath)
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastMoveFailed,
                        error.localizedDescription
                    )
                )
            }
        } else if let destPath = result.destination {
            // move <dest> - 移动当前选中文件
            let selectedFiles = getSelectedFiles()
            guard !selectedFiles.isEmpty else {
                showToast(
                    LocalizationManager.shared.localized(.toastNoFileSelected)
                )
                return
            }

            do {
                try await FileSystemService.shared.moveFiles(
                    selectedFiles,
                    to: destPath
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastMoveFailed,
                        error.localizedDescription
                    )
                )
            }
        }
    }

    /// 执行复制命令
    private func executeCopy(command: ParsedCommand, currentPath: URL) async {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: currentPath
        )

        guard result.valid else {
            if let error = result.error {
                showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // copy <src> <dest>
            do {
                try FileManager.default.copyItem(at: srcPath, to: destPath)
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastCopyFailed,
                        error.localizedDescription
                    )
                )
            }
        } else if let destPath = result.destination {
            // copy <dest> - 复制当前选中文件
            let selectedFiles = getSelectedFiles()
            guard !selectedFiles.isEmpty else {
                showToast(
                    LocalizationManager.shared.localized(.toastNoFileSelected)
                )
                return
            }

            do {
                try await FileSystemService.shared.copyFiles(
                    selectedFiles,
                    to: destPath
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastCopyFailed,
                        error.localizedDescription
                    )
                )
            }
        }
    }

    /// 执行删除命令
    private func executeDelete(command: ParsedCommand, currentPath: URL) async {
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
                await refreshCurrentPane()
                showToast(
                    LocalizationManager.shared.localized(.toastDeleted)
                        + ": \(targetPath.lastPathComponent)"
                )
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastDeleteFailed,
                        error.localizedDescription
                    )
                )
            }
        } else {
            // delete - 删除当前选中文件
            let selectedFiles = getSelectedFiles()
            guard !selectedFiles.isEmpty else {
                showToast(
                    LocalizationManager.shared.localized(.toastNoFileSelected)
                )
                return
            }

            do {
                try await FileSystemService.shared.trashFiles(selectedFiles)
                await refreshCurrentPane()
                showToast(
                    LocalizationManager.shared.localized(
                        .toastFilesMovedToTrash,
                        selectedFiles.count
                    )
                )
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastDeleteFailed,
                        error.localizedDescription
                    )
                )
            }
        }
    }

    private func getSelectedFiles() -> [FileItem] {
        let pane = currentPane
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

    private func getCurrentFile() -> FileItem? {
        let pane = currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex],
            !file.isParentDirectory
        else {
            return nil
        }
        return file
    }

}
