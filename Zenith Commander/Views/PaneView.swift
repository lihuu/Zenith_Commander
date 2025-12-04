//
//  PaneView.swift
//  Zenith Commander
//
//  单个面板视图
//

import AppKit
import Combine
import SwiftUI
import os.log

struct PaneView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var pane: PaneState
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject var bookmarkManager: BookmarkManager
    let side: PaneSide

    @State private var permissionDeniedPath: URL? = nil
    @State private var showPermissionError: Bool = false
    @State private var directoryMonitor: DispatchSourceDirectoryMonitor? = nil

    var isActivePane: Bool {
        appState.activePane == side
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            TabBarView(
                pane: pane,
                isActivePane: isActivePane,
                onTabSwitch: { index in
                    pane.switchTab(to: index)
                    loadCurrentDirectoryWithPermissionCheck()
                },
                onTabClose: { index in
                    pane.closeTab(at: index)
                },
                onTabAdd: {
                    pane.addTab()
                    loadCurrentDirectoryWithPermissionCheck()
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(
                side == .left ? "left_pane_header" : "right_pane_header"
            )
            .accessibilityLabel(isActivePane ? "active" : "inactive")

            // 权限错误横幅
            if showPermissionError, let deniedPath = permissionDeniedPath {
                PermissionErrorBanner(
                    message: "Cannot access: \(deniedPath.lastPathComponent)",
                    onDismiss: {
                        showPermissionError = false
                    },
                    onRequestAccess: {
                        requestFolderAccess()
                    }
                )
            }

            // 面包屑导航区域
            VStack(spacing: 4) {
                BreadcrumbView(
                    tab: pane.activeTab,
                    isActivePane: isActivePane,
                    onNavigate: { path in
                        navigateTo(path)
                    },
                    onDriveClick: {
                        appState.enterMode(.driveSelect)
                    }
                )

                // 文件数量和视图切换
                HStack {
                    Text("\(pane.activeTab.files.count) items")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)

                    Spacer()

                    // 视图模式切换
                    ViewModeToggle(viewMode: $pane.viewMode)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .background(Theme.background)

            Divider()
                .background(Theme.borderLight)

            // 主内容区域
            if let deniedPath = permissionDeniedPath,
                pane.activeTab.files.isEmpty
            {
                // 显示权限请求视图
                PermissionRequestView(
                    path: deniedPath,
                    onRequestAccess: {
                        requestFolderAccess()
                    },
                    onOpenSettings: {
                        FileSystemService.shared.openSystemPreferencesPrivacy()
                    },
                    onGoBack: {
                        leaveDirectory()
                    }
                )
            } else {
                // 文件列表
                fileListView
            }
        }
        .background(Theme.background)
        .opacity(isActivePane ? 1.0 : 0.85)
        .onTapGesture {
            appState.setActivePane(side)
        }
        .onAppear {
            // 使用异步加载避免在视图更新期间修改 @Published 属性
            DispatchQueue.main.async {
                loadCurrentDirectoryWithPermissionCheck()
                startDirectoryMonitoring()
            }
        }
        .onDisappear {
            stopDirectoryMonitoring()
        }
        .onChange(of: pane.activeTab.currentPath) { oldPath, newPath in
            // 当目录变化时，重新启动监控
            startDirectoryMonitoring()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(side == .left ? "left_pane" : "right_pane")
        .accessibilityLabel(side == .left ? "Left Pane" : "Right Pane")
    }

    // MARK: - 文件列表视图

    @ViewBuilder
    private var fileListView: some View {
        if pane.viewMode == .list {
            listView
        } else {
            gridView
        }
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(
                        Array(pane.activeTab.files.enumerated()),
                        id: \.element.id
                    ) { index, file in
                        FileRowView(
                            file: file,
                            isActive: index == pane.cursorIndex,
                            isSelected: pane.selections.contains(file.id),
                            isPaneActive: isActivePane,
                            rowIndex: index
                        )
                        .equatable()  // 使用 Equatable 优化重绘
                        .id(file.id)
                        .contentShape(Rectangle())
                        .dropDestination(for: URL.self) { urls, _ in
                            // 只有文件夹才接受拖放
                            guard file.type == .folder else { return false }
                            return handleDroppedURLs(urls, to: file.path)
                        } isTargeted: { isTargeted in
                            // 可以在这里添加拖放目标高亮效果
                        }
                        .simultaneousGesture(
                            TapGesture(count: 2)
                                .onEnded { handleFileDoubleClick(file: file) }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 1)
                                .onEnded {
                                    // 获取当前修饰键状态
                                    let modifiers = currentModifiers()
                                    handleFileClick(
                                        index: index,
                                        modifiers: modifiers
                                    )
                                }
                        )
                        .contextMenu {
                            fileContextMenu(file: file)
                        }
                    }

                    if pane.activeTab.files.isEmpty {
                        emptyDirectoryView
                    }

                    // 空白区域用于右键菜单
                    Spacer()
                        .frame(minHeight: 100)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .contextMenu {
                            directoryContextMenu
                        }
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                // 拖放到当前目录
                return handleDroppedURLs(urls, to: pane.activeTab.currentPath)
            }
            .onChange(of: pane.activeTab.cursorFileId) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    // 使用 nil anchor 让 SwiftUI 自动选择最小滚动量
                    // 只在目标项即将超出可视区域时才滚动
                    proxy.scrollTo(newValue, anchor: nil)
                }
            }
            .id(pane.activeTab.currentPath)
        }
    }

    /// Grid View 每个项目的宽度（包含间距）
    private let gridItemMinWidth: CGFloat = 90
    private let gridItemMaxWidth: CGFloat = 100
    private let gridSpacing: CGFloat = 8
    private let gridPadding: CGFloat = 8

    private var gridView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(
                                    minimum: gridItemMinWidth,
                                    maximum: gridItemMaxWidth
                                ),
                                spacing: gridSpacing
                            )
                        ],
                        spacing: gridSpacing
                    ) {
                        ForEach(
                            Array(pane.activeTab.files.enumerated()),
                            id: \.element.id
                        ) { index, file in
                            FileGridItemView(
                                file: file,
                                isActive: index == pane.cursorIndex,
                                isSelected: pane.selections.contains(file.id),
                                isPaneActive: isActivePane
                            )
                            .id(file.id)
                            .contentShape(Rectangle())
                            .dropDestination(for: URL.self) { urls, _ in
                                // 只有文件夹才接受拖放
                                guard file.type == .folder else { return false }
                                return handleDroppedURLs(urls, to: file.path)
                            } isTargeted: { isTargeted in
                                // 可以在这里添加拖放目标高亮效果
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        handleFileDoubleClick(file: file)
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture(count: 1)
                                    .onEnded {
                                        let modifiers = currentModifiers()
                                        handleFileClick(
                                            index: index,
                                            modifiers: modifiers
                                        )
                                    }
                            )
                            .contextMenu {
                                fileContextMenu(file: file)
                            }
                        }
                    }
                    .padding(gridPadding)

                    if pane.activeTab.files.isEmpty {
                        emptyDirectoryView
                    }

                    // 空白区域用于右键菜单
                    Spacer()
                        .frame(minHeight: 100)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .contextMenu {
                            directoryContextMenu
                        }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    // 拖放到当前目录
                    return handleDroppedURLs(
                        urls,
                        to: pane.activeTab.currentPath
                    )
                }
                .onChange(
                    of: pane.activeTab.cursorFileId
                ) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        // 使用 nil anchor 让 SwiftUI 自动选择最小滚动量
                        // 只在目标项即将超出可视区域时才滚动
                        proxy.scrollTo(newValue, anchor: nil)
                    }
                }
                .id(pane.activeTab.currentPath)
            }
            .onAppear {
                updateGridColumnCount(width: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                updateGridColumnCount(width: newWidth)
            }
        }
    }

    /// 根据视图宽度计算 Grid 的列数
    private func updateGridColumnCount(width: CGFloat) {
        let availableWidth = width - gridPadding * 2
        let itemWidth = gridItemMinWidth + gridSpacing
        let columnCount = max(1, Int(floor(availableWidth / itemWidth)))
        pane.gridColumnCount = columnCount
    }

    private var emptyDirectoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Theme.textMuted)
            Text("Empty Directory")
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 右键菜单

    @ViewBuilder
    private func fileContextMenu(file: FileItem) -> some View {
        Button(LocalizationManager.shared.localized(.contextOpen)) {
            handleFileDoubleClick(file: file)
        }

        Button(LocalizationManager.shared.localized(.contextOpenInTerminal)) {
            let path =
                file.type == .folder ? file.path : pane.activeTab.currentPath
            FileSystemService.shared.openInTerminal(path: path)
        }

        Divider()

        // 书签操作
        if bookmarkManager.contains(path: file.path) {
            Button(
                LocalizationManager.shared.localized(
                    .contextRemoveFromBookmarks
                )
            ) {
                if let bookmark = bookmarkManager.bookmarks.first(where: {
                    $0.path == file.path
                }) {
                    bookmarkManager.remove(bookmark)
                }
            }
        } else {
            Button(LocalizationManager.shared.localized(.contextAddToBookmarks))
            {
                bookmarkManager.addBookmark(for: file)
            }
        }

        Divider()

        Button(LocalizationManager.shared.localized(.contextCopyYank)) {
            appState.yankSelectedFiles()
        }

        Button(LocalizationManager.shared.localized(.contextPaste)) {
            pasteFiles()
        }
        .disabled(appState.clipboard.isEmpty)

        Divider()

        Button(LocalizationManager.shared.localized(.contextShowInFinder)) {
            FileSystemService.shared.revealInFinder(file)
        }

        Button(LocalizationManager.shared.localized(.contextCopyFullPath)) {
            copyFullPath(file: file)
        }

        // Git History 选项 - 仅在 Git 仓库中且非文件夹时显示
        if settingsManager.settings.git.enabled
            && pane.gitInfo?.isGitRepository == true && file.type != .folder
        {
            Divider()

            Button(LocalizationManager.shared.localized(.gitShowHistory)) {
                Logger.git.info(
                    "Show Git History menu item clicked for file: \(file.name, privacy: .public)"
                )
                Logger.git.debug(
                    "File path: \(file.path.path, privacy: .public)"
                )
                appState.showGitHistoryForFile(file)
            }
        }

        Divider()

        Button(LocalizationManager.shared.localized(.contextMoveToTrash)) {
            deleteSelectedFiles()
        }
        .keyboardShortcut(.delete, modifiers: .command)

        Divider()

        Button(LocalizationManager.shared.localized(.contextRefresh)) {
            refreshDirectory()
        }
    }

    /// 目录级右键菜单（空白处右键）
    @ViewBuilder
    private var directoryContextMenu: some View {
        Button(LocalizationManager.shared.localized(.contextNewFile)) {
            createNewFile()
        }

        Button(LocalizationManager.shared.localized(.contextNewFolder)) {
            createNewFolder()
        }

        Divider()

        Button(LocalizationManager.shared.localized(.contextPaste)) {
            pasteFiles()
        }
        .disabled(appState.clipboard.isEmpty)

        Divider()

        Button(LocalizationManager.shared.localized(.contextOpenInTerminal)) {
            FileSystemService.shared.openInTerminal(
                path: pane.activeTab.currentPath
            )
        }

        Divider()

        Button(LocalizationManager.shared.localized(.contextRefresh)) {
            refreshDirectory()
        }

        // Git History 选项 - 仅在 Git 仓库中显示
        if settingsManager.settings.git.enabled
            && pane.gitInfo?.isGitRepository == true
        {
            Divider()

            Button(LocalizationManager.shared.localized(.gitRepoHistory)) {
                appState.showGitHistoryForRepo(at: pane.activeTab.currentPath)
            }
        }
    }

    // MARK: - 事件处理（统一通过模式系统）

    /// 处理拖放的 URL - 移动文件到目标目录
    /// - Parameters:
    ///   - urls: 被拖放的文件 URL 列表
    ///   - destination: 目标目录 URL
    /// - Returns: 是否成功处理拖放
    private func handleDroppedURLs(_ urls: [URL], to destination: URL) -> Bool {
        guard !urls.isEmpty else { return false }

        // 检查目标是否为目录
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(
                atPath: destination.path,
                isDirectory: &isDirectory
            ),
            isDirectory.boolValue
        else {
            appState.showToast(LocalizationManager.shared.localized(.toastTargetNotFolder))
            return false
        }

        // 过滤掉目标目录本身和其父目录（避免移动到自身）
        let validURLs = urls.filter { url in
            // 不能移动到自己
            guard url != destination else { return false }
            // 不能移动父目录到子目录
            guard !destination.path.hasPrefix(url.path + "/") else {
                return false
            }
            return true
        }

        guard !validURLs.isEmpty else {
            appState.showToast(LocalizationManager.shared.localized(.toastCannotMoveToSame))
            return false
        }

        // 检查是否按住 Option 键来复制而不是移动
        let optionPressed = NSEvent.modifierFlags.contains(.option)

        do {
            for url in validURLs {
                let destURL = destination.appendingPathComponent(
                    url.lastPathComponent
                )

                // 生成唯一文件名（如果目标已存在）
                let uniqueDestURL = generateUniqueURL(for: destURL)
                
                // 如果源和目标在同一个目录，强制复制（因为移动没有意义）
                let isSameDirectory = url.deletingLastPathComponent() == destination
                let shouldCopy = optionPressed || isSameDirectory

                if shouldCopy {
                    try FileManager.default.copyItem(at: url, to: uniqueDestURL)
                } else {
                    try FileManager.default.moveItem(at: url, to: uniqueDestURL)
                }
            }


            // 刷新目录
            loadCurrentDirectoryWithPermissionCheck()

            return true
        } catch {
            appState.showToast(LocalizationManager.shared.localized(.error) + ": \(error.localizedDescription)")
            return false
        }
    }

    /// 生成唯一的目标 URL（如果已存在同名文件）
    private func generateUniqueURL(for url: URL) -> URL {
        var resultURL = url
        var counter = 1

        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parentDir = url.deletingLastPathComponent()

        while FileManager.default.fileExists(atPath: resultURL.path) {
            let newName =
                ext.isEmpty
                ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            resultURL = parentDir.appendingPathComponent(newName)
            counter += 1
        }

        return resultURL
    }

    /// 处理文件单击 - 检测修饰键并分发到对应的 Action
    private func handleFileClick(index: Int, modifiers: EventModifiers = []) {
        if modifiers.contains(.command) {
            // Command+Click: 切换选择（自动进入 Visual 模式）
            appState.handleMouseCommandClick(at: index, paneSide: side)
        } else if modifiers.contains(.shift) {
            // Shift+Click: 范围选择（自动进入 Visual 模式）
            appState.handleMouseShiftClick(at: index, paneSide: side)
        } else {
            // 普通单击: 移动光标
            appState.handleMouseClick(at: index, paneSide: side)
        }
    }

    /// 处理文件双击
    private func handleFileDoubleClick(file: FileItem) {
        Task {
            await appState.handleMouseDoubleClick(
                fileId: file.id,
                paneSide: side
            )
            // 双击后需要重新加载目录（处理权限检查等）
            if file.isFolder {
                loadCurrentDirectoryWithPermissionCheck()
            }
        }
    }

    /// 复制文件完整路径到剪贴板
    private func copyFullPath(file: FileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(file.path.path, forType: .string)

        // 显示成功提示
        appState.showToast(LocalizationManager.shared.localized(.toastPathCopied, file.name))
    }

    /// 刷新当前目录
    func refreshDirectory() {
        loadCurrentDirectoryWithPermissionCheck()
        appState.showToast(LocalizationManager.shared.localized(.toastRefreshed))
    }

    // MARK: - 目录监控

    /// 开始监控当前目录
    private func startDirectoryMonitoring() {
        // 停止之前的监控
        stopDirectoryMonitoring()

        let currentPath = pane.activeTab.currentPath
        let paneRef = pane
        let settingsRef = settingsManager

        // 使用 DispatchSource 监控器（轻量级方案）
        let monitor = DispatchSourceDirectoryMonitor(url: currentPath)
        monitor.start(
            onChange: {
                // 目录变化时自动刷新
                Task {
                    let result = await FileSystemService.shared
                        .loadDirectoryWithPermissionCheck(
                            at: paneRef.activeTab.currentPath
                        )

                    await MainActor.run {
                        if case .success(var files) = result {
                            // 获取 Git 状态（如果启用）
                            if settingsRef.settings.git.enabled {
                                let gitSettings = settingsRef.settings.git
                                let gitService = GitService.shared

                                // 获取仓库信息
                                let repoInfo = gitService.getRepositoryInfo(
                                    at: currentPath
                                )

                                if repoInfo.isGitRepository {
                                    // 获取文件状态
                                    let statusDict = gitService.getFileStatuses(
                                        in: currentPath,
                                        includeUntracked: gitSettings
                                            .showUntrackedFiles,
                                        includeIgnored: gitSettings
                                            .showIgnoredFiles
                                    )

                                    // 应用状态到文件（使用标准化路径比较）
                                    for index in files.indices {
                                        let standardizedPath = files[index].path
                                            .standardizedFileURL
                                        if let status = statusDict[
                                            standardizedPath
                                        ] {
                                            files[index] = files[index]
                                                .withGitStatus(status)
                                        } else if files[index].type == .folder {
                                            let folderPath =
                                                standardizedPath.path + "/"
                                            let hasModifiedChildren = statusDict
                                                .keys.contains { key in
                                                    key.path.hasPrefix(
                                                        folderPath
                                                    )
                                                }
                                            if hasModifiedChildren {
                                                files[index] = files[index]
                                                    .withGitStatus(.modified)
                                            }
                                        }
                                    }

                                    paneRef.gitInfo = repoInfo
                                }
                            }

                            paneRef.activeTab.files = files
                        }
                    }
                }
            },
            onDirectoryInvalidated: {
                // 目录被删除/移动/重命名时，导航到父目录
                Logger.monitor.warning(
                    "Directory invalidated, navigating to parent: \(currentPath.path, privacy: .public)"
                )

                let parentPath = currentPath.deletingLastPathComponent()

                // 检查父目录是否存在，如果不存在则导航到用户主目录
                var isDir: ObjCBool = false
                let parentExists = FileManager.default.fileExists(
                    atPath: parentPath.path,
                    isDirectory: &isDir
                )

                if parentExists && isDir.boolValue {
                    paneRef.activeTab.currentPath = parentPath
                    paneRef.cursorIndex = 0
                    paneRef.clearSelections()
                    // 重新加载目录
                    Task {
                        let result = await FileSystemService.shared
                            .loadDirectoryWithPermissionCheck(at: parentPath)
                        await MainActor.run {
                            if case .success(let files) = result {
                                paneRef.activeTab.files = files
                            }
                        }
                    }
                } else {
                    // 父目录也不存在，导航到用户主目录
                    let homeDir = FileManager.default
                        .homeDirectoryForCurrentUser
                    paneRef.activeTab.currentPath = homeDir
                    paneRef.cursorIndex = 0
                    paneRef.clearSelections()
                    Task {
                        let result = await FileSystemService.shared
                            .loadDirectoryWithPermissionCheck(at: homeDir)
                        await MainActor.run {
                            if case .success(let files) = result {
                                paneRef.activeTab.files = files
                            }
                        }
                    }
                }
            }
        )

        directoryMonitor = monitor
    }

    /// 停止监控当前目录
    private func stopDirectoryMonitoring() {
        directoryMonitor?.stop()
        directoryMonitor = nil
    }

    // MARK: - 导航

    func navigateTo(_ path: URL) {
        pane.activeTab.currentPath = path
        loadCurrentDirectoryWithPermissionCheck {
            pane.cursorIndex = 0
            pane.clearSelections()
        }
    }

    func loadCurrentDirectoryWithPermissionCheck(
        restoreSelection: String? = nil,
        successCallBack: @escaping () -> Void = {}
    ) {
        Task {
            let result = await FileSystemService.shared
                .loadDirectoryWithPermissionCheck(
                    at: pane.activeTab.currentPath
                )

            // Update UI on MainActor
            await MainActor.run {
                switch result {
                case .success(var files):
                    // 获取 Git 状态（如果启用）
                    successCallBack()
                    if settingsManager.settings.git.enabled {
                        let gitSettings = settingsManager.settings.git
                        applyGitStatus(to: &files, settings: gitSettings)
                    } else {
                        pane.gitInfo = nil
                    }

                    pane.activeTab.files = files
                    permissionDeniedPath = nil
                    showPermissionError = false

                    // Restore selection if requested
                    if let restoreName = restoreSelection {
                        if let index = files.firstIndex(where: {
                            $0.name == restoreName
                        }) {
                            pane.activeTab.cursorFileId = files[index].id
                        } else {
                            pane.cursorIndex = 0
                        }
                    }

                case .permissionDenied(let path):
                    pane.activeTab.files = []
                    permissionDeniedPath = path
                    showPermissionError = true
                    pane.gitInfo = nil

                case .notFound(let path):
                    pane.activeTab.files = []
                    appState.showToast(
                        LocalizationManager.shared.localized(.toastDirectoryNotFound, path.lastPathComponent)
                    )
                    permissionDeniedPath = nil
                    showPermissionError = false
                    pane.gitInfo = nil
                    // 尝试返回上级目录
                    leaveDirectory()

                case .error(let message):
                    pane.activeTab.files = []
                    appState.showToast(LocalizationManager.shared.localized(.error) + ": \(message)")
                    permissionDeniedPath = nil
                    showPermissionError = false
                    pane.gitInfo = nil
                }
            }
        }
    }

    /// 应用 Git 状态到文件列表
    private func applyGitStatus(
        to files: inout [FileItem],
        settings: GitSettings
    ) {
        let currentPath = pane.activeTab.currentPath
        let gitService = GitService.shared

        // 获取仓库信息
        pane.gitInfo = gitService.getRepositoryInfo(at: currentPath)

        // 如果不是 Git 仓库，清除状态
        guard pane.gitInfo?.isGitRepository == true else {
            pane.gitInfo = nil
            return
        }

        // 获取文件状态
        let statusDict = gitService.getFileStatuses(
            in: currentPath,
            includeUntracked: settings.showUntrackedFiles,
            includeIgnored: settings.showIgnoredFiles
        )

        // 应用状态到文件
        for index in files.indices {
            // 使用标准化路径进行比较
            let standardizedPath = files[index].path.standardizedFileURL
            if let status = statusDict[standardizedPath] {
                files[index] = files[index].withGitStatus(status)
            } else {
                // 文件可能在子目录中有修改（对于目录项）
                if files[index].type == .folder {
                    let folderPath = standardizedPath.path + "/"
                    let hasModifiedChildren = statusDict.keys.contains { key in
                        key.path.hasPrefix(folderPath)
                    }
                    if hasModifiedChildren {
                        files[index] = files[index].withGitStatus(.modified)
                    }
                }
            }
        }
    }

    func requestFolderAccess() {
        if let deniedPath = permissionDeniedPath {
            // 使用 NSOpenPanel 请求用户授权
            FileSystemService.shared.requestFolderAccess(for: deniedPath) {
                grantedURL in
                if grantedURL != nil {
                    // 用户授权成功，重新加载目录
                    DispatchQueue.main.async {
                        self.loadCurrentDirectoryWithPermissionCheck()
                    }
                }
            }
        }
    }

    func leaveDirectory() {
        let currentPath = pane.activeTab.currentPath
        let parent = FileSystemService.shared.parentDirectory(of: currentPath)

        // 检查是否已经在根目录
        if parent.path != currentPath.path {
            // 记住当前目录名，用于返回后定位
            let currentDirName = currentPath.lastPathComponent

            pane.activeTab.currentPath = parent
            pane.clearSelections()
            loadCurrentDirectoryWithPermissionCheck(
                restoreSelection: currentDirName
            )
        }
    }

    // MARK: - 文件操作

    func pasteFiles() {
        guard !appState.clipboard.isEmpty else { return }

        do {
            let destination = pane.activeTab.currentPath

            if appState.clipboardOperation == .copy {
                try FileSystemService.shared.copyFiles(
                    appState.clipboard,
                    to: destination
                )
                appState.showToast(LocalizationManager.shared.localized(.toastItemsCopied, appState.clipboard.count))
            } else {
                try FileSystemService.shared.moveFiles(
                    appState.clipboard,
                    to: destination
                )
                appState.showToast(LocalizationManager.shared.localized(.toastItemsMoved, appState.clipboard.count))
                appState.clipboard.removeAll()
            }

            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast(LocalizationManager.shared.localized(.error) + ": \(error.localizedDescription)")
        }
    }

    func deleteSelectedFiles() {
        let selections = pane.selections
        var filesToDelete: [FileItem]

        if selections.isEmpty {
            guard let file = pane.activeTab.files[safe: pane.cursorIndex] else {
                return
            }
            // 父目录项 (..) 不能被删除
            guard !file.isParentDirectory else {
                appState.showToast(LocalizationManager.shared.localized(.toastCannotDeleteParent))
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
            appState.showToast(LocalizationManager.shared.localized(.toastNoFilesToDelete))
            return
        }

        do {
            try FileSystemService.shared.trashFiles(filesToDelete)
            appState.showToast(LocalizationManager.shared.localized(.toastFilesMovedToTrash, filesToDelete.count))
            pane.clearSelections()
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast(LocalizationManager.shared.localized(.error) + ": \(error.localizedDescription)")
        }
    }

    // MARK: - 创建文件/文件夹

    private func createNewFile() {
        let baseName = "Untitled"
        let uniqueName = FileSystemService.shared.generateUniqueFileName(
            for: baseName,
            in: pane.activeTab.currentPath
        )

        do {
            _ = try FileSystemService.shared.createFile(
                at: pane.activeTab.currentPath,
                name: uniqueName
            )
            appState.showToast(LocalizationManager.shared.localized(.toastCreatedFile, uniqueName))
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast(
                LocalizationManager.shared.localized(.toastErrorCreatingFile, error.localizedDescription)
            )
        }
    }

    private func createNewFolder() {
        let baseName = "New Folder"
        let uniqueName = FileSystemService.shared.generateUniqueFileName(
            for: baseName,
            in: pane.activeTab.currentPath
        )

        do {
            _ = try FileSystemService.shared.createDirectory(
                at: pane.activeTab.currentPath,
                name: uniqueName
            )
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast(
                LocalizationManager.shared.localized(.toastErrorCreatingFolder, error.localizedDescription)
            )
        }
    }

    // MARK: - 辅助函数

    /// 获取当前按下的修饰键
    /// 通过 NSEvent 获取当前的修饰键状态，用于鼠标点击时判断 Command/Shift 等修饰键
    private func currentModifiers() -> EventModifiers {
        let flags = NSEvent.modifierFlags
        var modifiers: EventModifiers = []

        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }

        return modifiers
    }
}

// MARK: - 视图模式切换按钮
struct ViewModeToggle: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var viewMode: ViewMode

    var body: some View {
        HStack(spacing: 2) {
            viewModeButton(mode: .list, icon: "list.bullet")
            viewModeButton(mode: .grid, icon: "square.grid.2x2")
        }
        .padding(2)
        .background(Theme.backgroundTertiary)
        .cornerRadius(4)
    }

    private func viewModeButton(mode: ViewMode, icon: String) -> some View {
        Button(action: { viewMode = mode }) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(
                    viewMode == mode ? Theme.textPrimary : Theme.textTertiary
                )
                .frame(width: 20, height: 18)
                .background(
                    viewMode == mode ? Theme.backgroundElevated : .clear
                )
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let appState = AppState()
    let bookmarkManager = BookmarkManager()
    PaneView(
        pane: appState.leftPane,
        bookmarkManager: bookmarkManager,
        side: .left
    )
    .environmentObject(appState)
    .frame(width: 400, height: 600)
}
