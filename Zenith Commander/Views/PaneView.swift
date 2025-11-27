//
//  PaneView.swift
//  Zenith Commander
//
//  单个面板视图
//

import SwiftUI

struct PaneView: View {
    @Bindable var appState: AppState
    @Bindable var pane: PaneState
    let side: PaneSide
    
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
                },
                onTabClose: { index in
                    pane.closeTab(at: index)
                },
                onTabAdd: {
                    pane.addTab()
                    loadCurrentDirectory()
                }
            )
            
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
                    Text("\(pane.currentFiles.count) items")
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
            
            // 文件列表
            fileListView
        }
        .background(Theme.background)
        .opacity(isActivePane ? 1.0 : 0.85)
        .onTapGesture {
            appState.setActivePane(side)
        }
        .onAppear {
            loadCurrentDirectory()
        }
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
                    ForEach(Array(pane.currentFiles.enumerated()), id: \.element.id) { index, file in
                        FileRowView(
                            file: file,
                            isActive: index == pane.cursorIndex,
                            isSelected: pane.selections.contains(file.id),
                            isPaneActive: isActivePane
                        )
                        .id(index)
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
                    
                    if pane.currentFiles.isEmpty {
                        emptyDirectoryView
                    }
                }
            }
            .onChange(of: pane.cursorIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    private var gridView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90, maximum: 100), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(Array(pane.currentFiles.enumerated()), id: \.element.id) { index, file in
                        FileGridItemView(
                            file: file,
                            isActive: index == pane.cursorIndex,
                            isSelected: pane.selections.contains(file.id),
                            isPaneActive: isActivePane
                        )
                        .id(index)
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
                .padding(8)
                
                if pane.currentFiles.isEmpty {
                    emptyDirectoryView
                }
            }
            .onChange(of: pane.cursorIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
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
        loadCurrentDirectory()
    }
    
    func loadCurrentDirectory() {
        let files = FileSystemService.shared.loadDirectory(at: pane.activeTab.currentPath)
        pane.activeTab.files = files
    }
    
    func enterDirectory() {
        guard let file = pane.currentFiles[safe: pane.cursorIndex] else { return }
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
            navigateTo(parent)
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
            
            loadCurrentDirectory()
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
        }
    }
    
    func deleteSelectedFiles() {
        let selections = pane.selections
        let filesToDelete: [FileItem]
        
        if selections.isEmpty {
            guard let file = pane.currentFiles[safe: pane.cursorIndex] else { return }
            filesToDelete = [file]
        } else {
            filesToDelete = pane.currentFiles.filter { selections.contains($0.id) }
        }
        
        do {
            try FileSystemService.shared.trashFiles(filesToDelete)
            appState.showToast("\(filesToDelete.count) file(s) moved to Trash")
            pane.clearSelections()
            loadCurrentDirectory()
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
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
        appState: appState,
        pane: appState.leftPane,
        side: .left
    )
    .frame(width: 400, height: 600)
}
