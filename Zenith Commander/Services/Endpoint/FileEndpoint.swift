//
//  FileEndpoint.swift
//  Zenith Commander
//
//  FileEndpoint represents a connected file system instance.
//  It may hold session state, credentials, or connection handles.
//

import Foundation

// MARK: - Endpoint Kind

/// Endpoint type identifier - used for internal routing instead of string-based scheme
/// URL.scheme is only used for parsing, not as unique routing key
enum EndpointKind: Hashable, Sendable {
    case local
    case sftp(host: String, port: Int)
    // Future: case smb(host: String, share: String)
    // Future: case ftp(host: String, port: Int)
    
    /// Priority for resolution - higher priority endpoints are checked first
    var priority: Int {
        switch self {
        case .sftp: return 100  // More specific, check first
        case .local: return 0    // Fallback
        }
    }
    
    /// Create from URL (for initial parsing only)
    static func from(_ url: URL) -> EndpointKind {
        switch url.scheme?.lowercased() {
        case "sftp":
            let host = url.host ?? ""
            let port = url.port ?? 22
            return .sftp(host: host, port: port)
        default:
            return .local
        }
    }
}

// MARK: - File Endpoint Protocol

/// File endpoint protocol
/// Represents a connected file system that can provide FileOps.
/// Each endpoint instance handles a specific target (e.g., one SFTP host).
/// Note: Endpoints are expected to be used on the main actor.
@MainActor
protocol FileEndpoint: AnyObject {
    /// Endpoint kind identifier - used for routing and priority
    var kind: EndpointKind { get }
    
    /// Get the FileOps instance for this endpoint
    /// The ops instance is stable and reused for the lifetime of the endpoint.
    /// Endpoint may inject session/connection state into the ops.
    var ops: FileOps { get }
    
    /// Check if this endpoint can handle the given URL
    /// Used for precise matching beyond just scheme (e.g., specific host)
    /// - Parameter url: URL to check
    /// - Returns: True if this endpoint can handle it
    func canHandle(_ url: URL) -> Bool
}

// MARK: - Undo Supporting Endpoint

/// Optional capability protocol for endpoints that support undo
/// Only local endpoint implements this - remote endpoints do NOT support undo
@MainActor
protocol UndoSupportingEndpoint: FileEndpoint {
    /// Undo manager for reversible operations
    var undoManager: UndoManager? { get set }
}


