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
        return (
            .find, ToolRequest(executable: toolchain.findPath, args: args, workingDirectory: nil)
        )
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
    /// - Uses streaming shell pipeline: listProcess.stdout → Pipe → fzfProcess.stdin
    func listFilesThenFuzzyFilter(
        root: String,
        scope: FileListScope,
        query: String,
        config: FileListConfig? = nil,
        toolchain: ExternalToolchain? = nil
    ) async throws -> [String] {
        // 1) Early return on empty query (do not list files)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            print("[ToolRunner][fzf] query empty -> return []")
            return []
        }

        // 2) Resolve config/toolchain and build listing request (rg/fd/find)
        let effectiveConfig = config ?? FileListConfig()
        let effectiveToolchain = toolchain ?? ExternalToolchain.shared
        let (listTool, listReq) = buildFileListRequest(
            toolchain: effectiveToolchain, root: root, scope: scope, config: effectiveConfig
        )
        let listCmd = ([listReq.executable] + listReq.args).joined(separator: " ")
        let listCwd = listReq.workingDirectory ?? "."
        print("[ToolRunner][fzf] list (\(listTool.rawValue)) cmd: \(listCmd) | cwd=\(listCwd)")

        // If fzf exists, use streaming pipeline: listProcess stdout → pipe → fzf stdin
        if let fzfBase = buildFzfBaseRequest(toolchain: effectiveToolchain) {
            let fzfReq = ToolRequest(
                executable: fzfBase.executable,
                args: fzfBase.args + ["--filter", trimmed],
                workingDirectory: fzfBase.workingDirectory
            )
            let fzfCmd = ([fzfReq.executable] + fzfReq.args).joined(separator: " ")
            let fzfCwd = fzfReq.workingDirectory ?? "."
            print("[ToolRunner][fzf] filter cmd: \(fzfCmd) | cwd=\(fzfCwd)")

            do {
                let result = try await runShellPipeline(upstream: listReq, downstream: fzfReq)
                return result.stdoutString
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map(String.init)
            } catch {
                // fzf execution failed -> fallback to Swift filter
                print("[ToolRunner][fzf] pipeline failed: \(error), falling back to Swift filter")
            }
        }

        // fzf not installed or pipeline failed -> fallback (load into memory)
        let list = try await runData(listReq)
        let all = list.stdoutString
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        return all.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    // MARK: - Private Helpers

    /// Run a shell pipeline: upstream.stdout → Pipe → downstream.stdin
    /// Returns the downstream process's stdout/stderr.
    /// - Note: Starts downstream first, then upstream. Only waits for downstream to finish.
    ///         Upstream is terminated naturally when the pipe closes.
    private func runShellPipeline(
        upstream: ToolRequest,
        downstream: ToolRequest
    ) async throws -> ToolResponseData {
        try await withCheckedThrowingContinuation { cont in
            // 1) Create the shared pipe connecting upstream stdout → downstream stdin
            let sharedPipe = Pipe()

            // 2) Configure downstream process (fzf)
            let downstreamProcess = Process()
            downstreamProcess.executableURL = URL(fileURLWithPath: downstream.executable)
            downstreamProcess.arguments = downstream.args
            if let wd = downstream.workingDirectory {
                downstreamProcess.currentDirectoryURL = URL(fileURLWithPath: wd)
            }
            downstreamProcess.standardInput = sharedPipe
            let downstreamStdout = Pipe()
            let downstreamStderr = Pipe()
            downstreamProcess.standardOutput = downstreamStdout
            downstreamProcess.standardError = downstreamStderr

            // 3) Configure upstream process (rg/fd/find)
            let upstreamProcess = Process()
            upstreamProcess.executableURL = URL(fileURLWithPath: upstream.executable)
            upstreamProcess.arguments = upstream.args
            if let wd = upstream.workingDirectory {
                upstreamProcess.currentDirectoryURL = URL(fileURLWithPath: wd)
            }
            upstreamProcess.standardOutput = sharedPipe
            // Discard upstream stderr
            upstreamProcess.standardError = FileHandle.nullDevice

            // 4) Resume-once guard
            let lock = NSLock()
            var didResume = false
            func resumeOnce(_ body: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                body()
            }

            // 5) Set downstream termination handler - only wait for downstream
            downstreamProcess.terminationHandler = { proc in
                proc.terminationHandler = nil

                // Close the shared pipe's write end to ensure upstream sees EOF if still running
                try? sharedPipe.fileHandleForWriting.close()

                let outData = downstreamStdout.fileHandleForReading.readDataToEndOfFile()
                let errData = downstreamStderr.fileHandleForReading.readDataToEndOfFile()
                let resp = ToolResponseData(
                    exitCode: proc.terminationStatus,
                    stdout: outData,
                    stderr: errData
                )
                resumeOnce {
                    cont.resume(returning: resp)
                }
            }

            // 6) Start downstream first (so it's ready to receive data)
            do {
                try downstreamProcess.run()
            } catch {
                downstreamProcess.terminationHandler = nil
                resumeOnce {
                    cont.resume(throwing: error)
                }
                return
            }

            // 7) Start upstream (its stdout flows into the shared pipe)
            do {
                try upstreamProcess.run()
            } catch {
                // Upstream failed to start - terminate downstream and report
                downstreamProcess.terminationHandler = nil
                downstreamProcess.terminate()
                try? sharedPipe.fileHandleForWriting.close()
                resumeOnce {
                    cont.resume(throwing: error)
                }
                return
            }

            // 8) When upstream finishes, close the write end so downstream gets EOF
            upstreamProcess.terminationHandler = { proc in
                proc.terminationHandler = nil
                try? sharedPipe.fileHandleForWriting.close()
            }
        }
    }

    /// Convenience: list files (rg/fd/find), then fuzzy-filter using fzf (non-interactive).
    /// - Important: this helper keeps everything within ToolRunner.
    func listThenFzfFilter(
        listStdout: Data,
        fzfRequest: ToolRequest,
        query: String
    ) async throws -> ToolResponseData {
        // fzf filter (stdin = list stdout)
        let fzfReq = ToolRequest(
            executable: fzfRequest.executable,
            args: fzfRequest.args + ["--filter", query],
            workingDirectory: fzfRequest.workingDirectory
        )
        return try await runData(fzfReq, stdin: listStdout)
    }
}
