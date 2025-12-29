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

    init(toolRunner: ToolRunner = ProcessToolRunner()) {
        self.toolRunner = toolRunner
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
        let scope: FileListScope = recursive ? .recursive : .nonRecursive
        let results = try await toolRunner.listFilesThenFuzzyFilter(
            root: directory.path,
            scope: scope,
            query: pattern
        )
        return results.map { URL(fileURLWithPath: $0) }
    }

    func isFzfInstalled() -> Bool {
        return ExternalToolchain.shared.isToolAvailable(.fzf)
    }
}

// MARK: - Error Types

enum FzfError: LocalizedError {
    case notInstalled
    case searchFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            "fzf is not installed. Please install it using: brew install fzf"
        case .searchFailed(let message):
            "Search failed: \(message)"
        }
    }
}
