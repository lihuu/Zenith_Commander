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

// MARK: - Endpoint Registry

/// Thread-safe endpoint registry for resolving URLs to endpoints
/// Resolution order: candidates filtered by kind → canHandle precise match → priority sort
@MainActor
final class EndpointRegistry {
    static let shared = EndpointRegistry()
    
    private var endpoints: [FileEndpoint] = []
    
    private init() {}
    
    /// Register an endpoint
    func register(_ endpoint: FileEndpoint) {
        endpoints.append(endpoint)
    }
    
    /// Unregister an endpoint
    func unregister(_ endpoint: FileEndpoint) {
        endpoints.removeAll { $0 === endpoint }
    }
    
    /// Resolve URL to appropriate endpoint
    /// Resolution strategy:
    /// 1. Filter candidates by EndpointKind (supports multi-instance same-protocol)
    /// 2. Apply canHandle for precise matching
    /// 3. Sort by priority and return highest priority match
    /// - Parameter url: URL to resolve
    /// - Returns: FileEndpoint that can handle this URL
    func resolve(for url: URL) -> FileEndpoint? {
        let targetKind = EndpointKind.from(url)
        
        // Step 1: Filter by matching kind pattern
        let candidates = endpoints.filter { endpoint in
            matchesKindPattern(endpoint.kind, target: targetKind)
        }
        
        // Step 2: Apply canHandle for precise matching
        let matches = candidates.filter { $0.canHandle(url) }
        
        // Step 3: Sort by priority (descending) and return first match
        let sorted = matches.sorted { $0.kind.priority > $1.kind.priority }
        return sorted.first
    }
    
    /// Check if endpoint kind matches target pattern
    /// For multi-instance support (e.g., different SFTP hosts)
    private func matchesKindPattern(_ endpointKind: EndpointKind, target: EndpointKind) -> Bool {
        switch (endpointKind, target) {
        case (.local, .local):
            return true
        case let (.sftp(eHost, ePort), .sftp(tHost, tPort)):
            // Empty host in endpoint means "any host" (generic SFTP handler)
            if eHost.isEmpty {
                return true
            }
            return eHost == tHost && ePort == tPort
        default:
            return false
        }
    }
    
    /// Get all registered endpoints (for debugging/inspection)
    func allEndpoints() -> [FileEndpoint] {
        endpoints
    }
}
