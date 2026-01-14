//
//  LocalFileSystemProvider.swift
//  Zenith Commander
//
//  Local file system provider - bridges to Endpoint architecture
//  All methods internally delegate to LocalEndpoint/LocalFileOps
//

import AppKit
import Foundation

/// 本地文件系统提供者
/// 现在内部使用 Endpoint 架构实现
class LocalFileSystemProvider: FileSystemProvider {
    var scheme: String { "file" }
    weak var undoManager: UndoManager?
    
    // MARK: - Endpoint Access
    
    /// Get LocalEndpoint from registry
    @MainActor
    private func getEndpoint() -> LocalEndpoint? {
        EndpointRegistry.shared.resolve(for: URL(fileURLWithPath: "/")) as? LocalEndpoint
    }
    
    /// Get FileOps from endpoint
    @MainActor
    private func getOps() -> FileOps? {
        getEndpoint()?.ops
    }
    
    // MARK: - FileSystemProvider Implementation
    
    @MainActor
    func loadDirectory(at path: URL) async throws -> [FileItem] {
        guard let ops = getOps() else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1, 
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 使用 Endpoint 的 list 方法获取 FileEntry
        let entries = try await ops.list(at: path)
        
        // 转换为 FileItem
        var items = entries.map { FileItem.fromEntry($0) }
        
        // 排序：文件夹优先，然后按名称
        items.sort { item1, item2 in
            if item1.isFolder && !item2.isFolder { return true }
            if !item1.isFolder && item2.isFolder { return false }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
        
        // 添加父目录项
        if path.standardizedFileURL.path != "/" {
            let parentPath = path.standardizedFileURL.deletingLastPathComponent()
            let parentItem = FileItem.parentDirectoryItem(for: parentPath)
            items.insert(parentItem, at: 0)
        }
        
        return items
    }

    @MainActor
    func createDirectory(at path: URL, name: String) async throws -> FileItem {
        guard let endpoint = getEndpoint() else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 注入 undoManager
        if let undoManager = undoManager {
            endpoint.undoManager = undoManager
        }
        defer { endpoint.undoManager = nil }
        
        // 使用 Endpoint 创建目录
        let newURL = try await endpoint.ops.mkdir(at: path, name: name, recursive: false)
        
        // 使用 stat 获取完整信息并转换为 FileItem
        let entry = try await endpoint.ops.stat(at: newURL)
        return FileItem.fromEntry(entry)
    }

    @MainActor
    func createFile(at path: URL, name: String) async throws -> FileItem {
        guard let endpoint = getEndpoint() else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 注入 undoManager
        if let undoManager = undoManager {
            endpoint.undoManager = undoManager
        }
        defer { endpoint.undoManager = nil }
        
        // 使用 Endpoint 创建文件
        let newURL = try await endpoint.ops.createFile(at: path, name: name)
        
        // 使用 stat 获取完整信息并转换为 FileItem
        let entry = try await endpoint.ops.stat(at: newURL)
        return FileItem.fromEntry(entry)
    }

    @MainActor
    func delete(items: [FileItem]) async throws {
        guard let endpoint = getEndpoint() else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 注入 undoManager
        if let undoManager = undoManager {
            endpoint.undoManager = undoManager
        }
        defer { endpoint.undoManager = nil }
        
        // 循环调用 Endpoint 的 trash 方法
        for item in items {
            try await endpoint.ops.trash(at: item.path)
        }
    }

    @MainActor
    func move(items: [FileItem], to destination: URL) async throws {
        guard let endpoint = getEndpoint() else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 注入 undoManager
        if let undoManager = undoManager {
            endpoint.undoManager = undoManager
        }
        defer { endpoint.undoManager = nil }
        
        guard let localOps = endpoint.ops as? LocalFileOps else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid ops type"])
        }
        
        // 转换 FileItem 到 FileEntry 并调用批量移动
        let entries = items.map { item in
            FileEntry(
                name: item.name,
                url: item.path,
                type: FileEntryType(from: item.type),
                size: item.size,
                modifiedDate: item.modifiedDate,
                createdDate: item.createdDate,
                isHidden: item.isHidden,
                permissions: item.permissions.isEmpty ? nil : item.permissions
            )
        }
        try await localOps.move(items: entries, to: destination)
    }

    @MainActor
    func copy(items: [FileItem], to destination: URL) async throws {
        guard let endpoint = getEndpoint() else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 注入 undoManager
        if let undoManager = undoManager {
            endpoint.undoManager = undoManager
        }
        defer { endpoint.undoManager = nil }
        
        guard let localOps = endpoint.ops as? LocalFileOps else {
            throw NSError(domain: "LocalFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid ops type"])
        }
        
        // 转换 FileItem 到 FileEntry 并调用批量复制
        let entries = items.map { item in
            FileEntry(
                name: item.name,
                url: item.path,
                type: FileEntryType(from: item.type),
                size: item.size,
                modifiedDate: item.modifiedDate,
                createdDate: item.createdDate,
                isHidden: item.isHidden,
                permissions: item.permissions.isEmpty ? nil : item.permissions
            )
        }
        try await localOps.copy(items: entries, to: destination)
    }

    func parentDirectory(of path: URL) -> URL {
        path.deletingLastPathComponent()
    }

    @MainActor
    func openFile(_ file: FileItem) async {
        guard let ops = getOps() else { return }
        try? await ops.openFile(at: file.path)
    }
    
    // MARK: - Helper (for backward compatibility)
    
    func generateUniqueFileName(for fileName: String, in directory: URL) -> String {
        let destURL = directory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: destURL.path) {
            return fileName
        }

        let nameWithoutExtension: String
        let fileExtension: String

        if fileName.contains("."), !fileName.hasPrefix(".") {
            if let lastDotIndex = fileName.lastIndex(of: ".") {
                nameWithoutExtension = String(fileName[..<lastDotIndex])
                fileExtension = String(fileName[lastDotIndex...])
            } else {
                nameWithoutExtension = fileName
                fileExtension = ""
            }
        } else {
            nameWithoutExtension = fileName
            fileExtension = ""
        }

        var counter = 1
        while counter < 10000 {
            let numberedName = "\(nameWithoutExtension) Copy\(counter)\(fileExtension)"
            let numberedURL = directory.appendingPathComponent(numberedName)
            if !FileManager.default.fileExists(atPath: numberedURL.path) {
                return numberedName
            }
            counter += 1
        }
        return fileName
    }
}

