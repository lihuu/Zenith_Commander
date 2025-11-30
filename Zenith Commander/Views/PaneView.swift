//
//  PaneView.swift
//  Zenith Commander
//
//  单个面板视图
//

import SwiftUI
import Combine
import AppKit

struct PaneView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var pane: PaneState
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject var bookmarkManager: BookmarkManager
    let side: PaneSide
    
    @State private var permissionDeniedPath: URL? = nil
    @State private var showPermissionError: Bool = false
    @State private var directoryMonitor: FSEventsDirectoryMonitor? = nil
    
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
            .accessibilityIdentifier(side == .left ? "left_pane_header" : "right_pane_header")
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
            if let deniedPath = permissionDeniedPath, pane.activeTab.files.isEmpty {
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
                    ForEach(Array(pane.activeTab.files.enumerated()), id: \.element.id) { index, file in
                        FileRowView(
                            file: file,
                            isActive: index == pane.cursorIndex,
                            isSelected: pane.selections.contains(file.id),
                            isPaneActive: isActivePane
                        )
                        .id(file.id)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture(count: 2)
                                .onEnded { handleFileDoubleClick(file: file) }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 1)
                                .onEnded { handleFileClick(index: index) }
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
                        columns: [GridItem(.adaptive(minimum: gridItemMinWidth, maximum: gridItemMaxWidth), spacing: gridSpacing)],
                        spacing: gridSpacing
                    ) {
                        ForEach(Array(pane.activeTab.files.enumerated()), id: \.element.id) { index, file in
                            FileGridItemView(
                                file: file,
                                isActive: index == pane.cursorIndex,
                                isSelected: pane.selections.contains(file.id),
                                isPaneActive: isActivePane
                            )
                            .id(file.id)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded { handleFileDoubleClick(file: file) }
                            )
                            .simultaneousGesture(
                                TapGesture(count: 1)
                                    .onEnded { handleFileClick(index: index) }
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
        Button("Open") {
            handleFileDoubleClick(file: file)
        }
        
        Button("Open in Terminal") {
            let path = file.type == .folder ? file.path : pane.activeTab.currentPath
            FileSystemService.shared.openInTerminal(path: path)
        }
        
        Divider()
        
        // 书签操作
        if bookmarkManager.contains(path: file.path) {
            Button("Remove from Bookmarks") {
                if let bookmark = bookmarkManager.bookmarks.first(where: { $0.path == file.path }) {
                    bookmarkManager.remove(bookmark)
                    appState.showToast("Bookmark removed: \(file.name)")
                }
            }
        } else {
            Button("Add to Bookmarks (⌘B)") {
                bookmarkManager.addBookmark(for: file)
                appState.showToast("Bookmark added: \(file.name)")
            }
        }
        
        Divider()
        
        Button("Copy (y)") {
            appState.yankSelectedFiles()
        }
        
        Button("Paste (p)") {
            pasteFiles()
        }
        .disabled(appState.clipboard.isEmpty)
        
        Divider()
        
        Button("Show in Finder") {
            FileSystemService.shared.revealInFinder(file)
        }
        
        Button("Copy Full Path") {
            copyFullPath(file: file)
        }
        
        Divider()
        
        Button("Move to Trash") {
            deleteSelectedFiles()
        }
        .keyboardShortcut(.delete, modifiers: .command)
        
        Divider()
        
        Button("Refresh (R)") {
            refreshDirectory()
        }
    }
    
    /// 目录级右键菜单（空白处右键）
    @ViewBuilder
    private var directoryContextMenu: some View {
        Button("New File") {
            createNewFile()
        }
        
        Button("New Folder") {
            createNewFolder()
        }
        
        Divider()
        
        Button("Paste (p)") {
            pasteFiles()
        }
        .disabled(appState.clipboard.isEmpty)
        
        Divider()
        
        Button("Open in Terminal") {
            FileSystemService.shared.openInTerminal(path: pane.activeTab.currentPath)
        }
        
        Divider()
        
        Button("Refresh (R)") {
            refreshDirectory()
        }
    }
    
    // MARK: - 事件处理
    
    private func handleFileClick(index: Int) {
        appState.setActivePane(side)
        pane.cursorIndex = index
        
        // Visual 模式下自动选中
        if appState.mode == .visual {
            pane.selectCurrentFile()
        }
    }
    
    private func handleFileDoubleClick(file: FileItem) {
        if file.type == .folder {
            // 进入目录
            navigateTo(file.path)
        } else {
            // 打开文件
            FileSystemService.shared.openFile(file)
        }
    }
    
    /// 复制文件完整路径到剪贴板
    private func copyFullPath(file: FileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(file.path.path, forType: .string)
        
        // 显示成功提示
        appState.showToast("Path copied: \(file.name)")
    }
    
    /// 刷新当前目录
    func refreshDirectory() {
        loadCurrentDirectoryWithPermissionCheck()
        appState.showToast("Refreshed")
    }
    
    // MARK: - 目录监控
    
    /// 开始监控当前目录
    private func startDirectoryMonitoring() {
        // 停止之前的监控
        stopDirectoryMonitoring()
        
        let currentPath = pane.activeTab.currentPath
        let paneRef = pane
        let settingsRef = settingsManager
        
        // 使用 FSEvents 监控器（推荐方案，更可靠）
        let monitor = FSEventsDirectoryMonitor(url: currentPath)
        monitor.start {
            // 目录变化时自动刷新
            let result = FileSystemService.shared.loadDirectoryWithPermissionCheck(at: paneRef.activeTab.currentPath)
            if case .success(var files) = result {
                // 获取 Git 状态（如果启用）
                if settingsRef.settings.git.enabled {
                    let gitSettings = settingsRef.settings.git
                    let gitService = GitService.shared
                    
                    // 获取仓库信息
                    let repoInfo = gitService.getRepositoryInfo(at: currentPath)
                    
                    if repoInfo.isGitRepository {
                        // 获取文件状态
                        let statusDict = gitService.getFileStatuses(
                            in: currentPath,
                            includeUntracked: gitSettings.showUntrackedFiles,
                            includeIgnored: gitSettings.showIgnoredFiles
                        )
                        
                        // 应用状态到文件（使用标准化路径比较）
                        for index in files.indices {
                            let standardizedPath = files[index].path.standardizedFileURL
                            if let status = statusDict[standardizedPath] {
                                files[index] = files[index].withGitStatus(status)
                            } else if files[index].type == .folder {
                                let folderPath = standardizedPath.path + "/"
                                let hasModifiedChildren = statusDict.keys.contains { key in
                                    key.path.hasPrefix(folderPath)
                                }
                                if hasModifiedChildren {
                                    files[index] = files[index].withGitStatus(.modified)
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            paneRef.gitInfo = repoInfo
                        }
                    }
                }
                
                paneRef.activeTab.files = files
            }
        }
        
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
        pane.cursorIndex = 0
        pane.clearSelections()
        loadCurrentDirectoryWithPermissionCheck()
    }
    
    func loadCurrentDirectoryWithPermissionCheck() {
        let result = FileSystemService.shared.loadDirectoryWithPermissionCheck(at: pane.activeTab.currentPath)
        
        switch result {
        case .success(var files):
            // 获取 Git 状态（如果启用）
            if settingsManager.settings.git.enabled {
                let gitSettings = settingsManager.settings.git
                applyGitStatus(to: &files, settings: gitSettings)
            } else {
                pane.gitInfo = nil
            }
            
            pane.activeTab.files = files
            permissionDeniedPath = nil
            showPermissionError = false
            // 手动触发 UI 刷新
            pane.objectWillChange.send()
            
        case .permissionDenied(let path):
            pane.activeTab.files = []
            permissionDeniedPath = path
            showPermissionError = true
            pane.gitInfo = nil
            pane.objectWillChange.send()
            
        case .notFound(let path):
            pane.activeTab.files = []
            appState.showToast("Directory not found: \(path.lastPathComponent)")
            permissionDeniedPath = nil
            showPermissionError = false
            pane.gitInfo = nil
            pane.objectWillChange.send()
            // 尝试返回上级目录
            leaveDirectory()
            
        case .error(let message):
            pane.activeTab.files = []
            appState.showToast("Error: \(message)")
            permissionDeniedPath = nil
            showPermissionError = false
            pane.gitInfo = nil
            pane.objectWillChange.send()
        }
    }
    
    /// 应用 Git 状态到文件列表
    private func applyGitStatus(to files: inout [FileItem], settings: GitSettings) {
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
            FileSystemService.shared.requestFolderAccess(for: deniedPath) { grantedURL in
                if let _ = grantedURL {
                    // 用户授权成功，重新加载目录
                    DispatchQueue.main.async {
                        self.loadCurrentDirectoryWithPermissionCheck()
                    }
                }
            }
        }
    }
    
    func enterDirectory() {
        guard let file = pane.activeTab.files[safe: pane.cursorIndex] else { return }
        if file.type == .folder {
            navigateTo(file.path)
        } else {
            FileSystemService.shared.openFile(file)
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
            loadCurrentDirectoryWithPermissionCheck()
            
            // 在上级目录中找到之前所在的目录并选中
            if let index = pane.activeTab.files.firstIndex(where: { $0.name == currentDirName }) {
                pane.activeTab.cursorFileId = pane.activeTab.files[index].id
            } else {
                pane.cursorIndex = 0
            }
        }
    }
    
    // MARK: - 文件操作
    
    func pasteFiles() {
        guard !appState.clipboard.isEmpty else { return }
        
        do {
            let destination = pane.activeTab.currentPath
            
            if appState.clipboardOperation == .copy {
                try FileSystemService.shared.copyFiles(appState.clipboard, to: destination)
                appState.showToast("\(appState.clipboard.count) file(s) copied")
            } else {
                try FileSystemService.shared.moveFiles(appState.clipboard, to: destination)
                appState.showToast("\(appState.clipboard.count) file(s) moved")
                appState.clipboard.removeAll()
            }
            
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
        }
    }
    
    func deleteSelectedFiles() {
        let selections = pane.selections
        var filesToDelete: [FileItem]
        
        if selections.isEmpty {
            guard let file = pane.activeTab.files[safe: pane.cursorIndex] else { return }
            // 父目录项 (..) 不能被删除
            guard !file.isParentDirectory else {
                appState.showToast("Cannot delete parent directory item")
                return
            }
            filesToDelete = [file]
        } else {
            // 排除父目录项
            filesToDelete = pane.activeTab.files.filter { selections.contains($0.id) && !$0.isParentDirectory }
        }
        
        guard !filesToDelete.isEmpty else {
            appState.showToast("No files to delete")
            return
        }
        
        do {
            try FileSystemService.shared.trashFiles(filesToDelete)
            appState.showToast("\(filesToDelete.count) file(s) moved to Trash")
            pane.clearSelections()
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
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
            _ = try FileSystemService.shared.createFile(at: pane.activeTab.currentPath, name: uniqueName)
            appState.showToast("Created file: \(uniqueName)")
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast("Error creating file: \(error.localizedDescription)")
        }
    }
    
    private func createNewFolder() {
        let baseName = "New Folder"
        let uniqueName = FileSystemService.shared.generateUniqueFileName(
            for: baseName,
            in: pane.activeTab.currentPath
        )
        
        do {
            _ = try FileSystemService.shared.createDirectory(at: pane.activeTab.currentPath, name: uniqueName)
            appState.showToast("Created folder: \(uniqueName)")
            loadCurrentDirectoryWithPermissionCheck()
        } catch {
            appState.showToast("Error creating folder: \(error.localizedDescription)")
        }
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
                .foregroundColor(viewMode == mode ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 20, height: 18)
                .background(viewMode == mode ? Theme.backgroundElevated : .clear)
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
