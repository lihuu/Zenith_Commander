//
//  TabState.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/2/25.
//
import Combine
import Foundation
import SwiftUI

class TabState: Identifiable, ObservableObject {
    let id: UUID
    var drive: DriveInfo
    @Published var currentPath: URL
    @Published var cursorFileId: String
    @Published var scrollOffset: CGFloat
    @Published var sortOption: SortOption = .default
    
    /// 原始文件列表（内部存储）
    @Published private var _rawFiles: [FileItem] = []
    
    /// 文件列表（对外访问时返回排序后的列表）
    var files: [FileItem] {
        get { sortOption.sort(_rawFiles) }
        set { _rawFiles = newValue }
    }

    var isRemotePath: Bool {
        !currentPath.isFileURL
    }

    var isLocalPath: Bool {
        currentPath.isFileURL
    }

    /// 未过滤的原始文件列表（用于 Filter 模式恢复）
    var unfilteredFiles: [FileItem] = []

    /// 当前光标在本 Tab 中对应的索引（基于 cursorFileId 计算）
    /// 如果找不到对应文件，则返回 nil
    var cursorIndexInTab: Int? {
        files.firstIndex(where: { $0.id == self.cursorFileId })
    }

    init(drive: DriveInfo, path: URL) {
        id = UUID()
        self.drive = drive
        currentPath = path
        _rawFiles = []
        scrollOffset = 0
        cursorFileId = ""  // 空字符串表示无高亮
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

extension TabState {
    static func stub(
        drive: DriveInfo,
        path: URL,
        files: [FileItem] = [],
        cursorFileId: String = ".."
    ) -> TabState {
        let tab = TabState(drive: drive, path: path)
        tab.files = files
        tab.cursorFileId = cursorFileId
        return tab
    }
}

extension TabState {
    func applyFilter(_ filter: String, useRegex: Bool) {
        // 首次过滤时保存原始文件列表
        if unfilteredFiles.isEmpty, !files.isEmpty {
            unfilteredFiles = files
        }

        if filter.isEmpty {
            if !unfilteredFiles.isEmpty {
                files = unfilteredFiles
            }
            return
        }

        let sourceFiles = unfilteredFiles.isEmpty ? files : unfilteredFiles

        if useRegex {
            do {
                let regex = try NSRegularExpression(
                    pattern: filter,
                    options: [.caseInsensitive]
                )
                files = sourceFiles.filter { file in
                    let range = NSRange(
                        file.name.startIndex...,
                        in: file.name
                    )
                    return regex.firstMatch(
                        in: file.name,
                        options: [],
                        range: range
                    ) != nil
                }
            } catch {
                files = sourceFiles
            }
        } else {
            let lowerFilter = filter.lowercased()
            files = sourceFiles.filter {
                $0.name.lowercased().contains(lowerFilter)
            }
        }
    }

    func resetFilter() {
        unfilteredFiles = []
    }
}
