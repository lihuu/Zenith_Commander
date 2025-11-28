//
//  PaneView.swift
//  Zenith Commander
//
//  单个面板视图
//

import SwiftUI
import Combine

struct PaneView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var pane: PaneState
    @ObservedObject private var themeManager = ThemeManager.shared
    let side: PaneSide
    
    @State private var permissionDeniedPath: URL? = nil
    @State private var showPermissionError: Bool = false
    
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
            loadCurrentDirectoryWithPermissionCheck()
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
                        .onTapGesture {
                            handleFileClick(index: index)
                        }
                        .onTapGesture(count: 2) {
                            handleFileDoubleClick(file: file)
                        }
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
            .onChange(of: pane.cursorIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
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
                            .onTapGesture {
                                handleFileClick(index: index)
                            }
                            .onTapGesture(count: 2) {
                                handleFileDoubleClick(file: file)
                            }
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
                .onChange(of: pane.cursorIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newValue, anchor: .center)
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
        
        Divider()
        
        Button("Move to Trash") {
            deleteSelectedFiles()
        }
        .keyboardShortcut(.delete, modifiers: .command)
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
        case .success(let files):
            pane.activeTab.files = files
            permissionDeniedPath = nil
            showPermissionError = false
            // 手动触发 UI 刷新
            pane.objectWillChange.send()
            
        case .permissionDenied(let path):
            pane.activeTab.files = []
            permissionDeniedPath = path
            showPermissionError = true
            pane.objectWillChange.send()
            
        case .notFound(let path):
            pane.activeTab.files = []
            appState.showToast("Directory not found: \(path.lastPathComponent)")
            permissionDeniedPath = nil
            showPermissionError = false
            pane.objectWillChange.send()
            // 尝试返回上级目录
            leaveDirectory()
            
        case .error(let message):
            pane.activeTab.files = []
            appState.showToast("Error: \(message)")
            permissionDeniedPath = nil
            showPermissionError = false
            pane.objectWillChange.send()
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
        let parent = FileSystemService.shared.parentDirectory(of: pane.activeTab.currentPath)
        // 检查是否已经在根目录
        if parent.path != pane.activeTab.currentPath.path {
            pane.activeTab.currentPath = parent
            pane.cursorIndex = 0
            pane.clearSelections()
            loadCurrentDirectoryWithPermissionCheck()
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
    return PaneView(
        pane: appState.leftPane,
        side: .left
    )
    .environmentObject(appState)
    .frame(width: 400, height: 600)
}
