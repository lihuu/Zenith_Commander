//
//  FzfFileListingService.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/29/25.
//

import Foundation

// MARK: - Fzf File Listing Service

/// Search scope for listing files.
enum FileListScope: Sendable {
    /// Only list direct children (max depth 1).
    case nonRecursive
    /// Recursively list files under root.
    case recursive
}

/// Configuration for listing files using external tools.
struct FileListConfig: Sendable {
    /// Directory names to exclude (e.g. .git, node_modules).
    var excludes: [String] = [".git", "node_modules", "DerivedData", ".build", ".swiftpm"]
    /// Whether to include hidden files.
    var includeHidden = true
    /// Whether to follow symlinks.
    var followSymlinks = true

    init(
        excludes: [String] = [".git", "node_modules", "DerivedData", ".build", ".swiftpm"],
        includeHidden: Bool = true, followSymlinks: Bool = true
    ) {
        self.excludes = excludes
        self.includeHidden = includeHidden
        self.followSymlinks = followSymlinks
    }
}

/// Listing tool preference.
enum FileListTool: String, Sendable {
    case rg
    case fd
    case find
    case git
    case rsync
    case fzf
}

// MARK: - ToolRunner + File Listing Extensions

extension ToolRunner {
    /// Build a ToolRequest for listing files under `root` with automatic tool fallback.
    /// - Priority: rg (recursive only) > fd > find
    func buildFileListRequest(
        toolchain: ExternalToolchain,
        root: String,
        scope: FileListScope,
        config: FileListConfig = .init()
    ) -> (tool: FileListTool, request: ToolRequest) {
        // 1) rg: only for recursive listing (fastest), because rg lacks a clean max-depth flag.
        if scope == .recursive, let rg = toolchain.rgPath {
            var args = ["--files"]
            if config.includeHidden { args.append("--hidden") }
            if config.followSymlinks { args.append("--follow") }
            for ex in config.excludes {
                // Exclude directories by glob.
                args += ["--glob", "!\(ex)/*"]
            }
            args.append(root)
            return (.rg, ToolRequest(executable: rg, args: args, workingDirectory: nil))
        }

        // 2) fd: supports both recursive and non-recursive via --max-depth
        if let fd = toolchain.fdPath {
            var args: [String] = []
            if config.includeHidden { args.append("-H") }
            if config.followSymlinks { args.append("-L") }
            args += ["-t", "f"]
            if scope == .nonRecursive {
                args += ["--max-depth", "1"]
            }
            for ex in config.excludes {
                args += ["-E", ex]
            }
            // pattern + root
            args += [".", root]
            return (.fd, ToolRequest(executable: fd, args: args, workingDirectory: nil))
        }

        // 3) find: always available (fallback)
        var args: [String] = [root]
        switch scope {
        case .nonRecursive:
            args += ["-maxdepth", "1", "-type", "f", "-print"]
        case .recursive:
            if !config.excludes.isEmpty {
                // ( -type d ( -name ex1 -o -name ex2 ... ) -prune ) -o -type f -print
                args += ["(", "-type", "d", "("]
                for (i, ex) in config.excludes.enumerated() {
                    if i > 0 { args.append("-o") }
                    args += ["-name", ex]
                }
                args += [")", "-prune", ")", "-o"]
            }
            args += ["-type", "f", "-print"]
        }
        return (.find, ToolRequest(executable: toolchain.findPath, args: args, workingDirectory: nil))
    }

    /// Build a ToolRequest for non-interactive fzf filtering.
    /// - Note: This request intentionally does NOT include `--filter <query>`.
    ///         Pass the query at call time (e.g. `listThenFzfFilter`).
    func buildFzfBaseRequest(toolchain: ExternalToolchain) -> ToolRequest? {
        guard let fzf = toolchain.fzfPath else { return nil }
        return ToolRequest(executable: fzf, args: [], workingDirectory: nil)
    }

    /// A high-level helper: list files with automatic tool fallback, then fuzzy-filter via fzf (if available).
    /// - If fzf is not installed, falls back to a simple case-insensitive contains filter in Swift.
    func listFilesThenFuzzyFilter(
        root: String,
        scope: FileListScope,
        query: String,
        config: FileListConfig = .init(),
        toolchain: ExternalToolchain = .shared
    ) async throws -> [String] {
        let (_, listReq) = buildFileListRequest(
            toolchain: toolchain, root: root, scope: scope, config: config
        )
        let list = try await runData(listReq)

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return list.stdoutString.split(separator: "\n", omittingEmptySubsequences: true).map(
                String.init)
        }

        if let fzfBase = buildFzfBaseRequest(toolchain: toolchain) {
            let filtered = try await listThenFzfFilter(
                listRequest: listReq, fzfRequest: fzfBase, query: trimmed
            )
            return filtered.stdoutString.split(separator: "\n", omittingEmptySubsequences: true).map(
                String.init)
        }

        // fzf not installed -> fallback
        let all = list.stdoutString.split(separator: "\n", omittingEmptySubsequences: true).map(
            String.init)
        return all.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Convenience: list files (rg/fd/find), then fuzzy-filter using fzf (non-interactive).
    /// - Important: this helper keeps everything within ToolRunner.
    func listThenFzfFilter(
        listRequest: ToolRequest,
        fzfRequest: ToolRequest,
        query: String
    ) async throws -> ToolResponseData {
        // 1) list candidates
        let list = try await runData(listRequest)
        // 2) fzf filter (stdin = list stdout)
        let fzfReq = ToolRequest(
            executable: fzfRequest.executable,
            args: fzfRequest.args + ["--filter", query],
            workingDirectory: fzfRequest.workingDirectory
        )
        return try await runData(fzfReq, stdin: list.stdout)
    }
}
