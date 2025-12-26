//
//  FzfService.swift
//  Zenith Commander
//
//  Service for executing fzf fuzzy search operations
//

import Foundation

/// Service responsible for fzf operations
class FzfService {
    static let shared = FzfService()
    
    private let toolRunner: ToolRunner
    private var fzfInstalledCache: Bool?
    
    // Candidate paths for fzf executable
    private let candidatePaths: [String] = [
        "/opt/homebrew/bin/fzf",
        "/usr/local/bin/fzf",
        "/usr/bin/fzf",
    ]
    
    init(toolRunner: ToolRunner = ProcessToolRunner()) {
        self.toolRunner = toolRunner
    }
    
    // MARK: - Public API
    
    /// Checks if fzf is installed on the system
    /// - Returns: True if fzf executable is found
    /// - Note: Result is cached after first check
    func isFzfInstalled() -> Bool {
        if let cached = fzfInstalledCache {
            return cached
        }
        
        let allCandidates = ToolPathUtils.generateCandidatePaths(
            executableName: "fzf",
            additionalPaths: candidatePaths
        )
        
        let result = ToolPathUtils.resolveFirstExecutablePath(candidatePaths: allCandidates) != nil
        fzfInstalledCache = result
        return result
    }
    
    /// Performs fuzzy search using fzf
    /// - Parameters:
    ///   - pattern: Search pattern
    ///   - directory: Directory to search in
    ///   - recursive: Whether to search recursively
    /// - Returns: Array of matching file paths
    func search(
        pattern: String,
        directory: URL,
        recursive: Bool = true
    ) async throws -> [URL] {
        guard isFzfInstalled() else {
            throw FzfError.notInstalled
        }
        
        // Use find + fzf pipeline for file search
        // find . -type f | fzf --filter=pattern
        let findArgs = recursive
            ? [directory.path, "-type", "f"]
            : [directory.path, "-maxdepth", "1", "-type", "f"]
        
        // First get file list with find
        let findRequest = ToolRequest(
            executable: "/usr/bin/find",
            args: findArgs,
            workingDirectory: directory.path
        )
        
        let findResponse = try await toolRunner.run(findRequest)
        let files = findResponse.stdout.joined(separator: "\n")
        
        guard !files.isEmpty else {
            return []
        }
        
        // Then filter with fzf
        let fzfRequest = ToolRequest(
            executable: "/usr/bin/env",
            args: ["bash", "-c", "echo '\(files.replacingOccurrences(of: "'", with: "'\\''"))' | fzf --filter='\(pattern.replacingOccurrences(of: "'", with: "'\\''"))'"],
            workingDirectory: directory.path
        )
        
        let fzfResponse = try await toolRunner.run(fzfRequest)
        
        // Parse results
        let results = fzfResponse.stdout
            .filter { !$0.isEmpty }
            .compactMap { path -> URL? in
                let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return URL(fileURLWithPath: trimmed)
            }
        
        return results
    }
}

// MARK: - Error Types

enum FzfError: LocalizedError {
    case notInstalled
    case searchFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "fzf is not installed. Please install it using: brew install fzf"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        }
    }
}
