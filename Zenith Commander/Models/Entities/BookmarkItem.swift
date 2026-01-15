//
//  BookmarkItem.swift
//  Zenith Commander
//
//  书签数据模型
//

import Foundation
import SwiftUI

// MARK: - 书签数据模型

/// 书签项
struct BookmarkItem: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID

    /// 书签名称（显示名）
    var name: String

    /// 书签路径
    let path: URL

    /// 书签类型（使用 FileType）
    let type: FileType

    /// 图标名称
    var iconName: String

    /// 创建时间
    let createdAt: Date

    /// 初始化
    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        type: FileType,
        iconName: String = "folder.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.iconName = iconName
        self.createdAt = createdAt
    }

    /// 从 FileItem 创建书签
    static func from(fileItem: FileItem) -> BookmarkItem {
        // 如果是父目录项 (..)，使用实际的目录名和标准文件夹图标
        if fileItem.isParentDirectory {
            return BookmarkItem(
                name: fileItem.path.lastPathComponent,
                path: fileItem.path,
                type: .folder,
                iconName: "folder.fill"
            )
        }

        return BookmarkItem(
            name: fileItem.name,
            path: fileItem.path,
            type: fileItem.type,
            iconName: fileItem.iconName
        )
    }

    /// 检查书签目标是否存在
    var exists: Bool {
        FileManager.default.fileExists(atPath: path.path)
    }
}
