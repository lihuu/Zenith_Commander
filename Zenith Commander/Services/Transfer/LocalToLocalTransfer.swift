//
//  LocalToLocalTransfer.swift
//  Zenith Commander
//
//  本地文件系统之间的传输处理
//

import Foundation
import os.log

/// 本地文件系统之间的传输处理器
struct LocalToLocalTransfer: FileTransferHandler {
    
    private let fileManager = FileManager.default
    
    func canHandle(source: URL, destination: URL) -> Bool {
        source.isLocal && destination.isLocal
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
        
        // 使用 LocalFileSystemProvider 以支持撤销
        let provider = LocalFileSystemProvider()
        provider.undoManager = undoManager
        
        for source in sources {
            do {
                // 验证源文件存在
                guard fileManager.fileExists(atPath: source.path) else {
                    throw TransferError.sourceNotFound(source)
                }
                
                // 转换 URL 为 FileItem
                guard let item = FileItem.fromURL(source) else {
                    throw TransferError.sourceNotFound(source)
                }
                
                // 判断是否同目录（同目录只能复制）
                let isSameDirectory = source.deletingLastPathComponent() == destination
                let shouldCopy = operation == .copy || isSameDirectory
                
                if shouldCopy {
                    try await provider.copy(items: [item], to: destination)
                } else {
                    try await provider.move(items: [item], to: destination)
                }
                
                successCount += 1
                Logger.fileSystem.debug(
                    "Local transfer success: \(source.lastPathComponent) -> \(destination.path)"
                )
            } catch {
                Logger.fileSystem.error(
                    "Local transfer failed for \(source.lastPathComponent): \(error.localizedDescription)"
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
}

