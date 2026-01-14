//
//  SFTPToSFTPTransfer.swift
//  Zenith Commander
//
//  SFTP 之间的传输处理（同服务器/跨服务器）
//

import Foundation
import mft
import os.log

/// SFTP 之间的传输处理器
struct SFTPToSFTPTransfer: FileTransferHandler {
    
    private let fileManager = FileManager.default
    
    func canHandle(source: URL, destination: URL) -> Bool {
        source.isSFTP && destination.isSFTP
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
        
        for source in sources {
            do {
                // 检查是否是同一个服务器
                if isSameServer(source: source, destination: destination) {
                    try await transferSameServer(
                        source: source,
                        to: destination,
                        operation: operation
                    )
                } else {
                    // 跨服务器：通过本地临时目录中转
                    try await transferCrossServer(
                        source: source,
                        to: destination,
                        operation: operation,
                        progress: progress
                    )
                }
                successCount += 1
            } catch {
                Logger.fileSystem.error(
                    "SFTP transfer failed for \(source.lastPathComponent): \(error.localizedDescription)"
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
    
    /// 检查两个 URL 是否指向同一个 SFTP 服务器
    private func isSameServer(source: URL, destination: URL) -> Bool {
        guard let sourceHost = source.host,
              let destHost = destination.host else {
            return false
        }
        
        let sourcePort = source.port ?? 22
        let destPort = destination.port ?? 22
        
        return sourceHost == destHost && sourcePort == destPort
    }
    
    /// 同服务器传输（使用 SFTP 的 copy/move）
    private func transferSameServer(
        source: URL,
        to destination: URL,
        operation: TransferOperation
    ) async throws {
        let sftpProvider = SFTPFileSystemProvider()
        let destPath = destination.appendingPathComponent(source.lastPathComponent)
        
        // 在 Task.detached 之前捕获需要的值
        let sourcePath = source.path
        let destPathStr = destPath.path
        let isCopy = operation == .copy
        
        try await Task.detached {
            let sftp = try sftpProvider.connection(for: source)
            
            if isCopy {
                try sftp.copyItem(
                    atPath: sourcePath,
                    toFileAtPath: destPathStr,
                    progress: nil
                )
            } else {
                try sftp.moveItem(
                    atPath: sourcePath,
                    toPath: destPathStr
                )
            }
            
            Logger.fileSystem.debug(
                "SFTP same-server \(isCopy ? "copy" : "move"): \(sourcePath) -> \(destPathStr)"
            )
        }.value
    }
    
    /// 跨服务器传输（通过临时目录中转）
    private func transferCrossServer(
        source: URL,
        to destination: URL,
        operation: TransferOperation,
        progress: TransferProgressHandler?
    ) async throws {
        // 创建临时目录
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("sftp_transfer_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 1. 从源 SFTP 下载到临时目录
        let sftpToLocal = SFTPToLocalTransfer()
        let downloadResult = try await sftpToLocal.transfer(
            sources: [source],
            to: tempDir,
            operation: operation == .move ? .move : .copy,
            undoManager: nil,
            progress: progress
        )
        
        guard downloadResult.failedCount == 0 else {
            throw downloadResult.errors.first ?? TransferError.sourceNotFound(source)
        }
        
        // 2. 从临时目录上传到目标 SFTP
        let localFile = tempDir.appendingPathComponent(source.lastPathComponent)
        let localToSFTP = LocalToSFTPTransfer()
        let uploadResult = try await localToSFTP.transfer(
            sources: [localFile],
            to: destination,
            operation: .move, // 总是移动临时文件
            undoManager: nil,
            progress: progress
        )
        
        guard uploadResult.failedCount == 0 else {
            throw uploadResult.errors.first ?? TransferError.permissionDenied(destination)
        }
        
        Logger.fileSystem.debug(
            "SFTP cross-server transfer completed: \(source.path) -> \(destination.path)"
        )
    }
}
