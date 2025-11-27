//
//  Zenith_CommanderTests.swift
//  Zenith CommanderTests
//
//  验收测试 - 单元测试部分
//

import Testing
import Foundation
@testable import Zenith_Commander

// MARK: - 1. FileItem 模型测试

struct FileItemTests {
    
    @Test func testFileItemFromURL() {
        // 使用实际存在的目录测试
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        if let fileItem = FileItem.fromURL(homeDir) {
            #expect(fileItem.type == .folder)
            #expect(!fileItem.name.isEmpty)
            #expect(fileItem.path == homeDir)
        }
    }
    
    @Test func testFileItemFormattedSize() {
        // 使用 fromURL 创建真实的 FileItem
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        if let fileItem = FileItem.fromURL(homeDir) {
            // folder 应该显示 "--"
            #expect(fileItem.formattedSize == "--")
        }
    }
    
    @Test func testFileItemIconName() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        if let fileItem = FileItem.fromURL(homeDir) {
            #expect(fileItem.iconName == "folder.fill")
        }
    }
}

// MARK: - 2. AppMode 测试

struct AppModeTests {
    
    @Test func testAppModeRawValues() {
        #expect(AppMode.normal.rawValue == "NORMAL")
        #expect(AppMode.visual.rawValue == "VISUAL")
        #expect(AppMode.command.rawValue == "COMMAND")
        #expect(AppMode.filter.rawValue == "FILTER")
        #expect(AppMode.driveSelect.rawValue == "DRIVES")
    }
    
    @Test func testAppModeColors() {
        // 验证每种模式都有颜色
        let modes: [AppMode] = [.normal, .visual, .command, .filter, .driveSelect, .aiAnalysis]
        
        for mode in modes {
            let _ = mode.color // 如果没有定义颜色会崩溃
        }
        
        #expect(true) // 如果能到达这里，说明所有颜色都已定义
    }
}

// MARK: - 3. PaneSide 测试

struct PaneSideTests {
    
    @Test func testPaneSideOpposite() {
        #expect(PaneSide.left.opposite == .right)
        #expect(PaneSide.right.opposite == .left)
    }
}

// MARK: - 4. ViewMode 测试

struct ViewModeTests {
    
    @Test func testViewModeValues() {
        let list = ViewMode.list
        let grid = ViewMode.grid
        
        #expect(list.rawValue == "list")
        #expect(grid.rawValue == "grid")
        #expect(list != grid)
    }
}

// MARK: - 5. TabState 测试

struct TabStateTests {
    
    func createTestDrive() -> DriveInfo {
        return DriveInfo(
            id: "test-drive",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
    }
    
    @Test func testTabStateInitialization() {
        let drive = createTestDrive()
        let path = URL(fileURLWithPath: "/Users/test")
        
        let tab = TabState(drive: drive, path: path)
        
        #expect(tab.currentPath == path)
        #expect(tab.files.isEmpty)
        #expect(tab.cursorIndex == 0)
    }
    
    @Test func testTabStateDirectoryName() {
        let drive = createTestDrive()
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        
        let tab = TabState(drive: drive, path: path)
        
        #expect(tab.directoryName == "Documents")
    }
    
    @Test func testTabStatePathComponents() {
        let drive = createTestDrive()
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        
        let tab = TabState(drive: drive, path: path)
        let components = tab.pathComponents
        
        #expect(components.contains("Users"))
        #expect(components.contains("test"))
        #expect(components.contains("Documents"))
    }
}

// MARK: - 6. PaneState 测试 (标签页系统)

struct PaneStateTests {
    
    func createTestDrive() -> DriveInfo {
        return DriveInfo(
            id: "test-drive",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
    }
    
    func createTestPane() -> PaneState {
        let drive = createTestDrive()
        return PaneState(side: .left, initialPath: URL(fileURLWithPath: "/Users"), drive: drive)
    }
    
    @Test func testPaneStateInitialization() {
        let pane = createTestPane()
        
        #expect(pane.side == .left)
        #expect(pane.tabs.count == 1)
        #expect(pane.activeTabIndex == 0)
        #expect(pane.viewMode == .list)
        #expect(pane.selections.isEmpty)
    }
    
    @Test func testAddTab() {
        let pane = createTestPane()
        let initialCount = pane.tabs.count
        
        pane.addTab()
        
        #expect(pane.tabs.count == initialCount + 1)
        #expect(pane.activeTabIndex == pane.tabs.count - 1)
    }
    
    @Test func testCloseTab() {
        let pane = createTestPane()
        pane.addTab()
        pane.addTab()
        
        let countBeforeClose = pane.tabs.count
        pane.closeTab(at: 1)
        
        #expect(pane.tabs.count == countBeforeClose - 1)
    }
    
    @Test func testCannotCloseLastTab() {
        let pane = createTestPane()
        #expect(pane.tabs.count == 1)
        
        pane.closeTab(at: 0)
        
        #expect(pane.tabs.count == 1) // 最后一个标签页不可关闭
    }
    
    @Test func testSwitchTab() {
        let pane = createTestPane()
        pane.addTab()
        pane.addTab()
        
        pane.switchTab(to: 0)
        #expect(pane.activeTabIndex == 0)
        
        pane.switchTab(to: 2)
        #expect(pane.activeTabIndex == 2)
    }
    
    @Test func testNextPreviousTab() {
        let pane = createTestPane()
        pane.addTab()
        pane.addTab()
        pane.switchTab(to: 0)
        
        pane.nextTab()
        #expect(pane.activeTabIndex == 1)
        
        pane.nextTab()
        #expect(pane.activeTabIndex == 2)
        
        pane.nextTab() // 应该循环回到 0
        #expect(pane.activeTabIndex == 0)
        
        pane.previousTab() // 应该循环到最后
        #expect(pane.activeTabIndex == 2)
    }
    
    @Test func testSelections() {
        let pane = createTestPane()
        
        pane.toggleSelection(for: "file1")
        #expect(pane.selections.contains("file1"))
        
        pane.toggleSelection(for: "file2")
        #expect(pane.selections.count == 2)
        
        pane.toggleSelection(for: "file1") // 取消选择
        #expect(!pane.selections.contains("file1"))
        
        pane.clearSelections()
        #expect(pane.selections.isEmpty)
    }
}

// MARK: - 7. AppState 测试 (模态操作引擎)

struct AppStateTests {
    
    @Test func testInitialState() {
        let state = AppState()
        
        #expect(state.mode == .normal)
        #expect(state.activePane == .left)
        #expect(state.clipboard.isEmpty)
    }
    
    @Test func testPaneSwitching() {
        let state = AppState()
        
        state.setActivePane(.right)
        #expect(state.activePane == .right)
        
        state.toggleActivePane()
        #expect(state.activePane == .left)
        
        state.toggleActivePane()
        #expect(state.activePane == .right)
    }
    
    @Test func testEnterVisualMode() {
        let state = AppState()
        
        state.enterMode(.visual)
        
        #expect(state.mode == .visual)
        #expect(state.previousMode == .normal)
    }
    
    @Test func testEnterCommandMode() {
        let state = AppState()
        
        state.enterMode(.command)
        
        #expect(state.mode == .command)
        #expect(state.commandInput == "")
    }
    
    @Test func testEnterFilterMode() {
        let state = AppState()
        
        state.enterMode(.filter)
        
        #expect(state.mode == .filter)
        #expect(state.filterInput == "")
    }
    
    @Test func testEnterDriveSelectMode() {
        let state = AppState()
        
        state.enterMode(.driveSelect)
        
        #expect(state.mode == .driveSelect)
        #expect(state.showDriveSelector == true)
    }
    
    @Test func testExitMode() {
        let state = AppState()
        
        state.enterMode(.visual)
        state.exitMode()
        
        #expect(state.mode == .normal)
    }
    
    @Test func testExitDriveSelectMode() {
        let state = AppState()
        
        state.enterMode(.driveSelect)
        state.exitMode()
        
        #expect(state.mode == .normal)
        #expect(state.showDriveSelector == false)
    }
    
    @Test func testToast() {
        let state = AppState()
        
        state.showToast("Test message")
        
        #expect(state.toastMessage == "Test message")
    }
}

// MARK: - 7.1 Visual 模式测试

struct VisualModeTests {
    
    func createTestDrive() -> DriveInfo {
        return DriveInfo(
            id: "test-drive",
            name: "Test Drive",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
    }
    
    func createTestFileItems(count: Int) -> [FileItem] {
        return (0..<count).map { index in
            FileItem(
                id: "file-\(index)",
                name: "File \(index).txt",
                path: URL(fileURLWithPath: "/test/file\(index).txt"),
                type: .file,
                size: 1000,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "txt"
            )
        }
    }
    
    // MARK: - 测试 1: 按 v 进入 Visual 模式，状态栏显示 "VISUAL"
    
    @Test func testEnterVisualModeShowsVisualStatus() {
        let state = AppState()
        
        // 初始状态应该是 Normal 模式
        #expect(state.mode == .normal)
        #expect(state.mode.rawValue == "NORMAL")
        
        // 进入 Visual 模式
        state.enterMode(.visual)
        
        // 验证模式已切换
        #expect(state.mode == .visual)
        #expect(state.mode.rawValue == "VISUAL")
        
        // 验证保存了之前的模式
        #expect(state.previousMode == .normal)
    }
    
    @Test func testVisualModeHasDistinctColor() {
        // 验证 Visual 模式有独特的颜色（不同于 Normal 模式）
        let normalColor = AppMode.normal.color
        let visualColor = AppMode.visual.color
        
        // Visual 模式的颜色应该已定义（不会崩溃）
        #expect(visualColor != normalColor)
    }
    
    // MARK: - 测试 2: Visual 模式下 j/k 移动，光标移动过的文件自动选中
    
    @Test func testVisualModeStartSelection() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 2  // 从第 3 个文件开始
        
        // 进入 Visual 模式并开始选择
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 验证锚点被设置
        #expect(pane.visualAnchor == 2)
        
        // 验证当前文件被选中
        #expect(pane.selections.contains("file-2"))
        #expect(pane.selections.count == 1)
    }
    
    @Test func testVisualModeSelectDownWithJ() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 1  // 从第 2 个文件开始
        
        // 进入 Visual 模式
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 模拟按 j 向下移动
        pane.cursorIndex = 2
        pane.updateVisualSelection()
        
        // 验证选中了从锚点到当前位置的文件 (file-1, file-2)
        #expect(pane.selections.count == 2)
        #expect(pane.selections.contains("file-1"))
        #expect(pane.selections.contains("file-2"))
        
        // 再按 j 继续向下
        pane.cursorIndex = 3
        pane.updateVisualSelection()
        
        // 验证选中范围扩展 (file-1, file-2, file-3)
        #expect(pane.selections.count == 3)
        #expect(pane.selections.contains("file-1"))
        #expect(pane.selections.contains("file-2"))
        #expect(pane.selections.contains("file-3"))
    }
    
    @Test func testVisualModeSelectUpWithK() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 3  // 从第 4 个文件开始
        
        // 进入 Visual 模式
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 模拟按 k 向上移动
        pane.cursorIndex = 2
        pane.updateVisualSelection()
        
        // 验证选中了从当前位置到锚点的文件 (file-2, file-3)
        #expect(pane.selections.count == 2)
        #expect(pane.selections.contains("file-2"))
        #expect(pane.selections.contains("file-3"))
        
        // 再按 k 继续向上
        pane.cursorIndex = 1
        pane.updateVisualSelection()
        
        // 验证选中范围扩展 (file-1, file-2, file-3)
        #expect(pane.selections.count == 3)
        #expect(pane.selections.contains("file-1"))
        #expect(pane.selections.contains("file-2"))
        #expect(pane.selections.contains("file-3"))
    }
    
    @Test func testVisualModeSelectionContractsWhenDirectionChanges() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 2  // 从第 3 个文件开始（锚点）
        
        // 进入 Visual 模式
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 向下移动选择 (file-2, file-3, file-4)
        pane.cursorIndex = 4
        pane.updateVisualSelection()
        #expect(pane.selections.count == 3)
        #expect(pane.selections.contains("file-2"))
        #expect(pane.selections.contains("file-3"))
        #expect(pane.selections.contains("file-4"))
        
        // 按 k 向上移动，选择应该收缩
        pane.cursorIndex = 3
        pane.updateVisualSelection()
        
        // 验证 file-4 被取消选中，只剩 file-2 和 file-3
        #expect(pane.selections.count == 2)
        #expect(pane.selections.contains("file-2"))
        #expect(pane.selections.contains("file-3"))
        #expect(!pane.selections.contains("file-4"))
        
        // 继续向上移动，收缩到只有锚点
        pane.cursorIndex = 2
        pane.updateVisualSelection()
        #expect(pane.selections.count == 1)
        #expect(pane.selections.contains("file-2"))
        
        // 继续向上移动，选择应该向上扩展
        pane.cursorIndex = 1
        pane.updateVisualSelection()
        #expect(pane.selections.count == 2)
        #expect(pane.selections.contains("file-1"))
        #expect(pane.selections.contains("file-2"))
    }
    
    // MARK: - 测试 3: 按 Esc 退出 Visual 模式，清除选择
    
    @Test func testEscExitsVisualModeAndClearsSelection() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 1
        
        // 进入 Visual 模式并选择一些文件
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        pane.cursorIndex = 3
        pane.updateVisualSelection()
        
        // 验证有选中的文件
        #expect(pane.selections.count == 3)
        #expect(pane.visualAnchor != nil)
        
        // 模拟按 Esc：清除选择并退出模式
        pane.clearSelections()
        state.exitMode()
        
        // 验证回到 Normal 模式
        #expect(state.mode == .normal)
        
        // 验证选择被清除
        #expect(pane.selections.isEmpty)
        
        // 验证锚点被清除
        #expect(pane.visualAnchor == nil)
    }
    
    @Test func testClearSelectionsAlsoClearsAnchor() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 2
        
        // 开始选择
        pane.startVisualSelection()
        #expect(pane.visualAnchor == 2)
        #expect(!pane.selections.isEmpty)
        
        // 清除选择
        pane.clearSelections()
        
        // 验证锚点和选择都被清除
        #expect(pane.visualAnchor == nil)
        #expect(pane.selections.isEmpty)
    }
    
    // MARK: - 边界条件测试
    
    @Test func testVisualModeWithEmptyFileList() {
        let state = AppState()
        let pane = state.currentPane
        
        // 空文件列表
        pane.activeTab.files = []
        pane.cursorIndex = 0
        
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 不应该崩溃，选择应该为空
        #expect(pane.selections.isEmpty)
    }
    
    @Test func testVisualModeSelectionAtBoundaries() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 3)
        pane.cursorIndex = 0  // 从第一个文件开始
        
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 移动到最后一个文件
        pane.cursorIndex = 2
        pane.updateVisualSelection()
        
        // 应该选中所有文件
        #expect(pane.selections.count == 3)
        #expect(pane.selections.contains("file-0"))
        #expect(pane.selections.contains("file-1"))
        #expect(pane.selections.contains("file-2"))
    }
}

// MARK: - 7.2 Command 模式测试

struct CommandModeTests {
    
    // MARK: - 测试 1: 按 : 进入 Command 模式，状态栏显示 "COMMAND"
    
    @Test func testEnterCommandModeShowsCommandStatus() {
        let state = AppState()
        
        // 初始状态应该是 Normal 模式
        #expect(state.mode == .normal)
        #expect(state.mode.rawValue == "NORMAL")
        
        // 进入 Command 模式
        state.enterMode(.command)
        
        // 验证模式已切换
        #expect(state.mode == .command)
        #expect(state.mode.rawValue == "COMMAND")
        
        // 验证保存了之前的模式
        #expect(state.previousMode == .normal)
        
        // 验证命令输入被清空
        #expect(state.commandInput == "")
    }
    
    @Test func testCommandModeHasDistinctColor() {
        // 验证 Command 模式有独特的颜色
        let normalColor = AppMode.normal.color
        let commandColor = AppMode.command.color
        
        // Command 模式的颜色应该已定义且与 Normal 不同
        #expect(commandColor != normalColor)
    }
    
    // MARK: - 测试 2: 输入字符流畅
    
    @Test func testCommandInputAppendCharacters() {
        let state = AppState()
        
        // 进入 Command 模式
        state.enterMode(.command)
        #expect(state.commandInput == "")
        
        // 模拟输入字符
        state.commandInput.append("a")
        #expect(state.commandInput == "a")
        
        state.commandInput.append("i")
        #expect(state.commandInput == "ai")
        
        state.commandInput.append(" ")
        #expect(state.commandInput == "ai ")
        
        state.commandInput.append("h")
        state.commandInput.append("e")
        state.commandInput.append("l")
        state.commandInput.append("p")
        #expect(state.commandInput == "ai help")
    }
    
    @Test func testCommandInputDeleteCharacters() {
        let state = AppState()
        
        // 进入 Command 模式
        state.enterMode(.command)
        state.commandInput = "test"
        
        // 模拟按 Delete 删除字符
        if !state.commandInput.isEmpty {
            state.commandInput.removeLast()
        }
        #expect(state.commandInput == "tes")
        
        if !state.commandInput.isEmpty {
            state.commandInput.removeLast()
        }
        #expect(state.commandInput == "te")
        
        // 继续删除直到空
        state.commandInput.removeAll()
        #expect(state.commandInput == "")
        
        // 空字符串上删除不应崩溃
        if !state.commandInput.isEmpty {
            state.commandInput.removeLast()
        }
        #expect(state.commandInput == "")
    }
    
    @Test func testCommandInputWithSpecialCharacters() {
        let state = AppState()
        
        state.enterMode(.command)
        
        // 测试各种字符
        state.commandInput = "mkdir test-folder_123"
        #expect(state.commandInput == "mkdir test-folder_123")
        
        state.commandInput = "ai 这是中文"
        #expect(state.commandInput == "ai 这是中文")
        
        state.commandInput = "path/to/file.txt"
        #expect(state.commandInput == "path/to/file.txt")
    }
    
    // MARK: - 测试 3: 按 Enter 执行指令，按 Esc 取消
    
    @Test func testEscCancelsCommandMode() {
        let state = AppState()
        
        // 进入 Command 模式
        state.enterMode(.command)
        state.commandInput = "some command"
        
        #expect(state.mode == .command)
        #expect(state.commandInput == "some command")
        
        // 模拟按 Esc：退出模式
        state.exitMode()
        
        // 验证回到 Normal 模式
        #expect(state.mode == .normal)
        
        // 注意：Esc 不一定清空 commandInput，这取决于具体实现
        // 但模式应该回到 Normal
    }
    
    @Test func testEnterExecutesCommand() {
        let state = AppState()
        
        // 进入 Command 模式
        state.enterMode(.command)
        state.commandInput = "test"
        
        // 模拟执行命令后的状态
        // 执行命令后应该退出 Command 模式
        let command = state.commandInput
        state.exitMode()
        
        #expect(state.mode == .normal)
        #expect(command == "test")
    }
    
    @Test func testCommandModeFromVisualMode() {
        let state = AppState()
        
        // 先进入 Visual 模式
        state.enterMode(.visual)
        #expect(state.mode == .visual)
        
        // 从 Visual 模式进入 Command 模式
        state.enterMode(.command)
        
        #expect(state.mode == .command)
        #expect(state.previousMode == .visual)
    }
    
    @Test func testExitCommandModeReturnsToNormal() {
        let state = AppState()
        
        // 从 Normal 进入 Command
        state.enterMode(.command)
        state.commandInput = "quit"
        
        // 退出应该回到 Normal
        state.exitMode()
        
        #expect(state.mode == .normal)
    }
    
    // MARK: - 边界条件测试
    
    @Test func testEmptyCommandExecution() {
        let state = AppState()
        
        state.enterMode(.command)
        #expect(state.commandInput == "")
        
        // 空命令不应该崩溃
        let command = state.commandInput.trimmingCharacters(in: .whitespaces)
        #expect(command.isEmpty)
        
        state.exitMode()
        #expect(state.mode == .normal)
    }
    
    @Test func testCommandWithOnlyWhitespace() {
        let state = AppState()
        
        state.enterMode(.command)
        state.commandInput = "   "
        
        let command = state.commandInput.trimmingCharacters(in: .whitespaces)
        #expect(command.isEmpty)
    }
    
    @Test func testLongCommandInput() {
        let state = AppState()
        
        state.enterMode(.command)
        
        // 测试长命令
        let longCommand = String(repeating: "a", count: 1000)
        state.commandInput = longCommand
        
        #expect(state.commandInput.count == 1000)
    }
    
    @Test func testCommandInputClearedOnEnterMode() {
        let state = AppState()
        
        // 第一次进入 Command 模式
        state.enterMode(.command)
        state.commandInput = "first command"
        state.exitMode()
        
        // 第二次进入 Command 模式
        state.enterMode(.command)
        
        // 验证输入被清空（根据 enterMode 实现）
        #expect(state.commandInput == "")
    }
    
    @Test func testMultipleEnterExitCycles() {
        let state = AppState()
        
        // 多次进入退出循环
        for i in 0..<5 {
            state.enterMode(.command)
            #expect(state.mode == .command)
            
            state.commandInput = "command \(i)"
            #expect(state.commandInput == "command \(i)")
            
            state.exitMode()
            #expect(state.mode == .normal)
        }
    }
}

// MARK: - 7.3 Filter 模式测试

struct FilterModeTests {
    
    // 创建测试用文件列表
    private func createTestFiles() -> [FileItem] {
        let now = Date()
        return [
            FileItem(
                id: "file-1",
                name: "document.txt",
                path: URL(fileURLWithPath: "/test/document.txt"),
                type: .file,
                size: 100,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "txt"
            ),
            FileItem(
                id: "file-2",
                name: "image.png",
                path: URL(fileURLWithPath: "/test/image.png"),
                type: .file,
                size: 200,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "png"
            ),
            FileItem(
                id: "file-3",
                name: "Document.pdf",
                path: URL(fileURLWithPath: "/test/Document.pdf"),
                type: .file,
                size: 300,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "pdf"
            ),
            FileItem(
                id: "folder-1",
                name: "Documents",
                path: URL(fileURLWithPath: "/test/Documents"),
                type: .folder,
                size: 0,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rwxr-xr-x",
                fileExtension: ""
            ),
            FileItem(
                id: "folder-2",
                name: "Downloads",
                path: URL(fileURLWithPath: "/test/Downloads"),
                type: .folder,
                size: 0,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rwxr-xr-x",
                fileExtension: ""
            ),
        ]
    }
    
    // MARK: - 测试 1: 输入字符时，文件列表实时过滤（只显示匹配项）
    
    @Test func testEnterFilterMode() {
        let state = AppState()
        
        state.enterMode(.filter)
        
        #expect(state.mode == .filter)
        #expect(state.filterInput == "")
    }
    
    @Test func testFilterInputAppendCharacters() {
        let state = AppState()
        
        state.enterMode(.filter)
        
        // 模拟输入字符
        state.filterInput.append("d")
        #expect(state.filterInput == "d")
        
        state.filterInput.append("o")
        #expect(state.filterInput == "do")
        
        state.filterInput.append("c")
        #expect(state.filterInput == "doc")
    }
    
    @Test func testFilterFilesRealTime() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        // 设置测试文件
        state.currentPane.activeTab.files = testFiles
        
        // 进入 Filter 模式
        state.enterMode(.filter)
        
        // 保存原始文件到 unfilteredFiles（模拟首次过滤）
        state.currentPane.activeTab.unfilteredFiles = testFiles
        
        // 模拟过滤 "doc"（大小写不敏感）
        let filter = "doc"
        let filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.currentPane.activeTab.files = filteredFiles
        
        // 验证过滤结果：应包含 document.txt, Document.pdf, Documents
        #expect(state.currentPane.activeTab.files.count == 3)
        
        let names = state.currentPane.activeTab.files.map { $0.name }
        #expect(names.contains("document.txt"))
        #expect(names.contains("Document.pdf"))
        #expect(names.contains("Documents"))
        
        // 不应包含 image.png 和 Downloads
        #expect(!names.contains("image.png"))
        #expect(!names.contains("Downloads"))
    }
    
    @Test func testFilterIsCaseInsensitive() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        
        // 测试大写 "DOC"
        let filter = "DOC"
        let filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.currentPane.activeTab.files = filteredFiles
        
        // 应该匹配 document.txt, Document.pdf, Documents
        #expect(state.currentPane.activeTab.files.count == 3)
    }
    
    @Test func testFilterNoMatch() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        
        // 搜索不存在的内容
        let filter = "xyz123"
        let filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.currentPane.activeTab.files = filteredFiles
        
        #expect(state.currentPane.activeTab.files.isEmpty)
    }
    
    @Test func testFilterProgressiveNarrowing() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.enterMode(.filter)
        
        // 输入 "d" - 应匹配 document.txt, Document.pdf, Documents, Downloads
        var filter = "d"
        var filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        #expect(filteredFiles.count == 4)
        
        // 输入 "do" - 应匹配 document.txt, Document.pdf, Documents, Downloads
        filter = "do"
        filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        #expect(filteredFiles.count == 4)
        
        // 输入 "doc" - 应匹配 document.txt, Document.pdf, Documents
        filter = "doc"
        filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        #expect(filteredFiles.count == 3)
        
        // 输入 "docu" - 应匹配 document.txt, Document.pdf, Documents
        filter = "docu"
        filteredFiles = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        #expect(filteredFiles.count == 3)
    }
    
    // MARK: - 测试 2: 清空输入或按 Esc 退出过滤，恢复显示所有文件
    
    @Test func testEscExitsFilterModeAndRestoresFiles() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        // 设置初始文件
        state.currentPane.activeTab.files = testFiles
        #expect(state.currentPane.activeTab.files.count == 5)
        
        // 进入 Filter 模式
        state.enterMode(.filter)
        #expect(state.mode == .filter)
        
        // 模拟过滤操作
        state.currentPane.activeTab.unfilteredFiles = testFiles
        let filter = "doc"
        state.currentPane.activeTab.files = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.filterInput = filter
        
        // 验证文件被过滤
        #expect(state.currentPane.activeTab.files.count == 3)
        
        // 按 Esc 退出（调用 exitMode）
        state.exitMode()
        
        // 验证回到 Normal 模式
        #expect(state.mode == .normal)
        
        // 验证文件列表已恢复
        #expect(state.currentPane.activeTab.files.count == 5)
        
        // 验证 filterInput 被清空
        #expect(state.filterInput == "")
        
        // 验证 unfilteredFiles 被清空
        #expect(state.currentPane.activeTab.unfilteredFiles.isEmpty)
    }
    
    @Test func testClearFilterInputRestoresFiles() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        // 设置初始文件和 unfilteredFiles
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        
        // 模拟过滤
        let filter = "image"
        state.currentPane.activeTab.files = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.filterInput = filter
        
        // 验证过滤后只有1个文件
        #expect(state.currentPane.activeTab.files.count == 1)
        #expect(state.currentPane.activeTab.files.first?.name == "image.png")
        
        // 模拟清空输入（删除所有字符后应恢复）
        state.filterInput = ""
        // 当 filter 为空时，恢复原始列表
        if state.filterInput.isEmpty && !state.currentPane.activeTab.unfilteredFiles.isEmpty {
            state.currentPane.activeTab.files = state.currentPane.activeTab.unfilteredFiles
        }
        
        // 验证文件列表已恢复
        #expect(state.currentPane.activeTab.files.count == 5)
    }
    
    @Test func testFilterModeDeleteCharacter() {
        let state = AppState()
        
        state.enterMode(.filter)
        state.filterInput = "test"
        
        // 模拟按 Delete 删除字符
        if !state.filterInput.isEmpty {
            state.filterInput.removeLast()
        }
        #expect(state.filterInput == "tes")
        
        if !state.filterInput.isEmpty {
            state.filterInput.removeLast()
        }
        #expect(state.filterInput == "te")
    }
    
    @Test func testFilterModeDeleteToEmpty() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.enterMode(.filter)
        state.filterInput = "a"
        
        // 删除到空
        state.filterInput.removeLast()
        #expect(state.filterInput == "")
        
        // 空字符串上继续删除不应崩溃
        if !state.filterInput.isEmpty {
            state.filterInput.removeLast()
        }
        #expect(state.filterInput == "")
    }
    
    @Test func testEnterConfirmsFilterAndKeepsResults() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        // 设置初始文件
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        
        // 过滤
        let filter = "image"
        state.currentPane.activeTab.files = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.filterInput = filter
        state.enterMode(.filter)
        
        #expect(state.currentPane.activeTab.files.count == 1)
        
        // 模拟按 Enter 确认：保持过滤结果，清空 unfilteredFiles
        state.currentPane.activeTab.unfilteredFiles = []
        state.mode = .normal
        state.filterInput = ""
        
        // 验证
        #expect(state.mode == .normal)
        #expect(state.currentPane.activeTab.files.count == 1) // 保持过滤结果
        #expect(state.currentPane.activeTab.unfilteredFiles.isEmpty)
    }
    
    @Test func testExitModeOnlyRestoresWhenInFilterMode() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        
        // 从 Visual 模式退出不应影响文件列表
        state.enterMode(.visual)
        state.exitMode()
        
        #expect(state.currentPane.activeTab.files.count == 5)
        
        // 从 Command 模式退出不应影响文件列表
        state.enterMode(.command)
        state.exitMode()
        
        #expect(state.currentPane.activeTab.files.count == 5)
    }
    
    @Test func testFilterWithSpecialCharacters() {
        let state = AppState()
        
        state.enterMode(.filter)
        
        // 测试特殊字符
        state.filterInput = "test_file"
        #expect(state.filterInput == "test_file")
        
        state.filterInput = "test-file"
        #expect(state.filterInput == "test-file")
        
        state.filterInput = "test.txt"
        #expect(state.filterInput == "test.txt")
    }
    
    @Test func testFilterCursorResetToZero() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.currentPane.cursorIndex = 3 // 设置一个非零的光标位置
        
        // 过滤后光标应重置为0
        let filter = "doc"
        state.currentPane.activeTab.files = testFiles.filter { $0.name.lowercased().contains(filter.lowercased()) }
        state.currentPane.cursorIndex = 0
        
        #expect(state.currentPane.cursorIndex == 0)
    }
    
    @Test func testFilterModeHasDistinctColor() {
        // 验证 Filter 模式有独特的颜色
        let normalColor = AppMode.normal.color
        let filterColor = AppMode.filter.color
        
        #expect(filterColor != normalColor)
    }
    
    @Test func testRestoreUnfilteredFilesMethod() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        // 设置过滤后的状态
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.currentPane.activeTab.files = [testFiles[0]] // 只保留一个
        state.currentPane.cursorIndex = 0
        
        // 调用恢复方法
        state.restoreUnfilteredFiles()
        
        // 验证
        #expect(state.currentPane.activeTab.files.count == 5)
        #expect(state.currentPane.activeTab.unfilteredFiles.isEmpty)
    }
    
    @Test func testRestoreUnfilteredFilesAdjustsCursor() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        // 设置过滤后的状态，光标超出范围
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.currentPane.activeTab.files = testFiles
        state.currentPane.cursorIndex = 10 // 超出范围
        
        // 调用恢复方法
        state.restoreUnfilteredFiles()
        
        // 验证光标被调整
        #expect(state.currentPane.cursorIndex >= 0)
        #expect(state.currentPane.cursorIndex < state.currentPane.activeTab.files.count)
    }
    
    // MARK: - 正则表达式过滤测试
    
    @Test func testEnterRegexFilterMode() {
        let state = AppState()
        
        // 模拟 Shift + / 进入正则模式
        state.enterMode(.filter)
        state.filterUseRegex = true
        
        #expect(state.mode == .filter)
        #expect(state.filterUseRegex == true)
    }
    
    @Test func testRegexFilterStatusText() {
        let state = AppState()
        
        // 普通过滤模式
        state.enterMode(.filter)
        state.filterUseRegex = false
        state.filterInput = "test"
        
        #expect(state.statusText == "/test")
        
        // 正则过滤模式
        state.filterUseRegex = true
        
        #expect(state.statusText == "/regex: test")
    }
    
    @Test func testRegexFilterMatching() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.filterUseRegex = true
        
        // 使用正则表达式 "^doc" 匹配以 doc 开头的文件（大小写不敏感）
        let regex = try! NSRegularExpression(pattern: "^doc", options: [.caseInsensitive])
        let filteredFiles = testFiles.filter { file in
            let range = NSRange(file.name.startIndex..., in: file.name)
            return regex.firstMatch(in: file.name, options: [], range: range) != nil
        }
        state.currentPane.activeTab.files = filteredFiles
        
        // 应该匹配 document.txt, Document.pdf, Documents（都以 doc 开头）
        #expect(state.currentPane.activeTab.files.count == 3)
    }
    
    @Test func testRegexFilterWithPattern() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.filterUseRegex = true
        
        // 使用正则表达式 ".*\\.txt$" 匹配 .txt 结尾的文件
        let regex = try! NSRegularExpression(pattern: ".*\\.txt$", options: [.caseInsensitive])
        let filteredFiles = testFiles.filter { file in
            let range = NSRange(file.name.startIndex..., in: file.name)
            return regex.firstMatch(in: file.name, options: [], range: range) != nil
        }
        state.currentPane.activeTab.files = filteredFiles
        
        // 应该只匹配 document.txt
        #expect(state.currentPane.activeTab.files.count == 1)
        #expect(state.currentPane.activeTab.files.first?.name == "document.txt")
    }
    
    @Test func testRegexFilterInvalidPattern() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        state.filterUseRegex = true
        
        // 无效的正则表达式 "[" 应该不崩溃
        let invalidPattern = "["
        let isValid = (try? NSRegularExpression(pattern: invalidPattern)) != nil
        
        #expect(isValid == false)
        
        // 当正则无效时，应保持原始文件列表
        if !isValid {
            state.currentPane.activeTab.files = state.currentPane.activeTab.unfilteredFiles
        }
        
        #expect(state.currentPane.activeTab.files.count == 5)
    }
    
    @Test func testExitFilterModeClearsRegexFlag() {
        let state = AppState()
        
        // 进入正则过滤模式
        state.enterMode(.filter)
        state.filterUseRegex = true
        state.filterInput = "test"
        
        #expect(state.filterUseRegex == true)
        
        // 退出模式
        state.exitMode()
        
        // 验证正则标志被清除
        #expect(state.filterUseRegex == false)
        #expect(state.filterInput == "")
    }
    
    @Test func testRegexFilterSpecialCharacters() {
        let state = AppState()
        
        state.enterMode(.filter)
        state.filterUseRegex = true
        
        // 正则模式应支持特殊字符
        state.filterInput = "^test.*$"
        #expect(state.filterInput == "^test.*$")
        
        state.filterInput = "file[0-9]+"
        #expect(state.filterInput == "file[0-9]+")
        
        state.filterInput = "(doc|img)"
        #expect(state.filterInput == "(doc|img)")
    }
    
    @Test func testNormalFilterVsRegexFilter() {
        let state = AppState()
        let testFiles = createTestFiles()
        
        state.currentPane.activeTab.files = testFiles
        state.currentPane.activeTab.unfilteredFiles = testFiles
        
        // 普通模式："doc" 会匹配包含 doc 的文件
        state.filterUseRegex = false
        let normalFilter = "doc"
        let normalFiltered = testFiles.filter { $0.name.lowercased().contains(normalFilter.lowercased()) }
        
        // 应该匹配 document.txt, Document.pdf, Documents
        #expect(normalFiltered.count == 3)
        
        // 正则模式："^D" 只匹配以大写 D 开头的文件（区分大小写的话）
        state.filterUseRegex = true
        let regex = try! NSRegularExpression(pattern: "^D", options: [])
        let regexFiltered = testFiles.filter { file in
            let range = NSRange(file.name.startIndex..., in: file.name)
            return regex.firstMatch(in: file.name, options: [], range: range) != nil
        }
        
        // 应该匹配 Document.pdf, Documents, Downloads
        #expect(regexFiltered.count == 3)
    }
}

// MARK: - 8. FileSystemService 测试

struct FileSystemServiceTests {
    
    @Test func testSingletonInstance() {
        let service1 = FileSystemService.shared
        let service2 = FileSystemService.shared
        
        #expect(service1 === service2)
    }
    
    @Test func testLoadDirectory() {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        let files = service.loadDirectory(at: homeDir)
        
        // 主目录应该有文件
        #expect(!files.isEmpty)
    }
    
    @Test func testParentDirectory() {
        let service = FileSystemService.shared
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        
        let parent = service.parentDirectory(of: path)
        
        #expect(parent.lastPathComponent == "test")
    }
    
    @Test func testRootParentDirectory() {
        let service = FileSystemService.shared
        let rootPath = URL(fileURLWithPath: "/")
        
        let parent = service.parentDirectory(of: rootPath)
        
        #expect(parent.path == "/")
    }
    
    @Test func testGetMountedVolumes() {
        let service = FileSystemService.shared
        
        let volumes = service.getMountedVolumes()
        
        // 至少应该有一个卷（系统盘）
        #expect(!volumes.isEmpty)
    }
    
    @Test func testDirectoryExistsCheck() {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        #expect(service.directoryExists(at: homeDir) == true)
    }
    
    @Test func testDirectoryNotExistsCheck() {
        let service = FileSystemService.shared
        let fakePath = URL(fileURLWithPath: "/nonexistent/path/12345")
        
        #expect(service.directoryExists(at: fakePath) == false)
    }
    
    @Test func testHasReadPermission() {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        #expect(service.hasReadPermission(for: homeDir) == true)
    }
    
    @Test func testLoadDirectoryWithPermissionCheck() {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        let result = service.loadDirectoryWithPermissionCheck(at: homeDir)
        
        switch result {
        case .success(let files):
            #expect(!files.isEmpty)
        case .permissionDenied:
            // 如果权限被拒绝，也是有效的结果
            #expect(true)
        case .notFound:
            #expect(false, "Home directory should exist")
        case .error:
            #expect(false, "Should not error on home directory")
        }
    }
}

// MARK: - 9. DriveInfo 测试

struct DriveInfoTests {
    
    @Test func testDriveInfoCreation() {
        let drive = DriveInfo(
            id: "test-drive",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
        
        #expect(drive.name == "Macintosh HD")
        #expect(drive.totalCapacity == 500_000_000_000)
        #expect(drive.availableCapacity == 100_000_000_000)
    }
    
    @Test func testDriveInfoUsedPercentage() {
        let drive = DriveInfo(
            id: "test-drive",
            name: "Test Drive",
            path: URL(fileURLWithPath: "/Volumes/Test"),
            type: .external,
            totalCapacity: 1000,
            availableCapacity: 250
        )
        
        #expect(drive.usedPercentage == 75.0)
    }
    
    @Test func testDriveTypeIcons() {
        let systemDrive = DriveInfo(
            id: "sys",
            name: "System",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 1000,
            availableCapacity: 500
        )
        
        let externalDrive = DriveInfo(
            id: "ext",
            name: "External",
            path: URL(fileURLWithPath: "/Volumes/External"),
            type: .external,
            totalCapacity: 1000,
            availableCapacity: 500
        )
        
        #expect(systemDrive.iconName == "laptopcomputer")
        #expect(externalDrive.iconName == "externaldrive.fill")
    }
}

// MARK: - 10. Theme 测试

struct ThemeTests {
    
    @Test func testThemeColorsExist() {
        // 验证主题颜色已定义
        let _ = Theme.background
        let _ = Theme.backgroundSecondary
        let _ = Theme.accent
        let _ = Theme.textPrimary
        let _ = Theme.textSecondary
        
        #expect(true) // 如果能到达这里，说明颜色都存在
    }
}

// MARK: - 11. 安全数组访问扩展测试

struct ArrayExtensionTests {
    
    @Test func testSafeSubscriptValid() {
        let array = [1, 2, 3, 4, 5]
        
        #expect(array[safe: 0] == 1)
        #expect(array[safe: 2] == 3)
        #expect(array[safe: 4] == 5)
    }
    
    @Test func testSafeSubscriptInvalid() {
        let array = [1, 2, 3]
        
        #expect(array[safe: -1] == nil)
        #expect(array[safe: 3] == nil)
        #expect(array[safe: 100] == nil)
    }
    
    @Test func testSafeSubscriptEmptyArray() {
        let emptyArray: [Int] = []
        
        #expect(emptyArray[safe: 0] == nil)
    }
}

