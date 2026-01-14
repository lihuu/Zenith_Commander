//
//  SFTPToLocalTransfer.swift
//  Zenith Commander
//
//  SFTP 文件下载到本地的传输处理
//

import Foundation
import mft
import os.log

/// SFTP 文件下载到本地的传输处理器
struct SFTPToLocalTransfer: FileTransferHandler {
    
    private let fileManager = FileManager.default
    
    func canHandle(source: URL, destination: URL) -> Bool {
        source.isSFTP && destination.isLocal
    }
    
    func transfer(
        sources: [URL],
        to destination: URL,
        operation: TransferOperation,
        undoManager: UndoManager?,
        progress: TransferProgressHandler?
    ) async throws -> TransferResult {
        // 验证目标是目录
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw TransferError.destinationNotDirectory(destination)
        }
        
        var successCount = 0
        var errors: [Error] = []
        
        // 获取 SFTP 提供者
        let sftpProvider = SFTPFileSystemProvider()
        
        for source in sources {
            do {
                try await downloadItem(
                    source: source,
                    to: destination,
                    sftpProvider: sftpProvider,
                    operation: operation,
                    progress: progress
                )
                successCount += 1
            } catch {
                Logger.fileSystem.error(
                    "Download failed for \(source.lastPathComponent): \(error.localizedDescription)"
                )
                errors.append(error)
            }
        }
        
        return TransferResult(
            successCount: successCount,
            failedCount: errors.count,
            errors: errors
        )
    }
    
    /// 下载单个项目（文件或文件夹）
    private func downloadItem(
        source: URL,
        to destination: URL,
        sftpProvider: SFTPFileSystemProvider,
        operation: TransferOperation,
        progress: TransferProgressHandler?
    ) async throws {
        // 先检查远程项目是否是目录
        let isRemoteDirectory = try await checkIsDirectory(
            source: source,
            sftpProvider: sftpProvider
        )
        
        let localPath = destination.appendingPathComponent(source.lastPathComponent)
        let uniqueLocalPath = generateUniqueURL(for: localPath)
        
        if isRemoteDirectory {
            // 递归下载文件夹
            try await downloadDirectory(
                source: source,
                to: uniqueLocalPath,
                sftpProvider: sftpProvider,
                progress: progress
            )
        } else {
            // 下载单个文件
            try await downloadFile(
                source: source,
                to: uniqueLocalPath,
                sftpProvider: sftpProvider,
                progress: progress
            )
        }
        
        // 如果是移动操作，删除远程源文件
        if operation == .move {
            try await deleteRemoteItem(
                source: source,
                sftpProvider: sftpProvider,
                isDirectory: isRemoteDirectory
            )
        }
    }
    
    /// 检查远程路径是否为目录
    private func checkIsDirectory(
        source: URL,
        sftpProvider: SFTPFileSystemProvider
    ) async throws -> Bool {
        // 通过加载目录来判断是否是目录
        // 如果加载成功则是目录，否则是文件
        do {
            _ = try await sftpProvider.loadDirectory(at: source)
            return true
        } catch {
            return false
        }
    }
    
    /// 下载文件夹
    private func downloadDirectory(
        source: URL,
        to destination: URL,
        sftpProvider: SFTPFileSystemProvider,
        progress: TransferProgressHandler?
    ) async throws {
        // 创建本地目录
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // 获取远程目录内容
        let items = try await sftpProvider.loadDirectory(at: source)
        
        for item in items {
            // 跳过父目录项
            if item.name == ".." { continue }
            
            let localItemPath = destination.appendingPathComponent(item.name)
            
            if item.isFolder {
                try await downloadDirectory(
                    source: item.path,
                    to: localItemPath,
                    sftpProvider: sftpProvider,
                    progress: progress
                )
            } else {
                try await downloadFile(
                    source: item.path,
                    to: localItemPath,
                    sftpProvider: sftpProvider,
                    progress: progress
                )
            }
        }
    }
    
    /// 下载单个文件
    private func downloadFile(
        source: URL,
        to destination: URL,
        sftpProvider: SFTPFileSystemProvider,
        progress: TransferProgressHandler?
    ) async throws {
        // 在 Task.detached 之前捕获需要的值
        let sourcePath = source.path
        let destPath = destination.path
        
        try await Task.detached {
            let sftp = try sftpProvider.connection(for: source)
            
            guard let outputStream = OutputStream(url: destination, append: false) else {
                throw TransferError.permissionDenied(destination)
            }
            outputStream.open()
            defer { outputStream.close() }
            
            // 注意：由于 progress 回调可能是 main actor 隔离的，
            // 在 Task.detached 中不使用它以避免数据竞争
            try sftp.contents(
                atPath: sourcePath,
                toStream: outputStream,
                fromPosition: 0
            ) { _, _ in
                true // 始终继续传输
            }
            
            Logger.fileSystem.debug(
                "Downloaded: \(sourcePath) -> \(destPath)"
            )
        }.value
    }
    
    /// 删除远程项目
    private func deleteRemoteItem(
        source: URL,
        sftpProvider: SFTPFileSystemProvider,
        isDirectory: Bool
    ) async throws {
        // 在 Task.detached 之前捕获需要的值
        let sourcePath = source.path
        
        try await Task.detached {
            let sftp = try sftpProvider.connection(for: source)
            
            if isDirectory {
                try sftp.removeDirectory(atPath: sourcePath)
            } else {
                try sftp.removeFile(atPath: sourcePath)
            }
        }.value
    }
    
    /// 生成唯一的目标 URL
    private func generateUniqueURL(for url: URL) -> URL {
        var resultURL = url
        var counter = 1
        
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parentDir = url.deletingLastPathComponent()
        
        while fileManager.fileExists(atPath: resultURL.path) {
            let newName = ext.isEmpty
                ? "\(baseName) \(counter)"
                : "\(baseName) \(counter).\(ext)"
            resultURL = parentDir.appendingPathComponent(newName)
            counter += 1
        }
        
        return resultURL
    }
}
