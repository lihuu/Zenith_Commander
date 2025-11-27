//
//  MainView.swift
//  Zenith Commander
//
//  主视图 - 双面板布局
//

import SwiftUI

struct MainView: View {
    @State private var appState = AppState()
    @State private var leftPaneView: PaneView?
    @State private var rightPaneView: PaneView?
    
    var body: some View {
        VStack(spacing: 0) {
            // 双面板区域
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 左面板
                    PaneView(
                        appState: appState,
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
                        appState: appState,
                        pane: appState.rightPane,
                        side: .right
                    )
                    .frame(width: geometry.size.width / 2 - 1)
                }
            }
            
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
            moveCursor(direction: .down)
            pane.selectCurrentFile()
            return .handled
            
        case KeyEquivalent("k"):
            moveCursor(direction: .up)
            pane.selectCurrentFile()
            return .handled
            
        case KeyEquivalent("y"):
            appState.yankSelectedFiles()
            appState.exitMode()
            pane.clearSelections()
            return .handled
            
        case KeyEquivalent("r"):
            // 批量重命名
            appState.showRenameModal = true
            return .handled
            
        case KeyEquivalent("v"):
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
            applyFilter()
            appState.exitMode()
            return .handled
            
        case .delete:
            if !appState.filterInput.isEmpty {
                appState.filterInput.removeLast()
            }
            return .handled
            
        default:
            let char = key.character
            if char.isLetter || char.isNumber || char == "." || char == "_" || char == "-" {
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
        
        switch direction {
        case .up:
            pane.cursorIndex = max(0, pane.cursorIndex - 1)
        case .down:
            pane.cursorIndex = min(fileCount - 1, pane.cursorIndex + 1)
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
        let filter = appState.filterInput.lowercased()
        if filter.isEmpty {
            // 重新加载完整列表
            refreshCurrentPane()
        } else {
            let pane = appState.currentPane
            let allFiles = FileSystemService.shared.loadDirectory(at: pane.activeTab.currentPath)
            pane.activeTab.files = allFiles.filter { $0.name.lowercased().contains(filter) }
            pane.cursorIndex = 0
        }
    }
}

#Preview {
    MainView()
        .frame(width: 1200, height: 800)
}
