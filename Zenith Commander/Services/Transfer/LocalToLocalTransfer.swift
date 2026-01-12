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
        
        for source in sources {
            do {
                // 验证源文件存在
                guard fileManager.fileExists(atPath: source.path) else {
                    throw TransferError.sourceNotFound(source)
                }
                
                // 目标路径
                let destURL = destination.appendingPathComponent(source.lastPathComponent)
                let uniqueDestURL = generateUniqueURL(for: destURL)
                
                // 判断是否同目录（同目录只能复制）
                let isSameDirectory = source.deletingLastPathComponent() == destination
                let shouldCopy = operation == .copy || isSameDirectory
                
                if shouldCopy {
                    try fileManager.copyItem(at: source, to: uniqueDestURL)
                } else {
                    try fileManager.moveItem(at: source, to: uniqueDestURL)
                }
                
                successCount += 1
                Logger.fileSystem.debug(
                    "Local transfer success: \(source.lastPathComponent) -> \(uniqueDestURL.path)"
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
    
    /// 生成唯一的目标 URL（如果已存在同名文件）
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
