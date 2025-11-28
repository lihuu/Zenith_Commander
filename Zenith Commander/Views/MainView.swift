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
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showSettings = false
    
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
                driveName: appState.currentPane.activeTab.drive.name,
                itemCount: appState.currentPane.activeTab.files.count,
                selectedCount: appState.currentPane.selections.count,
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
                        selectDrive(drive)
                    },
                    onDismiss: {
                        appState.exitMode()
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
            Task { @MainActor in
                // 如果在 Visual 模式，清除选中状态
                if appState.mode == .visual {
                    appState.currentPane.clearSelections()
                }
                appState.exitMode()
            }
            return .handled
        }
        
        // Cmd+, - 打开设置
        if key == KeyEquivalent(",") && modifiers.contains(.command) {
            Task { @MainActor in
                showSettings = true
            }
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
        let isGridView = pane.viewMode == .grid
        
        switch key {
        // 方向键导航
        case .upArrow:
            moveCursor(direction: .up)
            return .handled
            
        case .downArrow:
            moveCursor(direction: .down)
            return .handled
            
        case .leftArrow:
            if isGridView {
                moveCursor(direction: .left)
            } else {
                Task { @MainActor in leaveDirectory() }
            }
            return .handled
            
        case .rightArrow:
            if isGridView {
                moveCursor(direction: .right)
            } else {
                Task { @MainActor in enterDirectory() }
            }
            return .handled
        
        // Vim 风格导航
        case KeyEquivalent("j"):
            moveCursor(direction: .down)
            return .handled
            
        case KeyEquivalent("k"):
            moveCursor(direction: .up)
            return .handled
            
        case KeyEquivalent("h"):
            if isGridView {
                moveCursor(direction: .left)
            } else {
                Task { @MainActor in leaveDirectory() }
            }
            return .handled
            
        case KeyEquivalent("l"):
            if isGridView {
                moveCursor(direction: .right)
            } else {
                Task { @MainActor in enterDirectory() }
            }
            return .handled
            
        case .return:
            Task { @MainActor in enterDirectory() }
            return .handled
            
        // 切换面板
        case .tab:
            Task { @MainActor in appState.toggleActivePane() }
            return .handled
            
        // 模式切换
        case KeyEquivalent("v"):
            Task { @MainActor in
                appState.enterMode(.visual)
                appState.currentPane.startVisualSelection()
            }
            return .handled
            
        case KeyEquivalent(":"):
            Task { @MainActor in appState.enterMode(.command) }
            return .handled
            
        case KeyEquivalent("/"):
            Task { @MainActor in
                appState.enterMode(.filter)
                appState.filterUseRegex = false
            }
            return .handled
        
        // 正则表达式过滤 (Shift + /)
        case KeyEquivalent("?"):
            Task { @MainActor in
                appState.enterMode(.filter)
                appState.filterUseRegex = true
            }
            return .handled
            
        // 驱动器选择 (Shift + D)
        case KeyEquivalent("D"):
            if modifiers.contains(.shift) {
                Task { @MainActor in appState.enterMode(.driveSelect) }
                return .handled
            }
            return .ignored
            
        // 关闭标签页
        case KeyEquivalent("w"):
            Task { @MainActor in
                let pane = appState.currentPane
                if pane.tabs.count > 1 {
                    pane.closeTab(at: pane.activeTabIndex)
                }
            }
            return .handled
            
        // Shift + H/L 切换标签页
        case KeyEquivalent("H"):
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    appState.currentPane.previousTab()
                    refreshCurrentPane()
                }
                return .handled
            }
            return .ignored
            
        case KeyEquivalent("L"):
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    appState.currentPane.nextTab()
                    refreshCurrentPane()
                }
                return .handled
            }
            return .ignored
            
        // 复制/粘贴
        case KeyEquivalent("y"):
            Task { @MainActor in appState.yankSelectedFiles() }
            return .handled
            
        case KeyEquivalent("p"):
            Task { @MainActor in pasteFiles() }
            return .handled
            
        // 跳转到顶部/底部
        case KeyEquivalent("g"):
            Task { @MainActor in appState.currentPane.cursorIndex = 0 }
            return .handled
            
        case KeyEquivalent("G"):
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    let pane = appState.currentPane
                    pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
                }
                return .handled
            }
            return .ignored
        
        // 主题切换 (Ctrl+T)
        case KeyEquivalent("t"):
            if modifiers.contains(.control) {
                Task { @MainActor in
                    themeManager.cycleTheme()
                    appState.showToast("Theme: \(themeManager.mode.displayName)")
                }
                return .handled
            }
            // 没有 Ctrl 修饰符时，创建新标签页
            Task { @MainActor in
                let pane = appState.currentPane
                pane.addTab()
                refreshCurrentPane()
                appState.showToast("New tab created")
            }
            return .handled
            
        default:
            return .ignored
        }
    }
    
    // MARK: - Visual 模式
    
    private func handleVisualModeKey(_ key: KeyEquivalent, modifiers: EventModifiers) -> KeyPress.Result {
        let pane = appState.currentPane
        let isGridView = pane.viewMode == .grid
        
        switch key {
        // 方向键导航
        case .upArrow:
            moveVisualCursor(direction: .up)
            return .handled
            
        case .downArrow:
            moveVisualCursor(direction: .down)
            return .handled
            
        case .leftArrow:
            if isGridView {
                moveVisualCursor(direction: .left)
            }
            return .handled
            
        case .rightArrow:
            if isGridView {
                moveVisualCursor(direction: .right)
            }
            return .handled
        
        // Vim 风格导航
        case KeyEquivalent("j"):
            moveVisualCursor(direction: .down)
            return .handled
            
        case KeyEquivalent("k"):
            moveVisualCursor(direction: .up)
            return .handled
            
        case KeyEquivalent("h"):
            if isGridView {
                moveVisualCursor(direction: .left)
            }
            return .handled
            
        case KeyEquivalent("l"):
            if isGridView {
                moveVisualCursor(direction: .right)
            }
            return .handled
            
        case KeyEquivalent("g"):
            // 跳到顶部
            Task { @MainActor in
                let pane = appState.currentPane
                pane.cursorIndex = 0
                pane.updateVisualSelection()
                pane.objectWillChange.send()
            }
            return .handled
            
        case KeyEquivalent("G"):
            // 跳到底部
            if modifiers.contains(.shift) {
                Task { @MainActor in
                    let pane = appState.currentPane
                    pane.cursorIndex = max(0, pane.activeTab.files.count - 1)
                    pane.updateVisualSelection()
                    pane.objectWillChange.send()
                }
                return .handled
            }
            return .ignored
            
        case KeyEquivalent("y"):
            Task { @MainActor in
                let pane = appState.currentPane
                appState.yankSelectedFiles()
                appState.exitMode()
                pane.clearSelections()
            }
            return .handled
            
        case KeyEquivalent("d"):
            // 删除选中文件
            Task { @MainActor in
                let pane = appState.currentPane
                deleteSelectedFiles()
                appState.exitMode()
                pane.clearSelections()
            }
            return .handled
            
        case KeyEquivalent("r"):
            // 批量重命名
            Task { @MainActor in appState.showRenameModal = true }
            return .handled
            
        case KeyEquivalent("v"), .escape:
            // 退出 Visual 模式
            Task { @MainActor in
                appState.currentPane.clearSelections()
                appState.exitMode()
            }
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
            Task { @MainActor in
                executeCommand()
            }
            return .handled
            
        case .delete:
            Task { @MainActor in
                if !appState.commandInput.isEmpty {
                    appState.commandInput.removeLast()
                }
            }
            return .handled
            
        default:
            let char = key.character
            if char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation {
                Task { @MainActor in
                    appState.commandInput.append(char)
                }
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
            Task { @MainActor in
                let pane = appState.currentPane
                pane.activeTab.unfilteredFiles = []
                appState.mode = .normal
                appState.filterInput = ""
                appState.filterUseRegex = false
            }
            return .handled
            
        case .delete:
            Task { @MainActor in
                if !appState.filterInput.isEmpty {
                    appState.filterInput.removeLast()
                    // 实时更新过滤
                    applyFilter()
                }
            }
            return .handled
            
        default:
            let char = key.character
            // 普通过滤支持常用字符，正则表达式支持更多特殊字符
            let isValidChar: Bool
            if appState.filterUseRegex {
                // 正则表达式模式：支持更多字符
                isValidChar = char.isLetter || char.isNumber || char.isWhitespace ||
                    "._-*+?^$[](){}|\\".contains(char)
            } else {
                // 普通模式：支持基本字符
                isValidChar = char.isLetter || char.isNumber || "._- ".contains(char)
            }
            
            if isValidChar {
                Task { @MainActor in
                    appState.filterInput.append(char)
                    // 实时过滤
                    applyFilter()
                }
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Drive Select 模式
    
    private func handleDriveSelectModeKey(_ key: KeyEquivalent) -> KeyPress.Result {
        switch key {
        case KeyEquivalent("j"):
            Task { @MainActor in
                if appState.driveSelectorCursor < appState.availableDrives.count - 1 {
                    appState.driveSelectorCursor += 1
                }
            }
            return .handled
            
        case KeyEquivalent("k"):
            Task { @MainActor in
                if appState.driveSelectorCursor > 0 {
                    appState.driveSelectorCursor -= 1
                }
            }
            return .handled
            
        case .return:
            Task { @MainActor in
                if let drive = appState.availableDrives[safe: appState.driveSelectorCursor] {
                    selectDrive(drive)
                }
            }
            return .handled
            
        default:
            return .ignored
        }
    }
    
    // MARK: - 辅助方法
    
    enum CursorDirection {
        case up, down, left, right
    }
    
    private func moveCursor(direction: CursorDirection) {
        let pane = appState.currentPane
        let fileCount = pane.activeTab.files.count
        guard fileCount > 0 else { return }
        
        // 使用 Task 延迟执行，避免在视图更新期间修改状态
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
                    currentIndex = min(fileCount - 1, currentIndex + columnCount)
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
                case .left, .right:
                    // List 模式不处理左右导航
                    return
                }
            }
            
            pane.activeTab.cursorFileId = pane.activeTab.files[currentIndex].id
        }
    }
    
    private func moveVisualCursor(direction: CursorDirection) {
        let pane = appState.currentPane
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
                    currentIndex = min(fileCount - 1, currentIndex + columnCount)
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
            
            pane.activeTab.cursorFileId = pane.activeTab.files[currentIndex].id
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
        // 手动触发 UI 刷新
        pane.objectWillChange.send()
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
            // 如果是移动操作，还需要刷新另一个面板（源文件可能在那里）
            if appState.clipboardOperation == .cut {
                refreshOtherPane()
            }
        } catch {
            appState.showToast("Error: \(error.localizedDescription)")
        }
    }
    
    private func refreshOtherPane() {
        let otherPane = appState.activePane == .left ? appState.rightPane : appState.leftPane
        let files = FileSystemService.shared.loadDirectory(at: otherPane.activeTab.currentPath)
        otherPane.activeTab.files = files
        otherPane.objectWillChange.send()
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
            let sourceFiles = tab.unfilteredFiles.isEmpty ? tab.files : tab.unfilteredFiles
            
            if appState.filterUseRegex {
                // 正则表达式过滤
                do {
                    let regex = try NSRegularExpression(pattern: filter, options: [.caseInsensitive])
                    tab.files = sourceFiles.filter { file in
                        let range = NSRange(file.name.startIndex..., in: file.name)
                        return regex.firstMatch(in: file.name, options: [], range: range) != nil
                    }
                } catch {
                    // 正则表达式无效时，不过滤
                    tab.files = sourceFiles
                }
            } else {
                // 普通字符串匹配（大小写不敏感）
                let lowerFilter = filter.lowercased()
                tab.files = sourceFiles.filter { $0.name.lowercased().contains(lowerFilter) }
            }
        }
        pane.cursorIndex = 0
    }
    
    private func deleteSelectedFiles() {
        let pane = appState.currentPane
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
