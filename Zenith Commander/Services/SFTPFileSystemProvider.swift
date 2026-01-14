//
//  SFTPFileSystemProvider.swift
//  Zenith Commander
//
//  SFTP file system provider - bridges to Endpoint architecture
//  All methods internally delegate to SFTPEndpoint/SFTPFileOps
//
//  Note: SFTPEndpoint is the low-level API, this provider calls it.
//

import AppKit
import Foundation
import mft
import os.log

/// SFTP 文件系统提供者
/// 现在内部使用 Endpoint 架构实现
class SFTPFileSystemProvider: FileSystemProvider {
    var scheme: String { "sftp" }
    
    // MARK: - Endpoint Access
    
    /// Get SFTPEndpoint from registry
    @MainActor
    private func getEndpoint(for url: URL) -> SFTPEndpoint? {
        EndpointRegistry.shared.resolve(for: url) as? SFTPEndpoint
    }
    
    /// Get FileOps from endpoint
    @MainActor
    private func getOps(for url: URL) -> FileOps? {
        getEndpoint(for: url)?.ops
    }
    
    /// Get connection from endpoint (for backward compatibility)
    @MainActor
    func connection(for url: URL) throws -> MFTSftpConnection {
        guard let endpoint = getEndpoint(for: url) else {
            throw NSError(domain: "SFTPFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        return try endpoint.connection(for: url)
    }

    // MARK: - FileSystemProvider Implementation

    @MainActor
    func loadDirectory(at path: URL) async throws -> [FileItem] {
        guard let ops = getOps(for: path) else {
            throw NSError(domain: "SFTPFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        Logger.fileSystem.debug("Loading SFTP directory: \(path.path)")
        
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
        if path.path != "/" && !path.path.isEmpty {
            let parentPath = path.deletingLastPathComponent()
            let parentItem = FileItem.parentDirectoryItem(for: parentPath)
            items.insert(parentItem, at: 0)
        }
        
        return items
    }

    @MainActor
    func createDirectory(at path: URL, name: String) async throws -> FileItem {
        guard let ops = getOps(for: path) else {
            throw NSError(domain: "SFTPFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 使用 Endpoint 创建目录
        let newURL = try await ops.mkdir(at: path, name: name, recursive: false)
        
        // 使用 stat 获取完整信息并转换为 FileItem
        let entry = try await ops.stat(at: newURL)
        return FileItem.fromEntry(entry)
    }

    @MainActor
    func createFile(at path: URL, name: String) async throws -> FileItem {
        guard let ops = getOps(for: path) else {
            throw NSError(domain: "SFTPFileSystemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint available"])
        }
        
        // 使用 Endpoint 创建文件
        let newURL = try await ops.createFile(at: path, name: name)
        
        // 使用 stat 获取完整信息并转换为 FileItem
        let entry = try await ops.stat(at: newURL)
        return FileItem.fromEntry(entry)
    }

    @MainActor
    func delete(items: [FileItem]) async throws {
        guard let first = items.first,
              let ops = getOps(for: first.path) else {
            return
        }
        
        // 循环调用 Endpoint 的 delete 方法（SFTP 没有 trash）
        for item in items {
            try await ops.delete(at: item.path)
        }
    }

    @MainActor
    func move(items: [FileItem], to destination: URL) async throws {
        guard let first = items.first,
              let ops = getOps(for: first.path) else {
            return
        }
        
        // 循环调用 Endpoint 的 rename 方法
        for item in items {
            let destPath = destination.appendingPathComponent(item.name)
            try await ops.rename(from: item.path, to: destPath)
        }
    }

    @MainActor
    func copy(items: [FileItem], to destination: URL) async throws {
        guard let first = items.first,
              let ops = getOps(for: first.path) else {
            return
        }
        
        // 循环调用 Endpoint 的 copy 方法
        for item in items {
            let destPath = destination.appendingPathComponent(item.name)
            try await ops.copy(from: item.path, to: destPath)
        }
    }

    func parentDirectory(of path: URL) -> URL {
        path.deletingLastPathComponent()
    }

    @MainActor
    func openFile(_ file: FileItem) async {
        guard let ops = getOps(for: file.path) else { return }
        
        do {
            try await ops.openFile(at: file.path)
        } catch {
            Logger.fileSystem.error(
                "Failed to open remote file: \(error.localizedDescription)"
            )
        }
    }
}
