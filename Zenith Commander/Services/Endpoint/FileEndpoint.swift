//
//  FileEndpoint.swift
//  Zenith Commander
//
//  FileEndpoint represents a connected file system instance.
//  It may hold session state, credentials, or connection handles.
//

import Foundation

/// File endpoint protocol
/// Represents a connected file system that can provide FileOps.
/// Each protocol (local, sftp, smb, ftp) has one FileEndpoint implementation.
protocol FileEndpoint: AnyObject {
    /// Protocol scheme identifier (e.g., "file", "sftp", "smb")
    var scheme: String { get }
    
    /// Get the FileOps instance for this endpoint
    /// The endpoint may inject session/connection state into the ops
    var ops: FileOps { get }
    
    /// Check if this endpoint can handle the given URL
    /// - Parameter url: URL to check
    /// - Returns: True if this endpoint can handle it
    func canHandle(_ url: URL) -> Bool
    
    /// Optional: Undo manager for local operations
    /// Only local endpoint needs this; remote endpoints return nil
    var undoManager: UndoManager? { get set }
}

/// Default implementation for endpoints that don't support undo
extension FileEndpoint {
    var undoManager: UndoManager? {
        get { nil }
        set { /* no-op for remote endpoints */ }
    }
}

/// Endpoint registry for resolving URLs to endpoints
class EndpointRegistry {
    static let shared = EndpointRegistry()
    
    private var endpoints: [FileEndpoint] = []
    
    private init() {}
    
    /// Register an endpoint
    func register(_ endpoint: FileEndpoint) {
        endpoints.append(endpoint)
    }
    
    /// Resolve URL to appropriate endpoint
    /// - Parameter url: URL to resolve
    /// - Returns: FileEndpoint that can handle this URL
    func resolve(for url: URL) -> FileEndpoint? {
        // First try exact scheme match
        if let scheme = url.scheme {
            if let endpoint = endpoints.first(where: { $0.scheme == scheme }) {
                return endpoint
            }
        }
        
        // Check canHandle for more complex routing
        return endpoints.first { $0.canHandle(url) }
    }
}
