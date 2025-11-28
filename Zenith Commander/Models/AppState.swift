//
//  AppState.swift
//  Zenith Commander
//
//  全局应用状态管理 (使用 ObservableObject + Combine)
//

import Foundation
import SwiftUI
import Combine

/// 标签页状态
class TabState: Identifiable, ObservableObject {
    let id: UUID
    var drive: DriveInfo
    @Published var currentPath: URL
    @Published var files: [FileItem]
    @Published var cursorFileId: String
    @Published var scrollOffset: CGFloat
    
    /// 未过滤的原始文件列表（用于 Filter 模式恢复）
    var unfilteredFiles: [FileItem] = []
    
    /// 当前光标在本 Tab 中对应的索引（基于 cursorFileId 计算）
    /// 如果找不到对应文件，则返回 nil
    var cursorIndexInTab: Int? {
        files.firstIndex(where: { $0.id == cursorFileId })
    }
    
    init(drive: DriveInfo, path: URL) {
        self.id = UUID()
        self.drive = drive
        self.currentPath = path
        self.files = []
        self.scrollOffset = 0
        self.cursorFileId = ".."
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
class PaneState: ObservableObject {
    var side: PaneSide
    @Published var tabs: [TabState]
    @Published var activeTabIndex: Int
    @Published var viewMode: ViewMode
    @Published var selections: Set<String> // 存储选中的文件 ID
    var visualAnchor: Int? // Visual 模式的锚点位置
    
    private var tabCancellables: [UUID: AnyCancellable] = [:]
    
    init(side: PaneSide, initialPath: URL, drive: DriveInfo) {
        self.side = side
        self.tabs = [TabState(drive: drive, path: initialPath)]
        self.activeTabIndex = 0
        self.viewMode = .list
        self.selections = []
        self.visualAnchor = nil
        
        // 订阅初始标签页的变化
        subscribeToTabChanges()
    }
    
    /// 订阅所有标签页的变化，转发到 PaneState
    private func subscribeToTabChanges() {
        tabCancellables.removeAll()
        for tab in tabs {
            let cancellable = tab.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            tabCancellables[tab.id] = cancellable
        }
    }
    
    /// 当前活动标签页
    var activeTab: TabState {
        tabs[activeTabIndex]
    }
    
    /// 当前文件列表
    var currentFiles: [FileItem] {
        activeTab.files
    }
    
    /// 当前光标指向的文件 ID（单一真实来源）
    var cursorFileId: String {
        get { activeTab.cursorFileId }
        set { activeTab.cursorFileId = newValue }
    }
    
    /// 当前光标位置（基于 cursorFileId 计算）
    /// 如果找不到对应文件，则返回 0；设置时会更新 cursorFileId
    var cursorIndex: Int {
        get {
            if let idx = activeTab.files.firstIndex(where: { $0.id == activeTab.cursorFileId }) {
                return idx
            } else {
                return 0
            }
        }
        set {
            guard !activeTab.files.isEmpty else { return }
            let clamped = max(0, min(newValue, activeTab.files.count - 1))
            if activeTab.files.indices.contains(clamped) {
                activeTab.cursorFileId = activeTab.files[clamped].id
            }
        }
    }
    
    
    /// 添加新标签页
    func addTab(path: URL? = nil, drive: DriveInfo? = nil) {
        let newDrive = drive ?? activeTab.drive
        let newPath = path ?? activeTab.currentPath
        let newTab = TabState(drive: newDrive, path: newPath)
        tabs.append(newTab)
        activeTabIndex = tabs.count - 1
        
        // 订阅新标签页的变化
        let cancellable = newTab.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        tabCancellables[newTab.id] = cancellable
    }
    
    /// 关闭标签页
    func closeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        let removedTab = tabs[index]
        tabCancellables.removeValue(forKey: removedTab.id)
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
class AppState: ObservableObject {
    // MARK: - 面板状态
    @Published var leftPane: PaneState
    @Published var rightPane: PaneState
    @Published var activePane: PaneSide = .left
    
    // MARK: - 订阅管理
    private var paneCancellables: Set<AnyCancellable> = []
    
    // MARK: - 模态状态
    @Published var mode: AppMode = .normal
    var previousMode: AppMode = .normal
    
    // MARK: - 输入状态
    @Published var commandInput: String = ""
    @Published var filterInput: String = ""
    @Published var filterUseRegex: Bool = false
    @Published var inputBuffer: String = ""
    
    // MARK: - 剪贴板
    @Published var clipboard: [FileItem] = []
    @Published var clipboardOperation: ClipboardOperation = .copy
    
    // MARK: - UI 状态
    @Published var toastMessage: String?
    @Published var showDriveSelector: Bool = false
    @Published var driveSelectorCursor: Int = 0
    @Published var availableDrives: [DriveInfo] = []
    
    // MARK: - AI 状态
    @Published var aiResult: String = ""
    @Published var isAiLoading: Bool = false
    
    // MARK: - 批量重命名状态
    @Published var showRenameModal: Bool = false
    @Published var renameFindText: String = ""
    @Published var renameReplaceText: String = ""
    @Published var renameUseRegex: Bool = false
    
    // MARK: - 右键菜单状态
    @Published var contextMenuPosition: CGPoint?
    @Published var contextMenuFile: FileItem?
    
    init(testDirectory: URL? = nil) {
        // 获取默认驱动器
        let defaultDrive = DriveInfo(
            id: "macintosh-hd",
            name: "Macintosh HD",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 0,
            availableCapacity: 0
        )
        
        // 如果提供了测试目录，使用测试目录；否则使用用户主目录
        if let testDir = testDirectory {
            leftPane = PaneState(side: .left, initialPath: testDir, drive: defaultDrive)
            rightPane = PaneState(side: .right, initialPath: testDir, drive: defaultDrive)
        } else {
            // 初始化面板，默认路径为用户主目录
            // TODO 这里可以从配置文件中读取，如果没有配置则使用默认路径，两边默认都应该使用home目录
            /// 应该记录上次使用的路径吧，其他的软件都是这样做的
            ///
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            leftPane = PaneState(side: .left, initialPath: homePath, drive: defaultDrive)
            rightPane = PaneState(side: .right, initialPath: homePath.appendingPathComponent("Downloads"), drive: defaultDrive)
        }
        
        // 订阅两个面板的变化，转发到 AppState
        subscribeToPaneChanges()
    }
    
    /// 订阅面板状态变化
    private func subscribeToPaneChanges() {
        leftPane.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &paneCancellables)
        
        rightPane.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &paneCancellables)
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
            let prefix = filterUseRegex ? "/regex: " : "/"
            return "\(prefix)\(filterInput)"
        default:
            let pane = currentPane
            let tab = pane.activeTab
            let currentFile = tab.files.isEmpty ? "" : tab.files[safe: pane.cursorIndex]?.name ?? ""
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
        // 退出 Filter 模式时，恢复未过滤的文件列表
        if mode == .filter {
            restoreUnfilteredFiles()
        }
        mode = .normal
        commandInput = ""
        filterInput = ""
        filterUseRegex = false
    }
    
    /// 恢复未过滤的文件列表
    func restoreUnfilteredFiles() {
        let tab = currentPane.activeTab
        if !tab.unfilteredFiles.isEmpty {
            tab.files = tab.unfilteredFiles
            tab.unfilteredFiles = []
            currentPane.cursorIndex = min(currentPane.cursorIndex, tab.files.count - 1)
            if currentPane.cursorIndex < 0 {
                currentPane.cursorIndex = 0
            }
        }
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
