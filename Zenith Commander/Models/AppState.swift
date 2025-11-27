//
//  AppState.swift
//  Zenith Commander
//
//  全局应用状态管理 (使用 @Observable - Swift 5.9+)
//

import Foundation
import SwiftUI

/// 标签页状态
@Observable
class TabState: Identifiable {
    let id: UUID
    var drive: DriveInfo
    var currentPath: URL
    var files: [FileItem]
    var cursorIndex: Int
    var scrollOffset: CGFloat
    
    init(drive: DriveInfo, path: URL) {
        self.id = UUID()
        self.drive = drive
        self.currentPath = path
        self.files = []
        self.cursorIndex = 0
        self.scrollOffset = 0
    }
    
    /// 当前目录名称
    var directoryName: String {
        currentPath.lastPathComponent.isEmpty ? drive.name : currentPath.lastPathComponent
    }
    
    /// 路径组件数组
    var pathComponents: [String] {
        var components = currentPath.pathComponents
        // 移除第一个 "/" 
        if components.first == "/" {
            components.removeFirst()
        }
        return components
    }
}

/// 面板状态
@Observable
class PaneState {
    var side: PaneSide
    var tabs: [TabState]
    var activeTabIndex: Int
    var viewMode: ViewMode
    var selections: Set<String> // 存储选中的文件 ID
    var visualAnchor: Int? // Visual 模式的锚点位置
    
    init(side: PaneSide, initialPath: URL, drive: DriveInfo) {
        self.side = side
        self.tabs = [TabState(drive: drive, path: initialPath)]
        self.activeTabIndex = 0
        self.viewMode = .list
        self.selections = []
        self.visualAnchor = nil
    }
    
    /// 当前活动标签页
    var activeTab: TabState {
        tabs[activeTabIndex]
    }
    
    /// 当前文件列表
    var currentFiles: [FileItem] {
        activeTab.files
    }
    
    /// 当前光标位置
    var cursorIndex: Int {
        get { activeTab.cursorIndex }
        set { activeTab.cursorIndex = newValue }
    }
    
    /// 添加新标签页
    func addTab(path: URL? = nil, drive: DriveInfo? = nil) {
        let newDrive = drive ?? activeTab.drive
        let newPath = path ?? activeTab.currentPath
        let newTab = TabState(drive: newDrive, path: newPath)
        tabs.append(newTab)
        activeTabIndex = tabs.count - 1
    }
    
    /// 关闭标签页
    func closeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        tabs.remove(at: index)
        if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        }
    }
    
    /// 切换到指定标签页
    func switchTab(to index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabIndex = index
    }
    
    /// 切换到下一个标签页
    func nextTab() {
        activeTabIndex = (activeTabIndex + 1) % tabs.count
    }
    
    /// 切换到上一个标签页
    func previousTab() {
        activeTabIndex = (activeTabIndex - 1 + tabs.count) % tabs.count
    }
    
    /// 清除选择
    func clearSelections() {
        selections.removeAll()
        visualAnchor = nil
    }
    
    /// 切换选择状态
    func toggleSelection(for fileId: String) {
        if selections.contains(fileId) {
            selections.remove(fileId)
        } else {
            selections.insert(fileId)
        }
    }
    
    /// 选择当前光标所在文件
    func selectCurrentFile() {
        guard cursorIndex < activeTab.files.count else { return }
        let file = activeTab.files[cursorIndex]
        selections.insert(file.id)
    }
    
    /// 开始 Visual 模式选择
    func startVisualSelection() {
        visualAnchor = cursorIndex
        // 选中当前文件
        selectCurrentFile()
    }
    
    /// 更新 Visual 模式选择范围
    /// 选择从锚点到当前光标之间的所有文件
    func updateVisualSelection() {
        guard let anchor = visualAnchor else {
            // 如果没有锚点，设置当前位置为锚点
            startVisualSelection()
            return
        }
        
        let files = activeTab.files
        guard !files.isEmpty else { return }
        
        // 计算选择范围
        let start = min(anchor, cursorIndex)
        let end = max(anchor, cursorIndex)
        
        // 清除旧选择，重新选择范围内的文件
        selections.removeAll()
        for i in start...end {
            if i < files.count {
                selections.insert(files[i].id)
            }
        }
    }
}

/// 全局应用状态
@Observable
class AppState {
    // MARK: - 面板状态
    var leftPane: PaneState
    var rightPane: PaneState
    var activePane: PaneSide = .left
    
    // MARK: - 模态状态
    var mode: AppMode = .normal
    var previousMode: AppMode = .normal
    
    // MARK: - 输入状态
    var commandInput: String = ""
    var filterInput: String = ""
    var inputBuffer: String = ""
    
    // MARK: - 剪贴板
    var clipboard: [FileItem] = []
    var clipboardOperation: ClipboardOperation = .copy
    
    // MARK: - UI 状态
    var toastMessage: String?
    var showDriveSelector: Bool = false
    var driveSelectorCursor: Int = 0
    var availableDrives: [DriveInfo] = []
    
    // MARK: - AI 状态
    var aiResult: String = ""
    var isAiLoading: Bool = false
    
    // MARK: - 批量重命名状态
    var showRenameModal: Bool = false
    var renameFindText: String = ""
    var renameReplaceText: String = ""
    var renameUseRegex: Bool = false
    
    // MARK: - 右键菜单状态
    var contextMenuPosition: CGPoint?
    var contextMenuFile: FileItem?
    
    init() {
        // 获取默认驱动器
        let defaultDrive = DriveInfo(
            id: "macintosh-hd",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 0,
            availableCapacity: 0
        )
        
        // 初始化面板，默认路径为用户主目录
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        leftPane = PaneState(side: .left, initialPath: homePath, drive: defaultDrive)
        rightPane = PaneState(side: .right, initialPath: homePath.appendingPathComponent("Downloads"), drive: defaultDrive)
    }
    
    // MARK: - 计算属性
    
    /// 当前活动面板
    var currentPane: PaneState {
        activePane == .left ? leftPane : rightPane
    }
    
    /// 非活动面板
    var inactivePane: PaneState {
        activePane == .left ? rightPane : leftPane
    }
    
    /// 状态栏显示文本
    var statusText: String {
        switch mode {
        case .command:
            return ":\(commandInput)"
        case .filter:
            return "/\(filterInput)"
        default:
            let tab = currentPane.activeTab
            let currentFile = tab.files.isEmpty ? "" : tab.files[safe: tab.cursorIndex]?.name ?? ""
            return "\(tab.drive.name) | \(currentFile)"
        }
    }
    
    // MARK: - 面板操作
    
    /// 切换活动面板
    func toggleActivePane() {
        activePane = activePane.opposite
    }
    
    /// 设置活动面板
    func setActivePane(_ side: PaneSide) {
        activePane = side
    }
    
    // MARK: - 模式操作
    
    /// 进入模式
    func enterMode(_ newMode: AppMode) {
        previousMode = mode
        mode = newMode
        
        switch newMode {
        case .command:
            commandInput = ""
        case .filter:
            filterInput = ""
        case .visual:
            // 进入 Visual 模式时选中当前文件
            currentPane.selectCurrentFile()
        case .driveSelect:
            showDriveSelector = true
            driveSelectorCursor = 0
        default:
            break
        }
    }
    
    /// 退出当前模式，返回 Normal
    func exitMode() {
        if mode == .driveSelect {
            showDriveSelector = false
        }
        mode = .normal
        commandInput = ""
        filterInput = ""
    }
    
    // MARK: - Toast 通知
    
    /// 显示 Toast 消息
    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
    
    // MARK: - 剪贴板操作
    
    /// 复制选中的文件
    func yankSelectedFiles() {
        let selections = currentPane.selections
        if selections.isEmpty {
            // 如果没有选择，复制当前光标文件
            if let file = currentPane.currentFiles[safe: currentPane.cursorIndex] {
                clipboard = [file]
            }
        } else {
            clipboard = currentPane.currentFiles.filter { selections.contains($0.id) }
        }
        clipboardOperation = .copy
        showToast("\(clipboard.count) file(s) yanked")
    }
    
    /// 剪切选中的文件
    func cutSelectedFiles() {
        yankSelectedFiles()
        clipboardOperation = .cut
        showToast("\(clipboard.count) file(s) cut")
    }
}

/// 剪贴板操作类型
enum ClipboardOperation {
    case copy
    case cut
}

// MARK: - 安全数组访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
