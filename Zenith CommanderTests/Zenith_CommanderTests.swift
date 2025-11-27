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

