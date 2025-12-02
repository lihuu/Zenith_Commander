//
//  TabState.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/2/25.
//
import Combine
import SwiftUI

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
        currentPath.lastPathComponent.isEmpty
            ? drive.name : currentPath.lastPathComponent
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
