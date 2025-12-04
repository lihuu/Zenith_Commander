//
//  PaneState.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/2/25.
//

import Combine
import Foundation
import SwiftUI

class PaneState: ObservableObject {
    var side: PaneSide
    @Published var tabs: [TabState]
    @Published var activeTabIndex: Int
    @Published var viewMode: ViewMode
    @Published var selections: Set<String>  // 存储选中的文件 ID
    @Published var gitInfo: GitRepositoryInfo? = nil  // Git 仓库信息
    var visualAnchor: Int?  // Visual 模式的锚点位置

    /// Grid View 每行的列数（用于键盘导航）
    var gridColumnCount: Int = 4

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
            if let idx = activeTab.files.firstIndex(where: {
                $0.id == activeTab.cursorFileId
            }) {
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
        // 父目录项 (..) 不能被选中
        if fileId == ".." { return }

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
        // 父目录项 (..) 不能被选中
        guard !file.isParentDirectory else { return }
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
                let file = files[i]
                // 父目录项 (..) 不能被选中
                if !file.isParentDirectory {
                    selections.insert(file.id)
                }
            }
        }
    }
    
    func refreshActiveTab() async{
        let files = await FileSystemService.shared.loadDirectory(
            at: activeTab.currentPath
        )
        activeTab.files = files
    }
    
}
