//
//  FileTransferService.swift
//  Zenith Commander
//
//  文件传输服务 - 管理跨协议传输
//

import Foundation
import os.log

/// 文件传输服务
/// 管理和路由跨协议的文件传输操作
class FileTransferService {
    static let shared = FileTransferService()
    
    private var handlers: [FileTransferHandler] = []
    
    init() {
        // 注册默认处理器（按优先级顺序）
        // 更具体的处理器应该先注册
        register(SFTPToSFTPTransfer())
        register(SFTPToLocalTransfer())
        register(LocalToSFTPTransfer())
        register(LocalToLocalTransfer())
    }
    
    /// 注册传输处理器
    func register(_ handler: FileTransferHandler) {
        handlers.append(handler)
    }
    
    /// 查找能处理指定传输的处理器
    /// - Parameters:
    ///   - source: 源文件 URL
    ///   - destination: 目标目录 URL
    /// - Returns: 能处理的传输处理器，如果没有则返回 nil
    func findHandler(for source: URL, to destination: URL) -> FileTransferHandler? {
        handlers.first { $0.canHandle(source: source, destination: destination) }
    }
    
    /// 执行传输（自动选择合适的处理器）
    /// - Parameters:
    ///   - sources: 源文件 URL 列表
    ///   - destination: 目标目录 URL
    ///   - operation: 传输操作类型
    ///   - undoManager: 撤销管理器（可选，用于本地操作的撤销支持）
    ///   - progress: 进度回调（可选）
    /// - Returns: 传输结果
    func transfer(
        sources: [URL],
        to destination: URL,
        operation: TransferOperation,
        undoManager: UndoManager? = nil,
        progress: TransferProgressHandler? = nil
    ) async throws -> TransferResult {
        guard !sources.isEmpty else {
            return .empty
        }
        
        // 按协议类型分组源文件
        var groupedSources: [String: [URL]] = [:]
        for source in sources {
            let key = source.scheme ?? "file"
            groupedSources[key, default: []].append(source)
        }
        
        var finalResult = TransferResult.empty
        
        // 对每组执行传输
        for (_, urls) in groupedSources {
            guard let firstURL = urls.first else { continue }
            
            // 查找处理器
            guard let handler = findHandler(for: firstURL, to: destination) else {
                Logger.fileSystem.error(
                    "No handler found for transfer from \(firstURL.scheme ?? "file") to \(destination.scheme ?? "file")"
                )
                let error = TransferError.unsupportedTransfer(
                    sourceScheme: firstURL.scheme ?? "file",
                    destinationScheme: destination.scheme ?? "file"
                )
                finalResult = finalResult.merged(with: .failure(errors: [error]))
                continue
            }
            
            do {
                let result = try await handler.transfer(
                    sources: urls,
                    to: destination,
                    operation: operation,
                    undoManager: undoManager,
                    progress: progress
                )
                finalResult = finalResult.merged(with: result)
            } catch {
                Logger.fileSystem.error(
                    "Transfer failed: \(error.localizedDescription)"
                )
                finalResult = finalResult.merged(with: .failure(errors: [error]))
            }
        }
        
        return finalResult
    }
}

// MARK: - Transfer Errors

enum TransferError: LocalizedError {
    case unsupportedTransfer(sourceScheme: String, destinationScheme: String)
    case destinationNotDirectory(URL)
    case sourceNotFound(URL)
    case permissionDenied(URL)
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedTransfer(let source, let dest):
            return "Unsupported transfer from \(source) to \(dest)"
        case .destinationNotDirectory(let url):
            return "Destination is not a directory: \(url.lastPathComponent)"
        case .sourceNotFound(let url):
            return "Source not found: \(url.lastPathComponent)"
        case .permissionDenied(let url):
            return "Permission denied: \(url.lastPathComponent)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}
