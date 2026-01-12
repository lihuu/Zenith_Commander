//
//  FileTransferHandler.swift
//  Zenith Commander
//
//  文件传输处理协议 - 定义跨文件系统拖放操作的统一接口
//

import Foundation

/// 传输操作类型
enum TransferOperation {
    case copy
    case move
}

/// 传输结果
struct TransferResult {
    let successCount: Int
    let failedCount: Int
    let errors: [Error]
    
    static var empty: TransferResult {
        TransferResult(successCount: 0, failedCount: 0, errors: [])
    }
    
    static func success(count: Int) -> TransferResult {
        TransferResult(successCount: count, failedCount: 0, errors: [])
    }
    
    static func failure(errors: [Error]) -> TransferResult {
        TransferResult(successCount: 0, failedCount: errors.count, errors: errors)
    }
    
    func merged(with other: TransferResult) -> TransferResult {
        TransferResult(
            successCount: successCount + other.successCount,
            failedCount: failedCount + other.failedCount,
            errors: errors + other.errors
        )
    }
}

/// 传输进度回调
typealias TransferProgressHandler = (_ current: Int64, _ total: Int64) -> Bool

/// 文件传输处理协议
/// 定义跨文件系统拖放操作的统一接口
protocol FileTransferHandler {
    /// 是否能处理该传输类型
    /// - Parameters:
    ///   - source: 源文件 URL
    ///   - destination: 目标目录 URL
    /// - Returns: 是否能处理
    func canHandle(source: URL, destination: URL) -> Bool
    
    /// 执行传输操作
    /// - Parameters:
    ///   - sources: 源文件 URL 列表
    ///   - destination: 目标目录 URL
    ///   - operation: 传输操作类型（复制/移动）
    ///   - progress: 进度回调（可选）
    /// - Returns: 传输结果
    func transfer(
        sources: [URL],
        to destination: URL,
        operation: TransferOperation,
        progress: TransferProgressHandler?
    ) async throws -> TransferResult
}

// MARK: - Default Implementation

extension FileTransferHandler {
    /// 默认无进度回调的传输方法
    func transfer(
        sources: [URL],
        to destination: URL,
        operation: TransferOperation
    ) async throws -> TransferResult {
        try await transfer(
            sources: sources,
            to: destination,
            operation: operation,
            progress: nil
        )
    }
}

// MARK: - URL Extension for Scheme Detection

extension URL {
    /// 是否为 SFTP URL
    var isSFTP: Bool {
        scheme?.lowercased() == "sftp"
    }
    
    /// 是否为本地文件 URL
    var isLocal: Bool {
        isFileURL || scheme == nil || scheme == "file"
    }
}
