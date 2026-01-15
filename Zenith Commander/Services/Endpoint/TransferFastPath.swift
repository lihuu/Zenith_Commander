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
@MainActor
class TransferFastPath {
    
    /// Check if fast path is available for this transfer
    func canHandle(source: PathRef, destination: PathRef) -> Bool {
        // Fast path only available for same-endpoint transfers
        source.isSameEndpoint(as: destination)
    }
    
    /// Execute fast path transfer
    /// - Returns: result if handled, nil to fall back to generic pipeline
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
        
        // Convert PathRefs to FileEntries using stat
        var entries: [FileEntry] = []
        for source in sources {
            do {
                let entry = try await source.ops.stat(at: source.url)
                entries.append(entry)
            } catch {
                return nil // Fall back to pipeline if stat fails
            }
        }
        
        do {
            if isMove {
                try await localOps.move(items: entries, to: destination.url)
            } else {
                try await localOps.copy(items: entries, to: destination.url)
            }
            
            Logger.fileSystem.debug(
                "FastPath \(isMove ? "move" : "copy"): \(entries.count) items -> \(destination.url.path)"
            )
            
            return .success(count: entries.count)
        } catch {
            Logger.fileSystem.error(
                "FastPath failed, falling back to pipeline: \(error.localizedDescription)"
            )
            return nil // Fall back to pipeline
        }
    }
}
