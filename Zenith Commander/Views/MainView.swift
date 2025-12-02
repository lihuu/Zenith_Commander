//
//  MainView.swift
//  Zenith Commander
//
//  主视图 - 双面板布局
//

import Combine
import SwiftUI
import os.log

struct MainView: View {
    @StateObject private var appState = AppState()
    @StateObject private var bookmarkManager = BookmarkManager()
    @ObservedObject private var themeManager = ThemeManager.shared
    private var showSettings: Binding<Bool> {
        Binding<Bool>(
            get: { appState.mode == .settings },
            set: { newValue in }
        )
    }

    private var showHelp: Binding<Bool> {
        Binding<Bool>(
            get: { appState.mode == .help },
            set: { newValue in }
        )
    }  // 帮助视图显示状态

    @State private var showBookmarkBar = true  // 书签栏显示状态
    @State private var gitHistoryPanelHeight: CGFloat = 250  // Git 历史面板高度（本地状态，避免触发全局刷新）

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
                            height: $gitHistoryPanelHeight,
                            isVisible: $appState.showGitHistory,
                            minHeight: 100,
                            maxHeight: geometry.size.height * 0.6
                        ) {
                            GitHistoryPanelView(
                                fileName: appState.gitHistoryFile?.name
                                    ?? LocalizationManager.shared.localized(
                                        .gitRepoHistory
                                    ),
                                commits: appState.gitHistoryCommits,
                                isLoading: appState.gitHistoryLoading,
                                onClose: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.closeGitHistory()
                                    }
                                },
                                onCommitSelected: { commit in
                                    Logger.git.debug(
                                        "Commit selected: \(commit.shortHash, privacy: .public)"
                                    )
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
                        Task { await appState.selectDrive(drive) }
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
                        Task { await performBatchRename() }
                    },
                    onDismiss: {
                        appState.exitMode()  // 退出 RENAME 模式
                    }
                )
            }
        }
        .sheet(
            isPresented: showSettings,
            onDismiss: {
                // 关闭设置时退出 SETTINGS 模式
                appState.exitMode()
            }
        ) {
            SettingsView()
        }
        .sheet(
            isPresented: showHelp,
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
        }
    }


    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard let action = appState.mode.action(for: keyPress) else {
            return .ignored
        }

        Task{ @MainActor in
            await apply(action)
        }

        return .handled

    }

    @MainActor
    private func apply(_ action: AppAction) async{
        switch action {
        case .none:
            break
        case .enterMode(let mode):
            appState.enterMode(mode)
        case .exitMode:
            appState.exitMode()
        case .moveCursor(let direction):
            await appState.moveCursor(direction)
        case .moveVisualCursor(let direction):
            await appState.moveVisualCursor(direction)
        case .jumpToTop:
            appState.jumpToTop()
        case .jumpToBottom:
            appState.jumpToBottom()
        case .enterDirectory:
            await appState.enterDirectory()
        case .leaveDirectory:
            await appState.leaveDirectory()
        case .toggleActivePane:
            appState.toggleActivePane()
        case .newTab:
            await appState.newTab()
        case .closeTab:
            appState.closeTab()
            break
        case .previousTab:
            appState.currentPane.previousTab()
            await appState.refreshCurrentPane()
        case .nextTab:
            appState.currentPane.nextTab()
            await appState.refreshCurrentPane()
        case .toggleBookmarkBar:
            withAnimation(.easeInOut(duration: 0.2)) {
                showBookmarkBar.toggle()
            }
            appState.showToast(
                showBookmarkBar
                    ? "Bookmark bar shown" : "Bookmark bar hidden"
            )
        case .addBookmark:
            addCurrentToBookmark()

        case .openHelp:
            appState.enterMode(.help)
        case .openSettings:
            appState.enterMode(.settings)

        case .yank:
            appState.yankSelectedFiles()
        case .visualModeYank:
            let pane = appState.currentPane
            appState.yankSelectedFiles()
            appState.exitMode()
            pane.clearSelections()
        case .paste:
            await appState.pasteFiles()
        case .deleteSelectedFiles:
            let pane = appState.currentPane
            await deleteSelectedFiles()
            appState.exitMode()
            pane.clearSelections()

        case .batchRename:
            break

        case .refreshCurrentPane:
            await appState.refreshCurrentPane()

        case .enterDriveSelection:
            appState.enterMode(.driveSelect)
        case .moveDriveCursor(let direction):
            if direction == .up {
                if appState.driveSelectorCursor > 0 {
                    appState.driveSelectorCursor -= 1
                }
            }

            if direction == .down {
                if appState.driveSelectorCursor < appState.availableDrives.count
                    - 1
                {
                    appState.driveSelectorCursor += 1
                }
            }

        case .selectDrive:
            if let drive = appState.availableDrives[
                safe: appState.driveSelectorCursor
            ] {
                await appState.selectDrive(drive)
            }
        case .cycleTheme:
            themeManager.cycleTheme()
            appState.showToast(
                "Theme: \(themeManager.mode.displayName)"
            )
        case .deleteCommand:
            if !appState.commandInput.isEmpty {
                appState.commandInput.removeLast()
            }
        case .executeCommand:
            await executeCommand()
        case .insertCommand(let char):
            if char.isLetter || char.isNumber || char.isWhitespace
                || char.isPunctuation
            {
                appState.commandInput.append(char)
            }
        case .deleteFilterCharacter:
            if !appState.filterInput.isEmpty {
                appState.filterInput.removeLast()
                // 实时更新过滤
                applyFilter()
            }
        case .inputFilterCharacter(let char):
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
                appState.filterInput.append(char)
                // 实时过滤
                applyFilter()
            }

        case .doFilter:
            let pane = appState.currentPane
            pane.activeTab.unfilteredFiles = []
            appState.mode = .normal
            appState.filterInput = ""
            appState.filterUseRegex = false
        }

    }


    /// 导航到书签位置
    private func navigateToBookmark(_ bookmark: BookmarkItem) {
        Task {
            let pane = appState.currentPane

            if bookmark.type == .folder {
                // 如果是文件夹，导航到该目录
                pane.activeTab.currentPath = bookmark.path
                let files = await FileSystemService.shared.loadDirectory(
                    at: bookmark.path
                )

                await MainActor.run {
                    pane.activeTab.files = files
                    pane.cursorIndex = 0
                    pane.objectWillChange.send()
                    appState.showToast("Navigated to \(bookmark.name)")
                }
            } else {
                // 如果是文件，直接使用默认应用打开
                await MainActor.run {
                    NSWorkspace.shared.open(bookmark.path)
                    appState.showToast("Opening \(bookmark.name)...")
                }
            }
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

    private func executeCommand() async {
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
                await appState.refreshCurrentPane()
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
                await appState.refreshCurrentPane()
                appState.showToast("Created file: \(newFile.lastPathComponent)")
            } catch {
                appState.showToast(
                    "Failed to create file: \(error.localizedDescription)"
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
                appState.currentPane.activeTab.currentPath = targetPath
                await appState.refreshCurrentPane()
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
    private func executeMove(command: ParsedCommand, currentPath: URL) async {
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
                await appState.refreshCurrentPane()
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
                await appState.refreshCurrentPane()
                appState.showToast("Moved \(selectedFiles.count) item(s)")
            } catch {
                appState.showToast("Move failed: \(error.localizedDescription)")
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
                appState.showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // copy <src> <dest>
            do {
                try FileManager.default.copyItem(at: srcPath, to: destPath)
                await appState.refreshCurrentPane()
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
                await appState.refreshCurrentPane()
                appState.showToast("Copied \(selectedFiles.count) item(s)")
            } catch {
                appState.showToast("Copy failed: \(error.localizedDescription)")
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
                await appState.refreshCurrentPane()
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
                await appState.refreshCurrentPane()
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
    private func performBatchRename() async {
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
        await appState.refreshCurrentPane()

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

    // MARK: - 删除文件

    private func deleteSelectedFiles() async {
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
            await appState.refreshCurrentPane()
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
