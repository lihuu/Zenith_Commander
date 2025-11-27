//
//  MainView.swift
//  Zenith Commander
//
//  主视图 - 双面板布局
//

import SwiftUI
import Combine

struct MainView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        VStack(spacing: 0) {
            // 双面板区域
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 左面板
                    PaneView(
                        pane: appState.leftPane,
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
                        side: .right
                    )
                    .frame(width: geometry.size.width / 2 - 1)
                }
            }
            .environmentObject(appState)
            
            // 状态栏
            StatusBarView(
                mode: appState.mode,
                statusText: appState.statusText,
                itemCount: appState.currentPane.activeTab.files.count,
                selectedCount: appState.currentPane.selections.count
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
        }
        .focusable()
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .onAppear {
            // 加载可用驱动器
            appState.availableDrives = FileSystemService.shared.getMountedVolumes()
        }
    }
    
    // MARK: - 键盘处理
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let key = keyPress.key
        let modifiers = keyPress.modifiers
        
        // ESC - 退出当前模式
        if key == .escape {
            // 如果在 Visual 模式，清除选中状态
            if appState.mode == .visual {
                appState.currentPane.clearSelections()
            }
            appState.exitMode()
            return .handled
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
        case .aiAnalysis:
            return .ignored
        }
    }
    
    // MARK: - Normal 模式
    
    private func handleNormalModeKey(_ key: KeyEquivalent, modifiers: EventModifiers) -> KeyPress.Result {
        let pane = appState.currentPane
        
        switch key {
        // 导航
        case KeyEquivalent("j"):
            moveCursor(direction: .down)
            return .handled
            
        case KeyEquivalent("k"):
            moveCursor(direction: .up)
            return .handled
            
        case KeyEquivalent("h"):
            leaveDirectory()
            return .handled
            
        case KeyEquivalent("l"):
            enterDirectory()
            return .handled
            
        case .return:
            enterDirectory()
            return .handled
            
        // 切换面板
        case .tab:
            appState.toggleActivePane()
            return .handled
            
        // 模式切换
        case KeyEquivalent("v"):
            appState.enterMode(.visual)
            // 进入 Visual 模式时设置锚点并选中当前文件
            pane.startVisualSelection()
            return .handled
            
        case KeyEquivalent(":"):
            appState.enterMode(.command)
            return .handled
            
        case KeyEquivalent("/"):
            appState.enterMode(.filter)
            return .handled
            
        // 驱动器选择 (Shift + D)
        case KeyEquivalent("D"):
            if modifiers.contains(.shift) {
                appState.enterMode(.driveSelect)
                return .handled
            }
            return .ignored
            
        // 标签页操作
        case KeyEquivalent("t"):
            pane.addTab()
            refreshCurrentPane()
            appState.showToast("New tab created")
            return .handled
            
        case KeyEquivalent("w"):
            if pane.tabs.count > 1 {
                pane.closeTab(at: pane.activeTabIndex)
            }
            return .handled
            
        // Shift + H/L 切换标签页
        case KeyEquivalent("H"):
            if modifiers.contains(.shift) {
                pane.previousTab()
                refreshCurrentPane()
                return .handled
            }
            return .ignored
            
        case KeyEquivalent("L"):
            if modifiers.contains(.shift) {
                pane.nextTab()
                refreshCurrentPane()
                return .handled
            }
            return .ignored
            
        // 复制/粘贴
        case KeyEquivalent("y"):
            appState.yankSelectedFiles()
            return .handled
            
        case KeyEquivalent("p"):
            pasteFiles()
            return .handled
            
        // 跳转到顶部/底部
        case KeyEquivalent("g"):
            pane.cursorIndex = 0
            return .handled
            
        case KeyEquivalent("G"):
            if modifiers.contains(.shift) {
                pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
                return .handled
            }
            return .ignored
            
        default:
            return .ignored
        }
    }
    
    // MARK: - Visual 模式
    
    private func handleVisualModeKey(_ key: KeyEquivalent, modifiers: EventModifiers) -> KeyPress.Result {
        let pane = appState.currentPane
        
        switch key {
        case KeyEquivalent("j"):
            moveVisualCursor(direction: .down)
            return .handled
            
        case KeyEquivalent("k"):
            moveVisualCursor(direction: .up)
            return .handled
            
        case KeyEquivalent("g"):
            // 跳到顶部
            Task { @MainActor in
                pane.activeTab.cursorIndex = 0
                pane.updateVisualSelection()
                pane.objectWillChange.send()
            }
            return .handled
            
        case KeyEquivalent("G"):
            // 跳到底部
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    pane.activeTab.cursorIndex = max(0, pane.activeTab.files.count - 1)
                    pane.updateVisualSelection()
                    pane.objectWillChange.send()
                }
                return .handled
            }
            return .ignored
            
        case KeyEquivalent("y"):
            appState.yankSelectedFiles()
            appState.exitMode()
            pane.clearSelections()
            return .handled
            
        case KeyEquivalent("d"):
            // 删除选中文件
            deleteSelectedFiles()
            appState.exitMode()
            pane.clearSelections()
            return .handled
            
        case KeyEquivalent("r"):
            // 批量重命名
            appState.showRenameModal = true
            return .handled
            
        case KeyEquivalent("v"), .escape:
            // 退出 Visual 模式
            pane.clearSelections()
            appState.exitMode()
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
            executeCommand()
            return .handled
            
        case .delete:
            if !appState.commandInput.isEmpty {
                appState.commandInput.removeLast()
            }
            return .handled
            
        default:
            let char = key.character
            if char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation {
                appState.commandInput.append(char)
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
            let pane = appState.currentPane
            pane.activeTab.unfilteredFiles = []
            appState.mode = .normal
            appState.filterInput = ""
            return .handled
            
        case .delete:
            if !appState.filterInput.isEmpty {
                appState.filterInput.removeLast()
                // 实时更新过滤
                applyFilter()
            }
            return .handled
            
        default:
            let char = key.character
            if char.isLetter || char.isNumber || char == "." || char == "_" || char == "-" || char == " " {
                appState.filterInput.append(char)
                // 实时过滤
                applyFilter()
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Drive Select 模式
    
    private func handleDriveSelectModeKey(_ key: KeyEquivalent) -> KeyPress.Result {
        switch key {
        case KeyEquivalent("j"):
            if appState.driveSelectorCursor < appState.availableDrives.count - 1 {
                appState.driveSelectorCursor += 1
            }
            return .handled
            
        case KeyEquivalent("k"):
            if appState.driveSelectorCursor > 0 {
                appState.driveSelectorCursor -= 1
            }
            return .handled
            
        case .return:
            if let drive = appState.availableDrives[safe: appState.driveSelectorCursor] {
                selectDrive(drive)
            }
            return .handled
            
        default:
            return .ignored
        }
    }
    
    // MARK: - 辅助方法
    
    enum CursorDirection {
        case up, down
    }
    
    private func moveCursor(direction: CursorDirection) {
        let pane = appState.currentPane
        let fileCount = pane.activeTab.files.count
        guard fileCount > 0 else { return }
        
        // 使用 Task 延迟执行，避免在视图更新期间修改状态
        Task { @MainActor in
            switch direction {
            case .up:
                pane.activeTab.cursorIndex = max(0, pane.activeTab.cursorIndex - 1)
            case .down:
                pane.activeTab.cursorIndex = min(fileCount - 1, pane.activeTab.cursorIndex + 1)
            }
            // 手动触发 objectWillChange
            pane.objectWillChange.send()
        }
    }
    
    private func moveVisualCursor(direction: CursorDirection) {
        let pane = appState.currentPane
        let fileCount = pane.activeTab.files.count
        guard fileCount > 0 else { return }
        
        Task { @MainActor in
            switch direction {
            case .up:
                pane.activeTab.cursorIndex = max(0, pane.activeTab.cursorIndex - 1)
            case .down:
                pane.activeTab.cursorIndex = min(fileCount - 1, pane.activeTab.cursorIndex + 1)
            }
            pane.updateVisualSelection()
            pane.objectWillChange.send()
        }
    }
    
    private func enterDirectory() {
        let pane = appState.currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex] else { return }
        
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
        let parent = FileSystemService.shared.parentDirectory(of: pane.activeTab.currentPath)
        
        if parent.path != pane.activeTab.currentPath.path {
            pane.activeTab.currentPath = parent
            pane.cursorIndex = 0
            pane.clearSelections()
            refreshCurrentPane()
        }
    }
    
    private func refreshCurrentPane() {
        let pane = appState.currentPane
        let files = FileSystemService.shared.loadDirectory(at: pane.activeTab.currentPath)
        pane.activeTab.files = files
    }
    
    private func pasteFiles() {
        guard !appState.clipboard.isEmpty else { return }
        
        do {
            let destination = appState.currentPane.activeTab.currentPath
            
            if appState.clipboardOperation == .copy {
                try FileSystemService.shared.copyFiles(appState.clipboard, to: destination)
                appState.showToast("\(appState.clipboard.count) file(s) copied")
            } else {
                try FileSystemService.shared.moveFiles(appState.clipboard, to: destination)
                appState.showToast("\(appState.clipboard.count) file(s) moved")
                appState.clipboard.removeAll()
            }
            
            refreshCurrentPane()
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
        }
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
        let command = appState.commandInput.trimmingCharacters(in: .whitespaces)
        
        if command.hasPrefix("ai ") {
            // AI 命令
            let query = String(command.dropFirst(3))
            appState.showToast("AI: \(query)")
        } else if command == "mkdir" {
            appState.showToast("Create directory...")
        } else if command == "q" || command == "quit" {
            NSApp.terminate(nil)
        } else {
            appState.showToast("Unknown command: \(command)")
        }
        
        appState.exitMode()
    }
    
    private func applyFilter() {
        let pane = appState.currentPane
        let tab = pane.activeTab
        let filter = appState.filterInput.lowercased()
        
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
            let sourceFiles = tab.unfilteredFiles.isEmpty ? tab.files : tab.unfilteredFiles
            tab.files = sourceFiles.filter { $0.name.lowercased().contains(filter) }
        }
        pane.cursorIndex = 0
    }
    
    private func deleteSelectedFiles() {
        let pane = appState.currentPane
        let selections = pane.selections
        let filesToDelete: [FileItem]
        
        if selections.isEmpty {
            guard let file = pane.activeTab.files[safe: pane.cursorIndex] else { return }
            filesToDelete = [file]
        } else {
            filesToDelete = pane.activeTab.files.filter { selections.contains($0.id) }
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
