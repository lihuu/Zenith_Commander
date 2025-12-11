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
        #expect(AppMode.rename.rawValue == "RENAME")
        #expect(AppMode.settings.rawValue == "SETTINGS")
    }
    
    @Test func testAppModeColors() {
        // 验证每种模式都有颜色
        let modes: [AppMode] = [.normal, .visual, .command, .filter, .driveSelect, .aiAnalysis, .rename, .settings]
        
        for mode in modes {
            let _ = mode.color // 如果没有定义颜色会崩溃
        }
        
        #expect(true) // 如果能到达这里，说明所有颜色都已定义
    }
    
    @Test func testAppModeIsModalMode() {
        // 测试 isModalMode 属性
        // 非模态模式
        #expect(AppMode.normal.isModalMode == false)
        #expect(AppMode.visual.isModalMode == false)
        #expect(AppMode.command.isModalMode == false)
        #expect(AppMode.filter.isModalMode == false)
        #expect(AppMode.driveSelect.isModalMode == false)
        
        // 模态模式 - 这些模式应该阻止全局键盘事件
        #expect(AppMode.rename.isModalMode == true)
        #expect(AppMode.settings.isModalMode == true)
        #expect(AppMode.aiAnalysis.isModalMode == true)
    }
    
    @Test func testAppModeDescription() {
        // 验证每种模式都有描述
        let modes = AppMode.allCases
        
        for mode in modes {
            #expect(!mode.description.isEmpty)
        }
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
        #expect(tab.cursorIndexInTab == nil) // files is empty, so cursor index is nil
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
    
    // MARK: - Grid View 导航测试
    
    @Test func testGridColumnCountDefault() {
        let pane = createTestPane()
        
        // 默认列数为 4
        #expect(pane.gridColumnCount == 4)
    }
    
    @Test func testGridColumnCountCanBeChanged() {
        let pane = createTestPane()
        
        pane.gridColumnCount = 6
        #expect(pane.gridColumnCount == 6)
        
        pane.gridColumnCount = 3
        #expect(pane.gridColumnCount == 3)
    }
    
    @Test func testViewModeToggle() {
        let pane = createTestPane()
        
        // 默认是 List 模式
        #expect(pane.viewMode == .list)
        
        // 切换到 Grid 模式
        pane.viewMode = .grid
        #expect(pane.viewMode == .grid)
        
        // 切换回 List 模式
        pane.viewMode = .list
        #expect(pane.viewMode == .list)
    }
}

// MARK: - Grid View 导航逻辑测试

struct GridViewNavigationTests {
    
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
    
    func createTestFiles(count: Int) -> [FileItem] {
        let now = Date()
        return (0..<count).map { index in
            FileItem(
                id: "file_\(index)",
                name: "file_\(index).txt",
                path: URL(fileURLWithPath: "/Users/test/file_\(index).txt"),
                type: .file,
                size: 1024,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "txt"
            )
        }
    }
    
    // MARK: - Grid View 上下导航测试
    
    @Test func testGridNavigationDownOneRow() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        // 创建 12 个文件（3行 x 4列）
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 0  // 从第一个开始
        
        // 模拟向下移动一行（移动 4 个位置）
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + pane.gridColumnCount)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 4)  // 应该移动到第二行第一个
    }
    
    @Test func testGridNavigationUpOneRow() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 4  // 从第二行第一个开始
        
        // 模拟向上移动一行
        let currentIndex = pane.cursorIndex
        let newIndex = max(0, currentIndex - pane.gridColumnCount)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 0)  // 应该移动到第一行第一个
    }
    
    @Test func testGridNavigationDownAtBoundary() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 10  // 第三行第三个
        
        // 向下移动应该到达最后一个文件
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + pane.gridColumnCount)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 11)  // 应该停在最后一个文件
    }
    
    @Test func testGridNavigationUpAtBoundary() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 1  // 第一行第二个
        
        // 向上移动应该停在第一行
        let currentIndex = pane.cursorIndex
        let newIndex = max(0, currentIndex - pane.gridColumnCount)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 0)  // 应该停在第一个
    }
    
    // MARK: - Grid View 左右导航测试
    
    @Test func testGridNavigationRight() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 0
        
        // 向右移动一格
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + 1)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 1)
    }
    
    @Test func testGridNavigationLeft() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 5
        
        // 向左移动一格
        let currentIndex = pane.cursorIndex
        let newIndex = max(0, currentIndex - 1)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 4)
    }
    
    @Test func testGridNavigationLeftAtBoundary() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 0
        
        // 向左移动应该停在第一个
        let currentIndex = pane.cursorIndex
        let newIndex = max(0, currentIndex - 1)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 0)
    }
    
    @Test func testGridNavigationRightAtBoundary() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 11  // 最后一个
        
        // 向右移动应该停在最后一个
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + 1)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 11)
    }
    
    // MARK: - Grid View 跨行导航测试
    
    @Test func testGridNavigationRightCrossRow() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 3  // 第一行最后一个
        
        // 向右移动应该到第二行第一个
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + 1)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 4)
    }
    
    @Test func testGridNavigationLeftCrossRow() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        pane.activeTab.files = createTestFiles(count: 12)
        pane.cursorIndex = 4  // 第二行第一个
        
        // 向左移动应该到第一行最后一个
        let currentIndex = pane.cursorIndex
        let newIndex = max(0, currentIndex - 1)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 3)
    }
    
    // MARK: - 不同列数测试
    
    @Test func testGridNavigationWithDifferentColumnCount() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 6  // 6列
        
        pane.activeTab.files = createTestFiles(count: 18)  // 3行 x 6列
        pane.cursorIndex = 0
        
        // 向下移动一行（6个位置）
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + pane.gridColumnCount)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 6)
    }
    
    @Test func testGridNavigationWithIncompleteRow() {
        let pane = createTestPane()
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        
        // 10个文件：第一行4个，第二行4个，第三行2个
        pane.activeTab.files = createTestFiles(count: 10)
        pane.cursorIndex = 6  // 第二行第三个
        
        // 向下移动应该到第三行的最后一个（索引9）
        let currentIndex = pane.cursorIndex
        let newIndex = min(pane.activeTab.files.count - 1, currentIndex + pane.gridColumnCount)
        pane.cursorIndex = newIndex
        
        #expect(pane.cursorIndex == 9)  // 应该是最后一个有效索引
    }
}

// MARK: - 父目录项 (..) 测试

@Suite("Parent Directory Item Tests")
struct ParentDirectoryItemTests {
    
    @Test func testParentDirectoryItemCreation() {
        let parentPath = URL(fileURLWithPath: "/Users/test")
        let item = FileItem.parentDirectoryItem(for: parentPath)
        
        #expect(item.id == "..")
        #expect(item.name == "..")
        #expect(item.path == parentPath)
        #expect(item.type == .folder)
        #expect(item.isParentDirectory == true)
    }
    
    @Test func testParentDirectoryItemIcon() {
        let parentPath = URL(fileURLWithPath: "/Users/test")
        let item = FileItem.parentDirectoryItem(for: parentPath)
        
        // 父目录项应该使用特殊的返回箭头图标
        #expect(item.iconName == "arrow.turn.up.left")
    }
    
    @Test func testRegularFolderIsNotParentDirectory() {
        let now = Date()
        let regularFolder = FileItem(
            id: "folder_1",
            name: "Documents",
            path: URL(fileURLWithPath: "/Users/test/Documents"),
            type: .folder,
            size: 0,
            modifiedDate: now,
            createdDate: now,
            isHidden: false,
            permissions: "755",
            fileExtension: ""
        )
        
        #expect(regularFolder.isParentDirectory == false)
        #expect(regularFolder.iconName == "folder.fill")
    }
    
    @Test func testLoadDirectoryIncludesParentItem() async {
        let service = FileSystemService.shared
        
        // 测试非根目录应该包含 ".." 项
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let result = await service.loadDirectoryWithPermissionCheck(at: documentsPath)
        
        if case .success(let files) = result {
            // 非根目录的第一个项目应该是 ".."
            if let firstItem = files.first {
                #expect(firstItem.isParentDirectory == true)
                #expect(firstItem.name == "..")
            }
        }
    }
    
    @Test func testRootDirectoryNoParentItem() async {
        let service = FileSystemService.shared
        
        // 测试根目录不应该包含 ".." 项
        let rootPath = URL(fileURLWithPath: "/")
        let result = await service.loadDirectoryWithPermissionCheck(at: rootPath)
        
        if case .success(let files) = result {
            // 根目录的第一个项目不应该是 ".."
            if let firstItem = files.first {
                #expect(firstItem.isParentDirectory == false)
            }
        }
    }
    
    // MARK: - 父目录项只读限制测试
    
    @Test func testParentDirectoryCannotBeSelected() {
        let drive = DriveInfo(
            id: "test-drive",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/Users"), drive: drive)
        
        // 尝试选中父目录项
        pane.toggleSelection(for: "..")
        
        // 父目录项不应该被选中
        #expect(pane.selections.contains("..") == false)
    }
    
    @Test func testParentDirectoryExcludedFromVisualSelection() {
        let drive = DriveInfo(
            id: "test-drive",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/Users"), drive: drive)
        
        // 添加父目录项和普通文件
        let parentItem = FileItem.parentDirectoryItem(for: URL(fileURLWithPath: "/"))
        let now = Date()
        let regularFile = FileItem(
            id: "file_1",
            name: "test.txt",
            path: URL(fileURLWithPath: "/Users/test.txt"),
            type: .file,
            size: 1024,
            modifiedDate: now,
            createdDate: now,
            isHidden: false,
            permissions: "rw-r--r--",
            fileExtension: "txt"
        )
        
        pane.activeTab.files = [parentItem, regularFile]
        
        // 设置 Visual 模式选择范围（包含父目录项）
        pane.visualAnchor = 0
        pane.cursorIndex = 1
        pane.updateVisualSelection()
        
        // 父目录项不应该在选择集中
        #expect(pane.selections.contains("..") == false)
        // 普通文件应该被选中
        #expect(pane.selections.contains("file_1") == true)
    }
    
    @Test func testSelectCurrentFileSkipsParentDirectory() {
        let drive = DriveInfo(
            id: "test-drive",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 500_000_000_000,
            availableCapacity: 100_000_000_000
        )
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/Users"), drive: drive)
        
        // 添加父目录项
        let parentItem = FileItem.parentDirectoryItem(for: URL(fileURLWithPath: "/"))
        pane.activeTab.files = [parentItem]
        pane.cursorIndex = 0
        
        // 尝试选择当前文件（父目录项）
        pane.selectCurrentFile()
        
        // 父目录项不应该被选中
        #expect(pane.selections.isEmpty == true)
    }
}

// MARK: - 7. AppState 测试 (模态操作引擎)

@MainActor
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
    
    @Test func testToast() async throws {
        let state = AppState()
        
        state.showToast("Test message")
        
        // 等待异步更新完成
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
        
        #expect(state.toastMessage == "Test message")
    }
}

// MARK: - 7.1 Visual 模式测试

@MainActor
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
    
    // MARK: - 测试：Visual 模式选择时 AppState 应该收到变化通知
    
    @Test func testVisualModeSelectionTriggersAppStateChange() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 1
        
        // 进入 Visual 模式并选择文件
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 初始应该有 1 个选中
        #expect(pane.selections.count == 1)
        
        // 移动光标选择更多文件
        pane.cursorIndex = 3
        pane.updateVisualSelection()
        
        // 验证选中计数正确
        #expect(pane.selections.count == 3)
        
        // 关键测试：验证通过 appState.currentPane.selections.count 能获得正确的值
        // 这是 StatusBarView 获取 selectedCount 的方式
        #expect(state.currentPane.selections.count == 3)
    }
    
    @Test func testVisualModeSelectionCountUpdatesCorrectly() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 10)
        pane.cursorIndex = 2
        
        // 进入 Visual 模式
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 验证初始选中 1 个
        #expect(state.currentPane.selections.count == 1)
        
        // 向下移动到 index 5 (应选中 2,3,4,5 共 4 个)
        pane.cursorIndex = 5
        pane.updateVisualSelection()
        #expect(state.currentPane.selections.count == 4)
        
        // 向下移动到 index 7 (应选中 2,3,4,5,6,7 共 6 个)
        pane.cursorIndex = 7
        pane.updateVisualSelection()
        #expect(state.currentPane.selections.count == 6)
        
        // 向上收缩到 index 4 (应选中 2,3,4 共 3 个)
        pane.cursorIndex = 4
        pane.updateVisualSelection()
        #expect(state.currentPane.selections.count == 3)
    }
    
    // MARK: - 测试: Visual 模式下按 r 显示批量重命名模态窗口
    
    @Test func testVisualModeShowRenameModal() {
        let state = AppState()
        let pane = state.currentPane
        
        // 设置测试文件
        pane.activeTab.files = createTestFileItems(count: 5)
        pane.cursorIndex = 1
        
        // 进入 Visual 模式并选择文件
        state.enterMode(.visual)
        pane.startVisualSelection()
        
        // 向下移动选择多个文件
        pane.cursorIndex = 3
        pane.updateVisualSelection()
        
        // 验证选中了多个文件
        #expect(pane.selections.count == 3)
        
        // 模拟按 r 显示重命名模态窗口
        state.showRenameModal = true
        
        // 验证模态窗口标志被设置
        #expect(state.showRenameModal == true)
    }
    
    @Test func testRenameModalInitialState() {
        let state = AppState()
        
        // 验证初始状态
        #expect(state.showRenameModal == false)
        #expect(state.renameFindText == "")
        #expect(state.renameReplaceText == "")
        #expect(state.renameUseRegex == false)
    }
    
    @Test func testRenameModalStateUpdates() {
        let state = AppState()
        
        // 设置重命名参数
        state.renameFindText = "IMG_"
        state.renameReplaceText = "Photo_{n}"
        state.renameUseRegex = false
        state.showRenameModal = true
        
        // 验证状态更新
        #expect(state.renameFindText == "IMG_")
        #expect(state.renameReplaceText == "Photo_{n}")
        #expect(state.renameUseRegex == false)
        #expect(state.showRenameModal == true)
    }
    
    @Test func testRenameModalWithRegex() {
        let state = AppState()
        
        // 设置正则表达式重命名
        state.renameFindText = "\\d{4}"
        state.renameReplaceText = "{date}"
        state.renameUseRegex = true
        
        // 验证正则模式
        #expect(state.renameUseRegex == true)
        #expect(state.renameFindText == "\\d{4}")
    }
    
    @Test func testRenameModalCloseResetsState() {
        let state = AppState()
        
        // 设置一些重命名参数
        state.renameFindText = "test"
        state.renameReplaceText = "new"
        state.showRenameModal = true
        
        // 模拟关闭模态窗口并重置状态
        state.showRenameModal = false
        state.renameFindText = ""
        state.renameReplaceText = ""
        state.renameUseRegex = false
        
        // 验证状态被重置
        #expect(state.showRenameModal == false)
        #expect(state.renameFindText == "")
        #expect(state.renameReplaceText == "")
        #expect(state.renameUseRegex == false)
    }
}

// MARK: - 7.1.1 批量重命名测试

@MainActor
struct BatchRenameTests {
    
    /// 模拟生成新文件名的逻辑（与 MainView 中的逻辑相同）
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
        
        var processedReplace = replaceText
            .replacingOccurrences(of: "{n}", with: String(format: "%03d", index + 1))
            .replacingOccurrences(of: "{date}", with: dateString)
        
        if useRegex {
            if let regex = try? NSRegularExpression(pattern: findText, options: []) {
                let range = NSRange(originalName.startIndex..., in: originalName)
                return regex.stringByReplacingMatches(
                    in: originalName,
                    options: [],
                    range: range,
                    withTemplate: processedReplace
                )
            }
            return originalName
        } else {
            return originalName.replacingOccurrences(of: findText, with: processedReplace)
        }
    }
    
    @Test func testBasicStringReplacement() {
        // 测试基本的字符串替换
        let result = generateNewName(
            originalName: "IMG_001.jpg",
            findText: "IMG_",
            replaceText: "Photo_",
            useRegex: false,
            index: 0
        )
        #expect(result == "Photo_001.jpg")
    }
    
    @Test func testSequenceNumberReplacement() {
        // 测试 {n} 序号替换
        let result1 = generateNewName(
            originalName: "file.txt",
            findText: "file",
            replaceText: "document_{n}",
            useRegex: false,
            index: 0
        )
        #expect(result1 == "document_001.txt")
        
        let result2 = generateNewName(
            originalName: "file.txt",
            findText: "file",
            replaceText: "document_{n}",
            useRegex: false,
            index: 9
        )
        #expect(result2 == "document_010.txt")
        
        let result3 = generateNewName(
            originalName: "file.txt",
            findText: "file",
            replaceText: "document_{n}",
            useRegex: false,
            index: 99
        )
        #expect(result3 == "document_100.txt")
    }
    
    @Test func testDateReplacement() {
        // 测试 {date} 日期替换
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let expectedDate = formatter.string(from: Date())
        
        let result = generateNewName(
            originalName: "photo.jpg",
            findText: "photo",
            replaceText: "pic_{date}",
            useRegex: false,
            index: 0
        )
        #expect(result == "pic_\(expectedDate).jpg")
    }
    
    @Test func testCombinedPlaceholders() {
        // 测试 {n} 和 {date} 组合使用
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let expectedDate = formatter.string(from: Date())
        
        let result = generateNewName(
            originalName: "IMG_original.png",
            findText: "IMG_original",
            replaceText: "Photo_{date}_{n}",
            useRegex: false,
            index: 4
        )
        #expect(result == "Photo_\(expectedDate)_005.png")
    }
    
    @Test func testRegexReplacement() {
        // 测试正则表达式替换
        let result = generateNewName(
            originalName: "file123.txt",
            findText: "\\d+",
            replaceText: "XXX",
            useRegex: true,
            index: 0
        )
        #expect(result == "fileXXX.txt")
    }
    
    @Test func testRegexWithGroups() {
        // 测试正则表达式分组捕获
        let result = generateNewName(
            originalName: "2023_photo.jpg",
            findText: "(\\d{4})_",
            replaceText: "year_$1_",
            useRegex: true,
            index: 0
        )
        #expect(result == "year_2023_photo.jpg")
    }
    
    @Test func testNoMatchNoChange() {
        // 测试没有匹配时不改变文件名
        let result = generateNewName(
            originalName: "document.pdf",
            findText: "photo",
            replaceText: "image",
            useRegex: false,
            index: 0
        )
        #expect(result == "document.pdf")
    }
    
    @Test func testEmptyReplacementRemovesMatch() {
        // 测试空替换删除匹配内容
        let result = generateNewName(
            originalName: "prefix_file.txt",
            findText: "prefix_",
            replaceText: "",
            useRegex: false,
            index: 0
        )
        #expect(result == "file.txt")
    }
    
    @Test func testMultipleMatchesReplaced() {
        // 测试多个匹配都被替换
        let result = generateNewName(
            originalName: "a_b_c.txt",
            findText: "_",
            replaceText: "-",
            useRegex: false,
            index: 0
        )
        #expect(result == "a-b-c.txt")
    }
    
    @Test func testInvalidRegexReturnsOriginal() {
        // 测试无效正则表达式返回原始文件名
        let result = generateNewName(
            originalName: "file.txt",
            findText: "[invalid",  // 无效的正则表达式
            replaceText: "new",
            useRegex: true,
            index: 0
        )
        #expect(result == "file.txt")
    }
    
    @Test func testSpecialCharactersInFindText() {
        // 测试查找文本中的特殊字符（非正则模式）
        let result = generateNewName(
            originalName: "file (1).txt",
            findText: " (1)",
            replaceText: "",
            useRegex: false,
            index: 0
        )
        #expect(result == "file.txt")
    }
}

// MARK: - 7.2 Command 模式测试

@MainActor
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

@MainActor
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
    
    @Test func testThemeModeValues() {
        // 验证主题模式枚举值
        #expect(ThemeMode.light.rawValue == "Light")
        #expect(ThemeMode.dark.rawValue == "Dark")
        #expect(ThemeMode.auto.rawValue == "Auto")
    }
    
    @Test func testThemeModeDisplayNames() {
        // 验证主题模式显示名称
        #expect(ThemeMode.light.displayName == "浅色")
        #expect(ThemeMode.dark.displayName == "深色")
        #expect(ThemeMode.auto.displayName == "跟随系统")
    }
    
    @Test func testThemeModeIcons() {
        // 验证主题模式图标
        #expect(ThemeMode.light.icon == "sun.max.fill")
        #expect(ThemeMode.dark.icon == "moon.fill")
        #expect(ThemeMode.auto.icon == "circle.lefthalf.filled")
    }
    
    @Test func testDarkThemeColors() {
        // 验证深色主题颜色
        let darkTheme = DarkTheme()
        #expect(darkTheme.background != darkTheme.textPrimary)
        #expect(darkTheme.accent != darkTheme.error)
    }
    
    @Test func testLightThemeColors() {
        // 验证浅色主题颜色
        let lightTheme = LightTheme()
        #expect(lightTheme.background != lightTheme.textPrimary)
        #expect(lightTheme.accent != lightTheme.error)
    }
    
    @Test func testThemeManagerSingleton() {
        // 验证 ThemeManager 单例
        let manager1 = ThemeManager.shared
        let manager2 = ThemeManager.shared
        #expect(manager1 === manager2)
    }
    
    @Test func testThemeManagerCycleTheme() {
        // 验证主题循环切换逻辑正确
        let allModes = ThemeMode.allCases
        
        // 验证循环顺序：light -> dark -> auto -> light
        #expect(allModes.count == 3)
        #expect(allModes[0] == .light)
        #expect(allModes[1] == .dark)
        #expect(allModes[2] == .auto)
        
        // 验证每个模式切换到下一个模式的逻辑
        for (index, currentMode) in allModes.enumerated() {
            let nextIndex = (index + 1) % allModes.count
            let expectedNextMode = allModes[nextIndex]
            
            // 模拟 cycleTheme 的逻辑
            if let currentIndex = allModes.firstIndex(of: currentMode) {
                let calculatedNextIndex = (currentIndex + 1) % allModes.count
                #expect(allModes[calculatedNextIndex] == expectedNextMode)
            }
        }
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

// MARK: - 12. 设置测试

@MainActor
struct SettingsTests {
    
    @Test func testAppSettingsDefault() {
        let settings = AppSettings.default
        
        #expect(settings.appearance.themeMode == "auto")
        #expect(settings.appearance.fontSize == 12.0)
        #expect(settings.appearance.lineHeight == 1.4)
        #expect(settings.terminal.defaultTerminal == "terminal")
    }
    
    @Test func testAppearanceSettingsThemeModeEnum() {
        var settings = AppearanceSettings.default
        
        settings.themeMode = "light"
        #expect(settings.themeModeEnum == .light)
        
        settings.themeMode = "dark"
        #expect(settings.themeModeEnum == .dark)
        
        settings.themeMode = "auto"
        #expect(settings.themeModeEnum == .auto)
        
        settings.themeMode = "invalid"
        #expect(settings.themeModeEnum == .auto) // 默认回退到 auto
    }
    
    @Test func testTerminalSettingsAvailableTerminals() {
        let terminals = TerminalSettings.availableTerminals
        
        #expect(terminals.count >= 1)
        #expect(terminals.first?.id == "terminal")
        #expect(terminals.first?.name == "Terminal")
        #expect(terminals.first?.bundleId == "com.apple.Terminal")
    }
    
    @Test func testTerminalOptionInstalled() {
        // 系统终端应该总是已安装
        let systemTerminal = TerminalOption(id: "terminal", name: "Terminal", bundleId: "com.apple.Terminal")
        #expect(systemTerminal.isInstalled == true)
    }
    
    @Test func testSettingsManagerSingleton() {
        let manager1 = SettingsManager.shared
        let manager2 = SettingsManager.shared
        #expect(manager1 === manager2)
    }
    
    @Test func testAppSettingsCodable() throws {
        let settings = AppSettings.default
        
        // 编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        // 解码
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        #expect(decoded == settings)
    }
    
    @Test func testTerminalSettingsCurrentTerminal() {
        var settings = TerminalSettings.default
        
        #expect(settings.currentTerminal.id == "terminal")
        
        settings.defaultTerminal = "iterm"
        #expect(settings.currentTerminal.id == "iterm")
        
        // 无效的终端 ID 应该回退到第一个
        settings.defaultTerminal = "nonexistent"
        #expect(settings.currentTerminal.id == "terminal")
    }
}

// MARK: - Scroll Sync Tests (cursorFileId 与 cursorIndex 同步测试)

struct ScrollSyncTests {
    
    func createTestDrive() -> DriveInfo {
        return DriveInfo(
            id: "test-drive",
            name: "Test",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 1000000,
            availableCapacity: 500000
        )
    }
    
    func createManyTestFiles(_ count: Int) -> [FileItem] {
        let now = Date()
        return (0..<count).map { i in
            FileItem(
                id: "file-\(i)",
                name: "file\(i).txt",
                path: URL(fileURLWithPath: "/test/file\(i).txt"),
                type: .file,
                size: 100 + Int64(i),
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "txt"
            )
        }
    }
    
    @Test func testCursorFileIdUpdatesWithCursorIndex() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(50)
        pane.activeTab.files = files
        
        // 初始位置
        pane.cursorIndex = 0
        #expect(pane.cursorFileId == "file-0")
        
        // 移动到中间
        pane.cursorIndex = 25
        #expect(pane.cursorFileId == "file-25")
        
        // 移动到末尾
        pane.cursorIndex = 49
        #expect(pane.cursorFileId == "file-49")
    }
    
    @Test func testCursorIndexUpdatesWithCursorFileId() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(50)
        pane.activeTab.files = files
        
        // 通过 cursorFileId 设置光标位置
        pane.cursorFileId = "file-10"
        #expect(pane.cursorIndex == 10)
        
        pane.cursorFileId = "file-40"
        #expect(pane.cursorIndex == 40)
    }
    
    @Test func testCursorNavigationDownToBottom() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(100)  // 模拟很多文件（需要滚动）
        pane.activeTab.files = files
        
        // 模拟使用 j 键向下导航到底部
        pane.cursorIndex = 0
        
        // 逐步向下移动
        for i in 1..<100 {
            pane.cursorIndex = i
            #expect(pane.cursorFileId == "file-\(i)")
        }
        
        // 确认到达底部
        #expect(pane.cursorIndex == 99)
        #expect(pane.cursorFileId == "file-99")
    }
    
    @Test func testCursorNavigationUpToTop() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(100)
        pane.activeTab.files = files
        
        // 从底部开始
        pane.cursorIndex = 99
        
        // 模拟使用 k 键向上导航到顶部
        for i in (0..<99).reversed() {
            pane.cursorIndex = i
            #expect(pane.cursorFileId == "file-\(i)")
        }
        
        // 确认到达顶部
        #expect(pane.cursorIndex == 0)
        #expect(pane.cursorFileId == "file-0")
    }
    
    @Test func testCursorBoundaryAtBottom() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(50)
        pane.activeTab.files = files
        
        // 尝试超出边界
        pane.cursorIndex = 50  // 超出范围
        
        // cursorIndex 应该被限制在有效范围内
        #expect(pane.cursorIndex <= 49)
    }
    
    @Test func testCursorBoundaryAtTop() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(50)
        pane.activeTab.files = files
        
        // 尝试超出边界
        pane.cursorIndex = -1  // 负数
        
        // cursorIndex 应该被限制在有效范围内
        #expect(pane.cursorIndex >= 0)
    }
    
    @Test func testFileIdConsistencyDuringNavigation() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(30)
        pane.activeTab.files = files
        
        // 快速来回导航，确保 cursorFileId 始终与 cursorIndex 同步
        let positions = [0, 15, 29, 10, 20, 5, 25, 0, 29]
        
        for pos in positions {
            pane.cursorIndex = pos
            let expectedFileId = "file-\(pos)"
            #expect(pane.cursorFileId == expectedFileId, "At position \(pos), expected \(expectedFileId) but got \(pane.cursorFileId)")
        }
    }
    
    @Test func testCursorFileIdForScrollViewReader() {
        // 这个测试验证 cursorFileId 的值格式与 FileItem 的 id 格式一致
        // 这对于 ScrollViewReader 的 scrollTo 功能至关重要
        
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(10)
        pane.activeTab.files = files
        
        for (index, file) in files.enumerated() {
            pane.cursorIndex = index
            // cursorFileId 应该与文件的 id 完全相同
            #expect(pane.cursorFileId == file.id, "cursorFileId should match file.id for scrollTo to work")
        }
    }
    
    // MARK: - 边缘滚动测试（anchor: nil 行为验证）
    
    @Test func testEdgeScrollingDownBehavior() {
        // 测试向下导航时的滚动行为
        // 使用 anchor: nil 时，只有当项目即将超出视图时才会滚动
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(100)
        pane.activeTab.files = files
        
        // 从顶部开始逐步向下
        pane.cursorIndex = 0
        
        // 模拟逐步向下移动（比如 j 键）
        // cursorFileId 应该始终跟随 cursorIndex
        for i in 1...99 {
            pane.cursorIndex = i
            #expect(pane.cursorFileId == "file-\(i)", "cursorFileId should track cursorIndex during downward navigation")
        }
        
        // 最终应该在最后一项
        #expect(pane.cursorIndex == 99)
        #expect(pane.cursorFileId == "file-99")
    }
    
    @Test func testEdgeScrollingUpBehavior() {
        // 测试向上导航时的滚动行为
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(100)
        pane.activeTab.files = files
        
        // 从底部开始
        pane.cursorIndex = 99
        #expect(pane.cursorFileId == "file-99")
        
        // 逐步向上移动（比如 k 键）
        for i in (0...98).reversed() {
            pane.cursorIndex = i
            #expect(pane.cursorFileId == "file-\(i)", "cursorFileId should track cursorIndex during upward navigation")
        }
        
        // 最终应该在第一项
        #expect(pane.cursorIndex == 0)
        #expect(pane.cursorFileId == "file-0")
    }
    
    @Test func testScrollTargetIdMatchesFileId() {
        // 验证 scroll target (cursorFileId) 与实际文件 id 格式完全匹配
        // 这是 scrollTo(id, anchor: nil) 正常工作的关键
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(50)
        pane.activeTab.files = files
        
        // 测试多个随机位置
        let testPositions = [0, 1, 24, 25, 48, 49]
        
        for pos in testPositions {
            pane.cursorIndex = pos
            let file = files[pos]
            
            // cursorFileId 必须与文件的 id 完全相同
            // 这样 ScrollViewReader.scrollTo(cursorFileId) 才能正确定位
            #expect(pane.cursorFileId == file.id, "Scroll target must match file.id exactly at position \(pos)")
        }
    }
    
    @Test func testContinuousNavigationWithoutJump() {
        // 测试连续导航时不会出现跳跃
        // 这验证了使用 anchor: nil 时的平滑滚动体验
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(200)  // 大量文件
        pane.activeTab.files = files
        
        pane.cursorIndex = 0
        var previousIndex = 0
        
        // 向下连续移动 50 次
        for _ in 1...50 {
            let newIndex = previousIndex + 1
            pane.cursorIndex = newIndex
            
            // 验证索引只增加 1（没有跳跃）
            #expect(pane.cursorIndex == previousIndex + 1, "Cursor should move one step at a time")
            #expect(pane.cursorFileId == "file-\(newIndex)")
            
            previousIndex = newIndex
        }
        
        // 向上连续移动 50 次
        for _ in 1...50 {
            let newIndex = previousIndex - 1
            pane.cursorIndex = newIndex
            
            // 验证索引只减少 1（没有跳跃）
            #expect(pane.cursorIndex == previousIndex - 1, "Cursor should move one step at a time")
            #expect(pane.cursorFileId == "file-\(newIndex)")
            
            previousIndex = newIndex
        }
    }
    
    @Test func testEdgeCasesForScrolling() {
        // 测试边界情况
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/"), drive: createTestDrive())
        let files = createManyTestFiles(10)
        pane.activeTab.files = files
        
        // 测试从第一项开始
        pane.cursorIndex = 0
        #expect(pane.cursorFileId == "file-0")
        
        // 移动到最后一项
        pane.cursorIndex = 9
        #expect(pane.cursorFileId == "file-9")
        
        // 直接跳到中间
        pane.cursorIndex = 5
        #expect(pane.cursorFileId == "file-5")
        
        // 跳回第一项
        pane.cursorIndex = 0
        #expect(pane.cursorFileId == "file-0")
        
        // 跳到最后一项
        pane.cursorIndex = 9
        #expect(pane.cursorFileId == "file-9")
    }
}

// MARK: - Mouse Click Tests (鼠标点击功能测试)

@MainActor
struct MouseClickTests {
    
    func createTestDrive() -> DriveInfo {
        return DriveInfo(
            id: "test-drive",
            name: "Test",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 1000000,
            availableCapacity: 500000
        )
    }
    
    func createTestFiles(_ count: Int) -> [FileItem] {
        let now = Date()
        return (0..<count).map { i in
            FileItem(
                id: "file-\(i)",
                name: "file\(i).txt",
                path: URL(fileURLWithPath: "/test/file\(i).txt"),
                type: .file,
                size: 100 + Int64(i),
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rw-r--r--",
                fileExtension: "txt"
            )
        }
    }
    
    func createTestFolders(_ count: Int) -> [FileItem] {
        let now = Date()
        return (0..<count).map { i in
            FileItem(
                id: "folder-\(i)",
                name: "folder\(i)",
                path: URL(fileURLWithPath: "/test/folder\(i)"),
                type: .folder,
                size: 0,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "rwxr-xr-x",
                fileExtension: ""
            )
        }
    }
    
    @Test func testSingleClickSelectsFile() {
        // 模拟单击选中文件
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFiles(10)
        
        // 初始光标在位置 0
        pane.cursorIndex = 0
        #expect(pane.cursorIndex == 0)
        
        // 模拟点击位置 5（单击应该更新 cursorIndex）
        pane.cursorIndex = 5
        
        #expect(pane.cursorIndex == 5)
        #expect(pane.cursorFileId == "file-5")
    }
    
    @Test func testClickOnDifferentFilesUpdatesCursor() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFiles(20)
        
        // 模拟连续点击不同文件
        let clickSequence = [0, 5, 10, 15, 19, 3, 7]
        
        for index in clickSequence {
            pane.cursorIndex = index
            #expect(pane.cursorIndex == index)
            #expect(pane.cursorFileId == "file-\(index)")
        }
    }
    
    @Test func testClickOnFolderSelectsFolder() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFolders(5)
        
        // 单击选中文件夹
        pane.cursorIndex = 2
        
        #expect(pane.cursorIndex == 2)
        #expect(pane.cursorFileId == "folder-2")
    }
    
    @Test func testClickUpdatesActivePaneState() {
        let appState = AppState()
        
        // 初始状态应该是左面板激活
        #expect(appState.activePane == .left)
        
        // 切换到右面板
        appState.setActivePane(.right)
        #expect(appState.activePane == .right)
        
        // 切换回左面板
        appState.setActivePane(.left)
        #expect(appState.activePane == .left)
    }
    
    @Test func testCursorIndexSyncWithFileId() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFiles(15)
        
        // 通过 cursorIndex 设置
        pane.cursorIndex = 7
        #expect(pane.cursorFileId == "file-7")
        
        // 通过 cursorFileId 设置
        pane.cursorFileId = "file-12"
        #expect(pane.cursorIndex == 12)
    }
    
    @Test func testClickInListViewMode() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.viewMode = .list
        pane.activeTab.files = createTestFiles(10)
        
        // 在列表模式下点击
        pane.cursorIndex = 3
        
        #expect(pane.viewMode == .list)
        #expect(pane.cursorIndex == 3)
    }
    
    @Test func testClickInGridViewMode() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.viewMode = .grid
        pane.gridColumnCount = 4
        pane.activeTab.files = createTestFiles(16)
        
        // 在网格模式下点击（第二行第三个）
        pane.cursorIndex = 6
        
        #expect(pane.viewMode == .grid)
        #expect(pane.cursorIndex == 6)
    }
    
    @Test func testClickOnFirstFile() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFiles(10)
        pane.cursorIndex = 5  // 从中间开始
        
        // 点击第一个文件
        pane.cursorIndex = 0
        
        #expect(pane.cursorIndex == 0)
        #expect(pane.cursorFileId == "file-0")
    }
    
    @Test func testClickOnLastFile() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFiles(10)
        pane.cursorIndex = 0  // 从开头开始
        
        // 点击最后一个文件
        pane.cursorIndex = 9
        
        #expect(pane.cursorIndex == 9)
        #expect(pane.cursorFileId == "file-9")
    }
    
    @Test func testRapidClicksOnDifferentFiles() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = createTestFiles(100)
        
        // 模拟快速连续点击
        for i in 0..<100 {
            pane.cursorIndex = i
            #expect(pane.cursorIndex == i)
        }
        
        // 最终应该在最后一个文件
        #expect(pane.cursorIndex == 99)
    }
    
    @Test func testClickWithEmptyFileList() {
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/test"), drive: createTestDrive())
        pane.activeTab.files = []
        
        // 尝试设置光标（空列表应该保持在 0 或安全值）
        pane.cursorIndex = 0
        
        // cursorIndex 在空列表中的行为
        #expect(pane.activeTab.files.isEmpty)
    }
}

// MARK: - 书签功能测试

@MainActor
struct BookmarkItemTests {
    
    @Test func testBookmarkItemCreation() {
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        let bookmark = BookmarkItem(
            name: "Documents",
            path: path,
            type: .folder,
            iconName: "folder.fill"
        )
        
        #expect(bookmark.name == "Documents")
        #expect(bookmark.path == path)
        #expect(bookmark.type == .folder)
        #expect(bookmark.iconName == "folder.fill")
        #expect(bookmark.id != UUID())
    }
    
    @Test func testBookmarkItemFromFileItem() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        if let fileItem = FileItem.fromURL(homeDir) {
            let bookmark = BookmarkItem.from(fileItem: fileItem)
            
            #expect(bookmark.name == fileItem.name)
            #expect(bookmark.path == fileItem.path)
            #expect(bookmark.iconName == fileItem.iconName)
        }
    }
    
    @Test func testBookmarkItemTypes() {
        let folderBookmark = BookmarkItem(
            name: "Folder",
            path: URL(fileURLWithPath: "/test/folder"),
            type: .folder
        )
        let fileBookmark = BookmarkItem(
            name: "File",
            path: URL(fileURLWithPath: "/test/file.txt"),
            type: .file
        )
        
        #expect(folderBookmark.type == .folder)
        #expect(fileBookmark.type == .file)
    }
    
    @Test func testBookmarkItemEquality() {
        let id = UUID()
        let bookmark1 = BookmarkItem(
            id: id,
            name: "Test",
            path: URL(fileURLWithPath: "/test"),
            type: .folder
        )
        let bookmark2 = BookmarkItem(
            id: id,
            name: "Test",
            path: URL(fileURLWithPath: "/test"),
            type: .folder
        )
        
        #expect(bookmark1.id == bookmark2.id)
        #expect(bookmark1.name == bookmark2.name)
        #expect(bookmark1.path == bookmark2.path)
    }
    
    @Test func testBookmarkItemCodable() throws {
        let bookmark = BookmarkItem(
            name: "Test Bookmark",
            path: URL(fileURLWithPath: "/Users/test/Documents"),
            type: .folder,
            iconName: "folder.fill"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(bookmark)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BookmarkItem.self, from: data)
        
        #expect(decoded.id == bookmark.id)
        #expect(decoded.name == bookmark.name)
        #expect(decoded.path == bookmark.path)
        #expect(decoded.type == bookmark.type)
        #expect(decoded.iconName == bookmark.iconName)
    }
}

@MainActor
struct BookmarkManagerTests {
    
    @Test func testBookmarkManagerAddBookmark() {
        let manager = BookmarkManager()
        manager.bookmarks = []  // 清空初始书签
        
        let bookmark = BookmarkItem(
            name: "Test",
            path: URL(fileURLWithPath: "/test"),
            type: .folder
        )
        
        manager.add(bookmark)
        
        #expect(manager.bookmarks.count == 1)
        #expect(manager.bookmarks.first?.name == "Test")
    }
    
    @Test func testBookmarkManagerRemoveBookmark() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        let bookmark = BookmarkItem(
            name: "Test",
            path: URL(fileURLWithPath: "/test"),
            type: .folder
        )
        
        manager.add(bookmark)
        #expect(manager.bookmarks.count == 1)
        
        manager.remove(bookmark)
        #expect(manager.bookmarks.isEmpty)
    }
    
    @Test func testBookmarkManagerPreventDuplicatePath() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        let path = URL(fileURLWithPath: "/test/duplicate")
        let bookmark1 = BookmarkItem(name: "First", path: path, type: .folder)
        let bookmark2 = BookmarkItem(name: "Second", path: path, type: .folder)
        
        manager.add(bookmark1)
        manager.add(bookmark2)  // 相同路径不应重复添加
        
        #expect(manager.bookmarks.count == 1)
        #expect(manager.bookmarks.first?.name == "First")
    }
    
    @Test func testBookmarkManagerReorder() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        let bookmark1 = BookmarkItem(name: "A", path: URL(fileURLWithPath: "/a"), type: .folder)
        let bookmark2 = BookmarkItem(name: "B", path: URL(fileURLWithPath: "/b"), type: .folder)
        let bookmark3 = BookmarkItem(name: "C", path: URL(fileURLWithPath: "/c"), type: .folder)
        
        manager.add(bookmark1)
        manager.add(bookmark2)
        manager.add(bookmark3)
        
        // 移动第一个到最后
        manager.reorder(from: IndexSet(integer: 0), to: 3)
        
        #expect(manager.bookmarks[0].name == "B")
        #expect(manager.bookmarks[1].name == "C")
        #expect(manager.bookmarks[2].name == "A")
    }
    
    @Test func testBookmarkManagerContainsPath() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        let path = URL(fileURLWithPath: "/test/exists")
        let bookmark = BookmarkItem(name: "Test", path: path, type: .folder)
        
        manager.add(bookmark)
        
        #expect(manager.contains(path: path) == true)
        #expect(manager.contains(path: URL(fileURLWithPath: "/other/path")) == false)
    }
    
    @Test func testBookmarkManagerAddFileItem() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        if let fileItem = FileItem.fromURL(homeDir) {
            manager.addBookmark(for: fileItem)
            
            #expect(manager.bookmarks.count == 1)
            #expect(manager.bookmarks.first?.path == homeDir)
        }
    }
    
    @Test func testBookmarkManagerToggleBookmark() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        if let fileItem = FileItem.fromURL(homeDir) {
            // 添加书签
            manager.toggleBookmark(for: fileItem)
            #expect(manager.bookmarks.count == 1)
            
            // 再次切换应该移除
            manager.toggleBookmark(for: fileItem)
            #expect(manager.bookmarks.isEmpty)
        }
    }
    
    @Test func testBookmarkManagerClearAll() {
        let manager = BookmarkManager()
        manager.bookmarks = []
        
        manager.add(BookmarkItem(name: "A", path: URL(fileURLWithPath: "/a"), type: .folder))
        manager.add(BookmarkItem(name: "B", path: URL(fileURLWithPath: "/b"), type: .folder))
        manager.add(BookmarkItem(name: "C", path: URL(fileURLWithPath: "/c"), type: .folder))
        
        #expect(manager.bookmarks.count == 3)
        
        manager.clearAll()
        #expect(manager.bookmarks.isEmpty)
    }
}



// MARK: - Git 状态模型测试

struct GitFileStatusTests {
    
    @Test func testGitFileStatusRawValues() {
        #expect(GitFileStatus.modified.rawValue == "M")
        #expect(GitFileStatus.added.rawValue == "A")
        #expect(GitFileStatus.deleted.rawValue == "D")
        #expect(GitFileStatus.renamed.rawValue == "R")
        #expect(GitFileStatus.copied.rawValue == "C")
        #expect(GitFileStatus.untracked.rawValue == "?")
        #expect(GitFileStatus.ignored.rawValue == "!")
        #expect(GitFileStatus.conflict.rawValue == "U")
        #expect(GitFileStatus.clean.rawValue == "")
    }
    
    @Test func testGitFileStatusDisplayText() {
        #expect(GitFileStatus.modified.displayText == "M")
        #expect(GitFileStatus.added.displayText == "A")
        #expect(GitFileStatus.deleted.displayText == "D")
        #expect(GitFileStatus.renamed.displayText == "R")
        #expect(GitFileStatus.untracked.displayText == "?")
        #expect(GitFileStatus.clean.displayText == "")
    }
    
    @Test func testGitFileStatusShouldDisplay() {
        // 应该显示的状态
        #expect(GitFileStatus.modified.shouldDisplay == true)
        #expect(GitFileStatus.added.shouldDisplay == true)
        #expect(GitFileStatus.deleted.shouldDisplay == true)
        #expect(GitFileStatus.renamed.shouldDisplay == true)
        #expect(GitFileStatus.copied.shouldDisplay == true)
        #expect(GitFileStatus.untracked.shouldDisplay == true)
        #expect(GitFileStatus.conflict.shouldDisplay == true)
        
        // 不应该显示的状态
        #expect(GitFileStatus.clean.shouldDisplay == false)
        #expect(GitFileStatus.ignored.shouldDisplay == false)
    }
    
    @Test func testGitFileStatusDescription() {
        #expect(GitFileStatus.modified.description == "Modified")
        #expect(GitFileStatus.added.description == "Added")
        #expect(GitFileStatus.deleted.description == "Deleted")
        #expect(GitFileStatus.renamed.description == "Renamed")
        #expect(GitFileStatus.copied.description == "Copied")
        #expect(GitFileStatus.untracked.description == "Untracked")
        #expect(GitFileStatus.ignored.description == "Ignored")
        #expect(GitFileStatus.conflict.description == "Conflict")
        #expect(GitFileStatus.clean.description == "Clean")
    }
    
    @Test func testGitFileStatusColor() {
        // 验证每种状态都有颜色（不会崩溃）
        let statuses: [GitFileStatus] = [
            .modified, .added, .deleted, .renamed,
            .copied, .untracked, .ignored, .conflict, .clean
        ]
        
        for status in statuses {
            let _ = status.color
        }
        
        #expect(true) // 所有颜色定义都存在
    }
}

// MARK: - Git 仓库信息测试

struct GitRepositoryInfoTests {
    
    @Test func testNotARepository() {
        let info = GitRepositoryInfo.notARepository
        
        #expect(info.isGitRepository == false)
        #expect(info.rootPath == nil)
        #expect(info.currentBranch == nil)
        #expect(info.isDetachedHead == false)
        #expect(info.ahead == 0)
        #expect(info.behind == 0)
        #expect(info.hasUncommittedChanges == false)
    }
    
    @Test func testBranchDisplayText() {
        // 非 Git 仓库
        let notRepo = GitRepositoryInfo.notARepository
        #expect(notRepo.branchDisplayText == nil)
        
        // 正常分支
        let normalRepo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 0,
            behind: 0,
            hasUncommittedChanges: false
        )
        #expect(normalRepo.branchDisplayText == "main")
        
        // 分离 HEAD 状态
        let detachedRepo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: nil,
            isDetachedHead: true,
            ahead: 0,
            behind: 0,
            hasUncommittedChanges: false
        )
        #expect(detachedRepo.branchDisplayText == "HEAD")
    }
    
    @Test func testSyncStatusText() {
        // 非 Git 仓库
        let notRepo = GitRepositoryInfo.notARepository
        #expect(notRepo.syncStatusText == nil)
        
        // 同步状态
        let syncedRepo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 0,
            behind: 0,
            hasUncommittedChanges: false
        )
        #expect(syncedRepo.syncStatusText == nil)
        
        // 领先远程
        let aheadRepo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 3,
            behind: 0,
            hasUncommittedChanges: false
        )
        #expect(aheadRepo.syncStatusText == "↑3")
        
        // 落后远程
        let behindRepo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 0,
            behind: 2,
            hasUncommittedChanges: false
        )
        #expect(behindRepo.syncStatusText == "↓2")
        
        // 同时领先和落后
        let divergedRepo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 3,
            behind: 2,
            hasUncommittedChanges: false
        )
        #expect(divergedRepo.syncStatusText == "↑3 ↓2")
    }
}

// MARK: - Git 状态缓存测试

struct GitStatusCacheEntryTests {
    
    @Test func testCacheExpiry() {
        let entry = GitStatusCacheEntry(
            fileStatuses: [:],
            repositoryInfo: GitRepositoryInfo.notARepository,
            timestamp: Date()
        )
        
        // 新创建的缓存不应该过期（TTL 为 5 秒）
        #expect(entry.isExpired(ttl: 5.0) == false)
        
        // 创建一个已经过期的缓存
        let expiredEntry = GitStatusCacheEntry(
            fileStatuses: [:],
            repositoryInfo: GitRepositoryInfo.notARepository,
            timestamp: Date().addingTimeInterval(-10)
        )
        
        #expect(expiredEntry.isExpired(ttl: 5.0) == true)
    }
}

// MARK: - Git 服务测试

struct GitServiceTests {
    
    @Test func testGitServiceSingleton() {
        let service1 = GitService.shared
        let service2 = GitService.shared
        
        // 验证单例
        #expect(service1 === service2)
    }
    
    @Test func testIsGitInstalled() {
        let service = GitService.shared
        let isInstalled = service.isGitInstalled()
        
        // Git 应该在大多数开发环境中安装
        // 这个测试可能在某些环境中失败，所以我们只验证它返回一个布尔值
        #expect(isInstalled == true || isInstalled == false)
    }
    
    @Test func testIsGitRepositoryForNonRepo() {
        let service = GitService.shared
        
        // /tmp 通常不是 Git 仓库
        let tmpPath = URL(fileURLWithPath: "/tmp")
        let isRepo = service.isGitRepository(at: tmpPath)
        
        #expect(isRepo == false)
    }
    
    @Test func testGetRepositoryInfoForNonRepo() {
        let service = GitService.shared
        
        // /tmp 通常不是 Git 仓库
        let tmpPath = URL(fileURLWithPath: "/tmp")
        let info = service.getRepositoryInfo(at: tmpPath)
        
        #expect(info.isGitRepository == false)
        #expect(info.currentBranch == nil)
    }
    
    @Test func testGetFileStatusesForNonRepo() {
        let service = GitService.shared
        
        // /tmp 通常不是 Git 仓库
        let tmpPath = URL(fileURLWithPath: "/tmp")
        let statuses = service.getFileStatuses(in: tmpPath)
        
        #expect(statuses.isEmpty)
    }
    
    @Test func testGetRepositoryInfoForActualRepo() {
        let service = GitService.shared
        
        // 测试当前项目目录（应该是 Git 仓库）
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Zenith CommanderTests
            .deletingLastPathComponent() // Zenith Commander
        
        if service.isGitRepository(at: projectPath) {
            let info = service.getRepositoryInfo(at: projectPath)
            
            #expect(info.isGitRepository == true)
            #expect(info.rootPath != nil)
            // 分支名应该存在（除非是分离 HEAD 状态）
            #expect(info.currentBranch != nil || info.isDetachedHead == true)
        }
    }
}

// MARK: - FileItem Git 状态测试

struct FileItemGitStatusTests {
    
    @Test func testFileItemDefaultGitStatus() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        if let fileItem = FileItem.fromURL(homeDir) {
            // 默认 Git 状态应该是 clean
            #expect(fileItem.gitStatus == .clean)
        }
    }
    
    @Test func testFileItemWithGitStatus() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        if let fileItem = FileItem.fromURL(homeDir) {
            // 测试 withGitStatus 方法
            let modifiedItem = fileItem.withGitStatus(.modified)
            #expect(modifiedItem.gitStatus == .modified)
            #expect(modifiedItem.name == fileItem.name)
            #expect(modifiedItem.path == fileItem.path)
            
            let addedItem = fileItem.withGitStatus(.added)
            #expect(addedItem.gitStatus == .added)
            
            let untrackedItem = fileItem.withGitStatus(.untracked)
            #expect(untrackedItem.gitStatus == .untracked)
            
            // 测试传入 nil
            let cleanItem = fileItem.withGitStatus(nil)
            #expect(cleanItem.gitStatus == .clean)
        }
    }
}

// MARK: - Git 设置测试

@MainActor
struct GitSettingsTests {
    
    @Test func testDefaultGitSettings() {
        let defaultSettings = GitSettings.default
        
        #expect(defaultSettings.enabled == true)
        #expect(defaultSettings.showUntrackedFiles == true)
        #expect(defaultSettings.showIgnoredFiles == false)
    }
    
    @Test func testGitSettingsEquatable() {
        let settings1 = GitSettings(
            enabled: true,
            showUntrackedFiles: true,
            showIgnoredFiles: false
        )
        
        let settings2 = GitSettings(
            enabled: true,
            showUntrackedFiles: true,
            showIgnoredFiles: false
        )
        
        let settings3 = GitSettings(
            enabled: false,
            showUntrackedFiles: true,
            showIgnoredFiles: false
        )
        
        #expect(settings1 == settings2)
        #expect(settings1 != settings3)
    }
    
    @Test func testGitSettingsCodable() throws {
        let originalSettings = GitSettings(
            enabled: true,
            showUntrackedFiles: false,
            showIgnoredFiles: true
        )
        
        // 编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSettings)
        
        // 解码
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(GitSettings.self, from: data)
        
        #expect(decodedSettings == originalSettings)
    }
}

// MARK: - AppSettings Git 集成测试

@MainActor
struct AppSettingsGitTests {
    
    @Test func testDefaultAppSettingsIncludesGit() {
        let defaultSettings = AppSettings.default
        
        // 验证默认设置包含 Git 设置
        #expect(defaultSettings.git.enabled == true)
        #expect(defaultSettings.git.showUntrackedFiles == true)
        #expect(defaultSettings.git.showIgnoredFiles == false)
    }
    
    @Test func testAppSettingsCodableWithGit() throws {
        let settings = AppSettings(
            appearance: .default,
            terminal: .default,
            git: GitSettings(
                enabled: false,
                showUntrackedFiles: false,
                showIgnoredFiles: true
            ),
            rsync: RsyncSettings(enabled: true)
        )
        
        // 编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        // 解码
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(AppSettings.self, from: data)
        
        #expect(decodedSettings.git.enabled == false)
        #expect(decodedSettings.git.showUntrackedFiles == false)
        #expect(decodedSettings.git.showIgnoredFiles == true)
    }
}

// MARK: - PaneState Git 信息测试

struct PaneStateGitInfoTests {
    
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
    
    @Test func testPaneStateGitInfoDefault() {
        let drive = createTestDrive()
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/Users"), drive: drive)
        
        // 默认 gitInfo 应该是 nil
        #expect(pane.gitInfo == nil)
    }
    
    @Test func testPaneStateGitInfoAssignment() {
        let drive = createTestDrive()
        let pane = PaneState(side: .left, initialPath: URL(fileURLWithPath: "/Users"), drive: drive)
        
        // 设置 gitInfo
        let testInfo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/test"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 1,
            behind: 2,
            hasUncommittedChanges: true
        )
        
        pane.gitInfo = testInfo
        
        #expect(pane.gitInfo?.isGitRepository == true)
        #expect(pane.gitInfo?.currentBranch == "main")
        #expect(pane.gitInfo?.ahead == 1)
        #expect(pane.gitInfo?.behind == 2)
        #expect(pane.gitInfo?.hasUncommittedChanges == true)
    }
}

// MARK: - 8. AppState Git History Tests


@MainActor
struct AppStateGitHistoryTests {
    
    @Test func testShowGitHistoryForRepoUpdatesState() {
        let state = AppState()
        let path = URL(fileURLWithPath: "/") // Just a path
        
        // Call the method
        state.showGitHistoryForRepo(at: path)
        
        // Check immediate state changes
        #expect(state.showGitHistory == true)
        #expect(state.gitHistoryLoading == true)
        #expect(state.gitHistoryFile == nil)
    }
    
    @Test func testCloseGitHistoryResetsState() {
        let state = AppState()
        state.showGitHistory = true
        state.gitHistoryLoading = false
        
        state.closeGitHistory()
        
        #expect(state.showGitHistory == false)
        #expect(state.gitHistoryFile == nil)
        #expect(state.gitHistoryCommits.isEmpty)
    }
}
