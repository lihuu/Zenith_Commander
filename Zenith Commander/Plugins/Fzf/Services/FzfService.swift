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
    private let fzfExecutablePath: String
    private let findExecuatablePath: String
    private let rgExecutablePath: String

    init(toolRunner: ToolRunner = ProcessToolRunner()) {
        self.toolRunner = toolRunner
        fzfExecutablePath =
            ToolPathUtils.resolveFirstExecutablePath(
                candidatePaths: [
                    "/opt/homebrew/bin/fzf",
                    "/usr/local/bin/fzf",
                    "/usr/bin/fzf",
                ]
            ) ?? "fzf"
        findExecuatablePath =
            ToolPathUtils.resolveFirstExecutablePath(candidatePaths: [
                "/opt/homebrew/bin/fd",
                "/usr/local/bin/fd",
                "/usr/bin/fd",
            ]) ?? ToolPathUtils.resolveFirstExecutablePath(candidatePaths: [
                "/opt/homebrew/bin/find",
                "/usr/local/bin/find",
                "/usr/bin/find",
            ]) ?? "find"
        rgExecutablePath =
            ToolPathUtils.resolveFirstExecutablePath(candidatePaths: [
                "/opt/homebrew/bin/rg",
                "/usr/local/bin/rg",
                "/usr/bin/rg",
            ]) ?? "rg"
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
        // Use find + fzf pipeline for file search
        // find . -type f | fzf --filter=pattern
        let findArgs =
            recursive
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
            args: [
                "bash", "-c",
                "echo '\(files.replacingOccurrences(of: "'", with: "'\\''"))' | fzf --filter='\(pattern.replacingOccurrences(of: "'", with: "'\\''"))'",
            ],
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
