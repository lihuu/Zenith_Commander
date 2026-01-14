//
//  LocalToSFTPTransfer.swift
//  Zenith Commander
//
//  本地文件上传到 SFTP 的传输处理
//

import Foundation
import mft
import os.log

/// 本地文件上传到 SFTP 的传输处理器
struct LocalToSFTPTransfer: FileTransferHandler {
    
    private let fileManager = FileManager.default
    
    func canHandle(source: URL, destination: URL) -> Bool {
        source.isLocal && destination.isSFTP
    }
    
    func transfer(
        sources: [URL],
        to destination: URL,
        operation: TransferOperation,
        undoManager: UndoManager?,
        progress: TransferProgressHandler?
    ) async throws -> TransferResult {
        var successCount = 0
        var errors: [Error] = []
        
        // 获取 SFTP 提供者
        let sftpProvider = SFTPFileSystemProvider()
        
        for source in sources {
            do {
                try await uploadItem(
                    source: source,
                    to: destination,
                    sftpProvider: sftpProvider,
                    operation: operation,
                    progress: progress
                )
                successCount += 1
            } catch {
                Logger.fileSystem.error(
                    "Upload failed for \(source.lastPathComponent): \(error.localizedDescription)"
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
    
    /// 上传单个项目（文件或文件夹）
    private func uploadItem(
        source: URL,
        to destination: URL,
        sftpProvider: SFTPFileSystemProvider,
        operation: TransferOperation,
        progress: TransferProgressHandler?
    ) async throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw TransferError.sourceNotFound(source)
        }
        
        let destPath = destination.appendingPathComponent(source.lastPathComponent)
        
        if isDirectory.boolValue {
            // 递归上传文件夹
            try await uploadDirectory(
                source: source,
                to: destPath,
                sftpProvider: sftpProvider,
                progress: progress
            )
        } else {
            // 上传单个文件
            try await uploadFile(
                source: source,
                to: destPath,
                sftpProvider: sftpProvider,
                progress: progress
            )
        }
        
        // 如果是移动操作，删除源文件
        if operation == .move {
            try fileManager.removeItem(at: source)
        }
    }
    
    /// 上传文件夹
    private func uploadDirectory(
        source: URL,
        to destination: URL,
        sftpProvider: SFTPFileSystemProvider,
        progress: TransferProgressHandler?
    ) async throws {
        // 先创建远程目录
        _ = try await sftpProvider.createDirectory(
            at: destination.deletingLastPathComponent(),
            name: destination.lastPathComponent
        )
        
        // 递归上传内容
        let contents = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        for item in contents {
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: item.path, isDirectory: &isDir)
            
            if isDir.boolValue {
                try await uploadDirectory(
                    source: item,
                    to: destination.appendingPathComponent(item.lastPathComponent),
                    sftpProvider: sftpProvider,
                    progress: progress
                )
            } else {
                try await uploadFile(
                    source: item,
                    to: destination.appendingPathComponent(item.lastPathComponent),
                    sftpProvider: sftpProvider,
                    progress: progress
                )
            }
        }
    }
    
    /// 上传单个文件
    private func uploadFile(
        source: URL,
        to destination: URL,
        sftpProvider: SFTPFileSystemProvider,
        progress: TransferProgressHandler?
    ) async throws {
        // 在 Task.detached 之前捕获需要的值
        let destPath = destination.path
        let fileName = source.lastPathComponent
        
        try await Task.detached {
            let sftp = try sftpProvider.connection(for: destination)
            
            guard let inputStream = InputStream(url: source) else {
                throw TransferError.sourceNotFound(source)
            }
            inputStream.open()
            defer { inputStream.close() }
            
            // 注意：由于 progress 回调可能是 main actor 隔离的，
            // 在 Task.detached 中不使用它以避免数据竞争
            try sftp.write(
                stream: inputStream,
                toFileAtPath: destPath,
                append: false
            ) { _ in
                true // 始终继续传输
            }
            
            Logger.fileSystem.debug(
                "Uploaded: \(fileName) -> \(destPath)"
            )
        }.value
    }
}
