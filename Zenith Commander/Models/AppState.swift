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

    @Published var editingFileId: String? = nil  // 当前正在编辑的文件ID
    @Published var editingFileName = ""  // 编辑中的文件名

    @Published var activeSheet: UIRequest?

    var driveSelectorCursor: Int {
        get {
            let index =
                availableDrives.firstIndex(where: {
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

    // MARK: - 依赖注入

    let env: AppEnvironment
    private var runtimeStarted = false

    init(environment: AppEnvironment, initialDirectory: URL? = nil) {
        self.env = environment
        // 获取默认驱动器
        let defaultDrive = DriveInfo(
            id: "macintosh-hd",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 0,
            availableCapacity: 0
        )

        leftPane = PaneState(
            side: .left,
            initialPath: env.initParam.leftInitPath,
            drive: defaultDrive
        )
        rightPane = PaneState(
            side: .right,
            initialPath: env.initParam.rightInitPath,
            drive: defaultDrive
        )

        // 订阅两个面板的变化，转发到 AppState
        subscribeToPaneChanges()
    }

    convenience init(initialDirectory: URL? = nil) {
        self.init(environment: .live(), initialDirectory: initialDirectory)
    }

    func startRuntime() {
        guard env.runtime.startSideEffects else { return }
        guard !runtimeStarted else { return }
        runtimeStarted = true
        Task {
            let drives = await env.fileSystem.mountedVolumes()
            availableDrives = drives
        }
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

        env.userDefaults.set(leftPath, forKey: "lastLeftPanePath")
        env.userDefaults.set(rightPath, forKey: "lastRightPanePath")

        // 保存安全书签以持久化访问权限
        saveSecurityBookmark(for: leftPane.activeTab.currentPath, key: "leftPaneBookmark")
        saveSecurityBookmark(for: rightPane.activeTab.currentPath, key: "rightPaneBookmark")

        Logger.app.debug(
            "Saved paths - Left: \(leftPath, privacy: .public), Right: \(rightPath, privacy: .public)"
        )
    }

    /// 保存安全书签
    private func saveSecurityBookmark(for url: URL, key: String) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            env.userDefaults.set(bookmarkData, forKey: key)
            Logger.app.debug("Saved security bookmark for: \(url.path, privacy: .public)")
        } catch {
            Logger.app.error(
                "Failed to save security bookmark: \(error.localizedDescription, privacy: .public)")
        }
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

    // MARK: - Action Dispatch

    func dispatch(_ action: AppAction) async {
        switch action {
        case .none:
            break
        case .mode(let modeAction):
            handleAction(modeAction)
        case .pane(let paneAction):
            handleAction(paneAction)
        case .paneAsync(let paneAsyncAction):
            await handleAction(paneAsyncAction)
        case .file(let fileAction):
            await handleAction(fileAction)
        case .ui(let uiAction):
            handleAction(uiAction)
        case .command(let commandAction):
            handleAction(commandAction)
        case .commandAsync(let commandAsyncAction):
            await handleAction(commandAsyncAction)
        case .filter(let filterAction):
            handleAction(filterAction)
        case .drive(let driveAction):
            await handleAction(driveAction)
        case .moveCursor(let direction):
            await moveCursor(direction)
        case .moveVisualCursor(let direction):
            await moveVisualCursor(direction)
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
        }
    }

    func deleteCommand() {
        if !commandInput.isEmpty {
            commandInput.removeLast()
        }
    }

    func insertCommand(_ char: Character) {
        if char.isLetter || char.isNumber || char.isWhitespace
            || char.isPunctuation
        {
            commandInput.append(char)
        }
    }

    func handleAction(_ action: CommandAction) {
        switch action {
        case .deleteCommand:
            deleteCommand()
        case .insertCommand(let char):
            insertCommand(char)
        }
    }

    func handleAction(_ action: CommandAsyncAction) async {
        switch action {
        case .executeCommand:
            await executeCommand()
        }
    }

    func handleAction(_ action: ModeAction) {
        switch action {
        case .enterMode(let mode):
            enterMode(mode)
        case .exitMode:
            exitMode()
        }
    }

    func handleAction(_ action: UIAction) {
        switch action {
        case .toast(let message):
            showToast(message)
        case .cycleTheme:
            let themeManager = ThemeManager.shared
            themeManager.cycleTheme()
            showToast(
                LocalizationManager.shared.localized(
                    .toastTheme,
                    themeManager.mode.displayName
                )
            )
        case .openRsync:
            presentRsyncSheet(sourceIsLeft: true)
        case .showSheet(let req):
            activeSheet = req
        case .dismissSheet:
            activeSheet = nil
        }
    }

    func handleAction(_ action: FilterAction) {
        switch action {
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
        }
    }

    func handleAction(_ action: DriveAction) async {
        switch action {
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
        }
    }

    func handleAction(_ action: FileAction) async {
        switch action {
        case .yank:
            yankSelectedFiles()
        case .cut:
            cutSelectedFiles()
        case .visualModeYank:
            let pane = currentPane
            yankSelectedFiles()
            exitMode()
            pane.clearSelections()
        case .deleteSelectedFiles:
            await deleteSelectedFiles()
            exitMode()
        case .paste:
            await pasteFiles()
        case .batchRename:
            enterMode(.batchRename)
        case .startRenamingFile(let fileName, let filePath):
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
        }
    }

    /// 显示 Toast 消息
    // MARK: - Toast 通知

    func showToast(_ message: String) {
        // 使用异步更新避免在视图更新期间修改 @Published 属性
        env.main.async { [weak self] in
            self?.toastMessage = message
        }
        env.main.asyncAfter(seconds: 2) { [weak self] in
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

    func pasteFiles() async {
        guard !clipboard.isEmpty else { return }

        do {
            let destination = currentPane.activeTab.currentPath

            if clipboardOperation == .copy {
                try await env.fileSystem.copyFiles(
                    clipboard,
                    to: destination,
                    undoManager: undoManager
                )
                showToast("\(clipboard.count) file(s) copied")
            } else {
                try await env.fileSystem.moveFiles(
                    clipboard,
                    to: destination,
                    undoManager: undoManager
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
        let files = await env.fileSystem.loadDirectory(
            at: otherPane.activeTab.currentPath
        )
        otherPane.activeTab.files = files
    }

    func selectDrive(_ drive: DriveInfo) async {
        driveSelectorCursor = availableDrives.firstIndex(of: drive) ?? 0
        Logger.app.debug("Selected drive: \(drive.name, privacy: .public)")
        let pane = currentPane
        pane.activeTab.drive = drive
        pane.activeTab.currentPath = drive.path
        pane.cursorIndex = 0
        pane.clearSelections()
        await refreshCurrentPane()
        exitMode()
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
                try await env.fileSystem.moveItem(at: file.path, to: newPath)
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

    func makePaneSnapshot() -> PanesSnapshot {
        return PanesSnapshot(
            leftPath: leftPane.activeTab.currentPath.path,
            rightPath: rightPane.activeTab.currentPath.path,
            active: activePane == .left ? .left : .right
        )
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
