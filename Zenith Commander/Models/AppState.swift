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
    @Published var driveSelectorCursor: Int = 0
    @Published var availableDrives: [DriveInfo] = []

    // MARK: - AI 状态
    @Published var aiResult: String = ""
    @Published var isAiLoading: Bool = false

    // MARK: - 批量重命名状态
    @Published var showRenameModal: Bool = false
    @Published var renameFindText: String = ""
    @Published var renameReplaceText: String = ""
    @Published var renameUseRegex: Bool = false

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
        let pane = currentPane
        let files = await FileSystemService.shared.loadDirectory(
            at: pane.activeTab.currentPath
        )
        pane.activeTab.files = files
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
        Logger.git.info(
            "showGitHistoryForFile called for: \(file.name, privacy: .public)"
        )
        Logger.git.debug("File path: \(file.path.path, privacy: .public)")
        Logger.git.debug(
            "File type: \(String(describing: file.type), privacy: .public)"
        )

        // 先在主线程复制需要的值，避免在后台线程访问可能触发 UI 更新的属性
        let filePath = file.path
        let fileName = file.name

        gitHistoryFile = file
        gitHistoryLoading = true
        showGitHistory = true

        Logger.git.debug(
            "State updated: showGitHistory=true, gitHistoryLoading=true"
        )

        // 异步加载历史
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Logger.git.debug(
                "Background thread started for getFileHistory - file: \(fileName, privacy: .public)"
            )

            let commits = GitService.shared.getFileHistory(for: filePath)

            Logger.git.info(
                "getFileHistory returned \(commits.count) commits for \(fileName, privacy: .public)"
            )

            DispatchQueue.main.async {
                guard let self = self else {
                    Logger.git.warning("Self was deallocated before UI update")
                    return
                }
                Logger.git.debug(
                    "Main thread: updating UI with \(commits.count) commits"
                )
                self.gitHistoryCommits = commits
                self.gitHistoryLoading = false
                Logger.git.debug("State updated: gitHistoryLoading=false")
            }
        }
    }

    func moveCursor(_ direction: CursorDirection) {
        let pane = currentPane
        let fileCount = pane.activeTab.files.count
        guard fileCount > 0 else { return }

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
                case .left:
                    await leaveDirectory()
                    return  // leaveDirectory 已经处理了光标，直接返回
                case .right:
                    await enterDirectory()
                    return  // enterDirectory 已经处理了光标，直接返回
                }
            }
            
            // 重新获取当前文件数量，防止在 Task 执行期间文件列表发生变化
            let currentFiles = pane.activeTab.files
            let actualFileCount = currentFiles.count
            
            guard actualFileCount > 0 else { return }
            
            // 确保索引在有效范围内
            let safeIndex = min(max(0, currentIndex), actualFileCount - 1)
            
            Logger.app.info("Cursor moved to index: \(safeIndex)")
            Logger.app.info("File count in current tab: \(actualFileCount)")

            pane.activeTab.cursorFileId = currentFiles[safeIndex].id
        }
    }

    func newTab() async {
        let pane = currentPane
        pane.addTab()
        await refreshCurrentPane()
        showToast("New tab created")
    }

    func moveVisualCursor(_ direction: CursorDirection) {
        let pane = currentPane
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

            // 重新获取当前文件数量，防止在 Task 执行期间文件列表发生变化
            let currentFiles = pane.activeTab.files
            let actualFileCount = currentFiles.count
            
            guard actualFileCount > 0 else { return }
            
            // 确保索引在有效范围内
            let safeIndex = min(max(0, currentIndex), actualFileCount - 1)
            
            pane.activeTab.cursorFileId = currentFiles[safeIndex].id
            pane.updateVisualSelection()
            pane.objectWillChange.send()
        }
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Logger.git.debug(
                "Background thread started for getRepositoryHistory - path: \(path.path, privacy: .public)"
            )

            let commits = GitService.shared.getRepositoryHistory(at: path)

            Logger.git.info(
                "getRepositoryHistory returned \(commits.count) commits"
            )

            DispatchQueue.main.async {
                guard let self = self else {
                    Logger.git.warning("Self was deallocated before UI update")
                    return
                }
                Logger.git.debug(
                    "Main thread: updating UI with \(commits.count) commits"
                )
                self.gitHistoryCommits = commits
                self.gitHistoryLoading = false
                Logger.git.debug("State updated: gitHistoryLoading=false")
            }
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

        if file.type == .folder {
            pane.activeTab.currentPath = file.path
            pane.cursorIndex = 0
            pane.clearSelections()
            await refreshCurrentPane()
        } else {
            FileSystemService.shared.openFile(file)
        }
    }

    func leaveDirectory() async {
        let pane = currentPane
        let currentPath = pane.activeTab.currentPath
        let parent = FileSystemService.shared.parentDirectory(of: currentPath)

        // 检查是否已经在根目录
        if parent.path != currentPath.path {
            // 记住当前目录名，用于返回后定位
            let currentDirName = currentPath.lastPathComponent

            pane.activeTab.currentPath = parent
            pane.clearSelections()
            await refreshCurrentPane()

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
                try FileSystemService.shared.copyFiles(
                    clipboard,
                    to: destination
                )
                showToast("\(clipboard.count) file(s) copied")
            } else {
                try FileSystemService.shared.moveFiles(
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
        let pane = currentPane
        pane.activeTab.drive = drive
        pane.activeTab.currentPath = drive.path
        pane.cursorIndex = 0
        pane.clearSelections()
        await refreshCurrentPane()
        exitMode()
        showToast("Switched to \(drive.name)")
    }

    func jumpToTop() {
        let pane = currentPane
        pane.cursorIndex = 0
        
        if mode == .visual{
            pane.updateVisualSelection()
        }
    }

    func jumpToBottom() {
        let pane = currentPane
        pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
        if mode == .visual{
            pane.updateVisualSelection()
        }
    }

    func closeTab() {
        let pane = currentPane
        if pane.tabs.count > 1 {
            pane.closeTab(at: pane.activeTabIndex)
        }
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
            driveSelectorCursor = 0
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
