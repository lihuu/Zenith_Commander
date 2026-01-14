//
//  PathRef.swift
//  Zenith Commander
//
//  PathRef is the unified path reference - protocol-agnostic entry point.
//  Contains URL and resolved endpoint for all file operations.
//

import Foundation

/// Unified path reference
/// This is the entry point for all file operations.
/// Contains both the URL and the resolved endpoint.
struct PathRef {
    /// The underlying URL
    let url: URL
    
    /// The resolved endpoint for this path
    let endpoint: FileEndpoint
    
    /// Create a PathRef by resolving the URL to an endpoint
    /// - Parameter url: URL to wrap
    /// - Returns: PathRef if endpoint found, nil otherwise
    static func from(_ url: URL) -> PathRef? {
        guard let endpoint = EndpointRegistry.shared.resolve(for: url) else {
            return nil
        }
        return PathRef(url: url, endpoint: endpoint)
    }
    
    /// Create a PathRef with explicit endpoint (for internal use)
    init(url: URL, endpoint: FileEndpoint) {
        self.url = url
        self.endpoint = endpoint
    }
    
    // MARK: - Convenience Properties
    
    /// Get FileOps for this path
    var ops: FileOps {
        endpoint.ops
    }
    
    /// Protocol scheme
    var scheme: String {
        endpoint.scheme
    }
    
    /// File/directory name
    var name: String {
        url.lastPathComponent
    }
    
    /// Parent directory as PathRef
    var parent: PathRef {
        PathRef(url: url.deletingLastPathComponent(), endpoint: endpoint)
    }
    
    /// Append path component
    func appending(_ component: String) -> PathRef {
        PathRef(url: url.appendingPathComponent(component), endpoint: endpoint)
    }
    
    /// Check if this is a local file
    var isLocal: Bool {
        scheme == "file" || url.isFileURL
    }
    
    /// Check if source and destination share the same endpoint type
    func isSameEndpoint(as other: PathRef) -> Bool {
        scheme == other.scheme
    }
}

// MARK: - Equatable & Hashable

extension PathRef: Equatable {
    static func == (lhs: PathRef, rhs: PathRef) -> Bool {
        lhs.url == rhs.url && lhs.scheme == rhs.scheme
    }
}

extension PathRef: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(scheme)
    }
}
