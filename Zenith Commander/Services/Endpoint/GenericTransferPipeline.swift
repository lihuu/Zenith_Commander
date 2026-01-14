//
//  GenericTransferPipeline.swift
//  Zenith Commander
//
//  Generic transfer pipeline for cross-protocol file transfers.
//  Uses FileOps streaming interface - no N×N implementations needed.
//

import Foundation
import os.log

/// Transfer operation result
struct TransferPipelineResult {
    let successCount: Int
    let failedCount: Int
    let errors: [Error]
    
    static var empty: TransferPipelineResult {
        TransferPipelineResult(successCount: 0, failedCount: 0, errors: [])
    }
    
    static func success(count: Int) -> TransferPipelineResult {
        TransferPipelineResult(successCount: count, failedCount: 0, errors: [])
    }
    
    static func failure(errors: [Error]) -> TransferPipelineResult {
        TransferPipelineResult(successCount: 0, failedCount: errors.count, errors: errors)
    }
    
    func merged(with other: TransferPipelineResult) -> TransferPipelineResult {
        TransferPipelineResult(
            successCount: successCount + other.successCount,
            failedCount: failedCount + other.failedCount,
            errors: errors + other.errors
        )
    }
}

/// Progress callback for transfers
typealias TransferPipelineProgress = (_ current: Int64, _ total: Int64) -> Bool

/// Generic transfer pipeline
/// Transfers files between any two FileOps implementations using streaming.
/// No protocol-specific knowledge required.
class GenericTransferPipeline {
    
    /// Transfer a file from source to destination using streaming
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination directory path
    ///   - sourceOps: Source FileOps
    ///   - destOps: Destination FileOps
    ///   - progress: Optional progress callback
    func transferFile(
        from source: PathRef,
        to destination: PathRef,
        progress: TransferPipelineProgress? = nil
    ) async throws {
        let sourceOps = source.ops
        let destOps = destination.ops
        
        // Create destination file path
        let destFile = destination.appending(source.name)
        
        // Stream from source to destination
        let dataStream = try await sourceOps.read(from: source.url)
        try await destOps.write(to: destFile.url, data: dataStream)
        
        Logger.fileSystem.debug(
            "Pipeline transfer: \(source.url.lastPathComponent) -> \(destFile.url.path)"
        )
    }
    
    /// Transfer multiple items (files and directories)
    /// - Parameters:
    ///   - sources: Source paths
    ///   - destination: Destination directory
    ///   - isMove: If true, delete source after successful transfer
    ///   - progress: Optional progress callback
    func transfer(
        sources: [PathRef],
        to destination: PathRef,
        isMove: Bool = false,
        progress: TransferPipelineProgress? = nil
    ) async throws -> TransferPipelineResult {
        var successCount = 0
        var errors: [Error] = []
        
        for source in sources {
            do {
                // Check if source is directory
                let items = try? await source.ops.list(at: source.url)
                let isDirectory = items != nil && !items!.isEmpty
                
                if isDirectory {
                    // Recursively transfer directory
                    try await transferDirectory(
                        from: source,
                        to: destination,
                        isMove: isMove,
                        progress: progress
                    )
                } else {
                    // Transfer single file
                    try await transferFile(
                        from: source,
                        to: destination,
                        progress: progress
                    )
                }
                
                // If move, delete source
                if isMove {
                    try await source.ops.delete(at: source.url)
                }
                
                successCount += 1
            } catch {
                Logger.fileSystem.error(
                    "Pipeline transfer failed for \(source.url.lastPathComponent): \(error.localizedDescription)"
                )
                errors.append(error)
            }
        }
        
        return TransferPipelineResult(
            successCount: successCount,
            failedCount: errors.count,
            errors: errors
        )
    }
    
    /// Recursively transfer a directory
    private func transferDirectory(
        from source: PathRef,
        to destination: PathRef,
        isMove: Bool,
        progress: TransferPipelineProgress?
    ) async throws {
        // Create destination directory
        let destDir = try await destination.ops.createDirectory(
            at: destination.url,
            name: source.name
        )
        let destDirRef = destination.appending(source.name)
        
        // List source contents
        let items = try await source.ops.list(at: source.url)
        
        for item in items {
            // Skip parent directory entries
            if item.name == ".." { continue }
            
            let itemSource = source.appending(item.name)
            
            if item.isFolder {
                try await transferDirectory(
                    from: itemSource,
                    to: destDirRef,
                    isMove: isMove,
                    progress: progress
                )
            } else {
                try await transferFile(
                    from: itemSource,
                    to: destDirRef,
                    progress: progress
                )
            }
        }
    }
}
