//
//  TransferFastPath.swift
//  Zenith Commander
//
//  Optional fast path for same-endpoint transfers.
//  Falls back to GenericTransferPipeline if not applicable.
//

import Foundation
import os.log

/// Fast path for optimized same-endpoint transfers
/// Used when source and destination are on the same file system
/// and native operations are more efficient than streaming.
class TransferFastPath {
    
    /// Check if fast path is available for this transfer
    func canHandle(source: PathRef, destination: PathRef) -> Bool {
        // Fast path only available for same-endpoint transfers
        source.isSameEndpoint(as: destination)
    }
    
    /// Execute fast path transfer
    /// - Returns: true if handled, false to fall back to generic pipeline
    func transfer(
        sources: [PathRef],
        to destination: PathRef,
        isMove: Bool
    ) async throws -> TransferPipelineResult? {
        // Only handle local-to-local for now
        guard sources.first?.isLocal == true && destination.isLocal else {
            return nil // Fall back to pipeline
        }
        
        // Use LocalFileOps directly for native operations with undo support
        guard let localOps = destination.ops as? LocalFileOps else {
            return nil
        }
        
        let items = sources.compactMap { FileItem.fromURL($0.url) }
        guard items.count == sources.count else {
            return nil // Some items couldn't be converted
        }
        
        do {
            if isMove {
                try await localOps.move(items: items, to: destination.url)
            } else {
                try await localOps.copy(items: items, to: destination.url)
            }
            
            Logger.fileSystem.debug(
                "FastPath \(isMove ? "move" : "copy"): \(items.count) items -> \(destination.url.path)"
            )
            
            return .success(count: items.count)
        } catch {
            Logger.fileSystem.error(
                "FastPath failed, falling back to pipeline: \(error.localizedDescription)"
            )
            return nil // Fall back to pipeline
        }
    }
}
