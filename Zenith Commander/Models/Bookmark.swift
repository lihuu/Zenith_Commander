//
//  Bookmark.swift
//  Zenith Commander
//
//  书签数据模型和管理器
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - 书签数据模型

/// 书签项
struct BookmarkItem: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID
    
    /// 书签名称（显示名）
    var name: String
    
    /// 书签路径
    let path: URL
    
    /// 书签类型
    let type: BookmarkType
    
    /// 图标名称
    var iconName: String
    
    /// 创建时间
    let createdAt: Date
    
    /// 书签类型枚举
    enum BookmarkType: String, Codable {
        case file
        case folder
    }
    
    /// 初始化
    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        type: BookmarkType,
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
        let type: BookmarkType = fileItem.type == .folder ? .folder : .file
        
        return BookmarkItem(
            name: fileItem.name,
            path: fileItem.path,
            type: type,
            iconName: fileItem.iconName
        )
    }
    
    /// 检查书签目标是否存在
    var exists: Bool {
        FileManager.default.fileExists(atPath: path.path)
    }
}

// MARK: - 书签管理器

/// 书签管理器 - 负责书签的增删改查和持久化
class BookmarkManager: ObservableObject {
    
    /// 单例
    static let shared = BookmarkManager()
    
    /// 书签列表
    @Published var bookmarks: [BookmarkItem] = []
    
    /// 书签文件路径
    private var bookmarksFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ZenithCommander")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent("bookmarks.json")
    }
    
    /// 初始化 - 公开以允许在测试中使用
    init() {
        loadBookmarks()
    }
    
    // MARK: - 公共方法
    
    /// 添加书签
    func add(_ bookmark: BookmarkItem) {
        // 检查是否已存在相同路径的书签
        guard !bookmarks.contains(where: { $0.path == bookmark.path }) else {
            Logger.app.info("Bookmark already exists for path: \(bookmark.path.path)")
            return
        }
        
        bookmarks.append(bookmark)
        saveBookmarks()
        Logger.app.info("Added bookmark: \(bookmark.name)")
    }
    
    /// 从 FileItem 添加书签
    func addBookmark(for fileItem: FileItem) {
        let bookmark = BookmarkItem.from(fileItem: fileItem)
        add(bookmark)
    }
    
    /// 删除书签
    func remove(_ bookmark: BookmarkItem) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
        Logger.app.info("Removed bookmark: \(bookmark.name)")
    }
    
    /// 删除书签（通过路径）
    func remove(path: URL) {
        bookmarks.removeAll { $0.path == path }
        saveBookmarks()
        Logger.app.info("Removed bookmark for path: \(path.path)")
    }
    
    /// 检查路径是否已收藏
    func contains(path: URL) -> Bool {
        bookmarks.contains { $0.path == path }
    }
    
    /// 切换书签状态
    func toggleBookmark(for fileItem: FileItem) {
        if contains(path: fileItem.path) {
            remove(path: fileItem.path)
        } else {
            addBookmark(for: fileItem)
        }
    }
    
    /// 重新排序
    func reorder(from source: IndexSet, to destination: Int) {
        bookmarks.move(fromOffsets: source, toOffset: destination)
        saveBookmarks()
    }
    
    /// 清空所有书签
    func clearAll() {
        bookmarks.removeAll()
        saveBookmarks()
        Logger.app.info("Cleared all bookmarks")
    }
    
    /// 清理不存在的书签
    func cleanupInvalidBookmarks() {
        let validBookmarks = bookmarks.filter { $0.exists }
        if validBookmarks.count != bookmarks.count {
            let removedCount = bookmarks.count - validBookmarks.count
            bookmarks = validBookmarks
            saveBookmarks()
            Logger.app.info("Cleaned up \(removedCount) invalid bookmarks")
        }
    }
    
    // MARK: - 持久化
    
    /// 加载书签
    private func loadBookmarks() {
        guard FileManager.default.fileExists(atPath: bookmarksFileURL.path) else {
            Logger.app.debug("No bookmarks file found, starting with empty list")
            return
        }
        
        do {
            let data = try Data(contentsOf: bookmarksFileURL)
            let decoder = JSONDecoder()
            bookmarks = try decoder.decode([BookmarkItem].self, from: data)
            Logger.app.info("Loaded \(self.bookmarks.count) bookmarks")
        } catch {
            Logger.app.error("Failed to load bookmarks: \(error.localizedDescription)")
        }
    }
    
    /// 保存书签
    private func saveBookmarks() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(bookmarks)
            try data.write(to: bookmarksFileURL)
            Logger.app.debug("Saved \(self.bookmarks.count) bookmarks")
        } catch {
            Logger.app.error("Failed to save bookmarks: \(error.localizedDescription)")
        }
    }
}
