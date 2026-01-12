//
//  BookmarkManager.swift
//  Zenith Commander
//
//  书签管理器 - 负责书签的增删改查和持久化
//

import Combine
import Foundation
import SwiftUI
import os.log

/// 书签管理器 - 负责书签的增删改查和持久化
class BookmarkManager: ObservableObject {
    /// 单例
    static let shared = BookmarkManager()

    /// 书签列表
    @Published var bookmarks: [BookmarkItem] = []

    /// 书签存储目录
    private let storageDirectory: URL

    /// 书签文件路径
    private var bookmarksFileURL: URL {
        storageDirectory.appendingPathComponent("bookmarks.json")
    }

    /// 初始化 - 公开以允许在测试中使用
    /// - Parameter storageDirectory: 可选的存储目录，默认使用 Application Support
    init(storageDirectory: URL? = nil) {
        if let storageDirectory = storageDirectory {
            self.storageDirectory = storageDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            self.storageDirectory = appSupport.appendingPathComponent("ZenithCommander")
        }

        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: self.storageDirectory, withIntermediateDirectories: true)

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
        let validBookmarks = bookmarks.filter(\.exists)
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
        Logger.app.debug("Loading bookmarks from \(self.bookmarksFileURL.path)")
        guard FileManager.default.fileExists(atPath: bookmarksFileURL.path) else {
            Logger.app.debug("No bookmarks file found")
            Logger.app.debug("No bookmarks file found, starting with empty list")
            return
        }

        do {
            let data = try Data(contentsOf: bookmarksFileURL)
            let decoder = JSONDecoder()
            bookmarks = try decoder.decode([BookmarkItem].self, from: data)
            Logger.app.debug("Loaded \(self.bookmarks.count) bookmarks")
            Logger.app.info("Loaded \(self.bookmarks.count) bookmarks")
        } catch {
            Logger.app.error("Failed to load bookmarks: \(error)")
            Logger.app.error("Failed to load bookmarks: \(error.localizedDescription)")
        }
    }

    /// 保存书签
    private func saveBookmarks() {
        Logger.app.debug("Saving \(self.bookmarks.count) bookmarks to \(self.bookmarksFileURL.path)")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(bookmarks)
            try data.write(to: bookmarksFileURL)
            Logger.app.debug("Saved successfully")
            Logger.app.debug("Saved \(self.bookmarks.count) bookmarks")
        } catch {
            Logger.app.error("Failed to save bookmarks: \(error)")
            Logger.app.error("Failed to save bookmarks: \(error.localizedDescription)")
        }
    }
}
