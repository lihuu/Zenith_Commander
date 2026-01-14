//
//  NewTransferService.swift
//  Zenith Commander
//
//  Unified TransferService - single entry point for all file transfers.
//  Uses Endpoint architecture to eliminate N×N implementations.
//

import Foundation
import os.log

/// Transfer operation type
enum TransferOp {
    case copy
    case move
}

/// Unified transfer service
/// Single entry point for all file transfers across any protocol combination.
class NewTransferService {
    static let shared = NewTransferService()
    
    private let pipeline = GenericTransferPipeline()
    private let fastPath = TransferFastPath()
    
    private init() {
        // Register endpoints on initialization
        EndpointRegistry.shared.register(LocalEndpoint())
        EndpointRegistry.shared.register(SFTPEndpoint())
    }
    
    /// Transfer files from sources to destination
    /// - Parameters:
    ///   - sources: Source file URLs
    ///   - destination: Destination directory URL
    ///   - operation: Copy or move
    ///   - undoManager: Optional undo manager for local operations
    ///   - progress: Optional progress callback
    /// - Returns: Transfer result
    func transfer(
        sources: [URL],
        to destination: URL,
        operation: TransferOp,
        undoManager: UndoManager? = nil,
        progress: TransferPipelineProgress? = nil
    ) async throws -> TransferPipelineResult {
        guard !sources.isEmpty else {
            return .empty
        }
        
        // Resolve destination
        guard let destRef = PathRef.from(destination) else {
            throw TransferServiceError.noEndpointForURL(destination)
        }
        
        // Resolve all sources
        var sourceRefs: [PathRef] = []
        for source in sources {
            guard let ref = PathRef.from(source) else {
                throw TransferServiceError.noEndpointForURL(source)
            }
            sourceRefs.append(ref)
        }
        
        // Inject undo manager for local endpoints
        if let undoManager = undoManager {
            destRef.endpoint.undoManager = undoManager
            for ref in sourceRefs {
                ref.endpoint.undoManager = undoManager
            }
        }
        
        defer {
            // Clear undo managers
            destRef.endpoint.undoManager = nil
            for ref in sourceRefs {
                ref.endpoint.undoManager = nil
            }
        }
        
        let isMove = operation == .move
        
        // Try fast path first for same-endpoint transfers
        if sourceRefs.first?.isSameEndpoint(as: destRef) == true {
            if let result = try await fastPath.transfer(
                sources: sourceRefs,
                to: destRef,
                isMove: isMove
            ) {
                return result
            }
        }
        
        // Fall back to generic pipeline
        return try await pipeline.transfer(
            sources: sourceRefs,
            to: destRef,
            isMove: isMove,
            progress: progress
        )
    }
}

// MARK: - Errors

enum TransferServiceError: LocalizedError {
    case noEndpointForURL(URL)
    case destinationNotDirectory(URL)
    case sourceNotFound(URL)
    
    var errorDescription: String? {
        switch self {
        case .noEndpointForURL(let url):
            return "No endpoint available for URL: \(url)"
        case .destinationNotDirectory(let url):
            return "Destination is not a directory: \(url.lastPathComponent)"
        case .sourceNotFound(let url):
            return "Source not found: \(url.lastPathComponent)"
        }
    }
}
