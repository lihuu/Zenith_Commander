import Foundation

/// Thread-safe endpoint registry for resolving URLs to endpoints
/// Resolution order: candidates filtered by kind → canHandle precise match → priority sort
@MainActor
final class EndpointRegistry {
    static let shared = EndpointRegistry()
    
    private var endpoints: [FileEndpoint] = []
    
    private init() {
        // Self-register default endpoints at initialization
        // This ensures endpoints are available for all file operations
        registerDefaultEndpoints()
    }
    
    /// Register default endpoints (local and SFTP)
    private func registerDefaultEndpoints() {
        endpoints.append(LocalEndpoint())
        endpoints.append(SFTPEndpoint())
    }
    
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