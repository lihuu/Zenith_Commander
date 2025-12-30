//
//  RsyncService.swift
//  Zenith Commander
//
//  Service for executing rsync operations with preview and run capabilities
//

import Foundation

// Helper function for localization (nonisolated for use in error descriptions)
private nonisolated func L(_ key: LocalizedStringKey) -> String {
    MainActor.assumeIsolated {
        LocalizationManager.shared.localized(key)
    }
}

/// Service responsible for rsync operations
class RsyncService {
    // Singleton instance
    static let shared = RsyncService()

    // Tool runner for executing rsync commands
    private let toolRunner: ToolRunner

    // Cache for rsync installation check
    private var rsyncInstalledCache: Bool?

    // Candidate paths for rsync executable
    init(toolRunner: ToolRunner = ProcessToolRunner()) {
        self.toolRunner = toolRunner
    }

    // MARK: - Public API

    /// Checks if rsync is installed on the system
    /// - Returns: True if rsync executable is found
    /// - Note: Result is cached after first check
    func isRsyncInstalled() -> Bool {
        // Return cached value if available
        if let cached = rsyncInstalledCache {
            return cached
        }

        let result = ToolPathUtils.commandAvailable(command: "rsync")

        rsyncInstalledCache = result
        return result
    }

    /// Performs a dry-run preview of the rsync operation
    /// - Parameter config: Configuration for the rsync operation
    /// - Returns: Preview result with categorized file operations
    /// - Throws: Error if validation fails or rsync execution fails
    func preview(config: RsyncSyncConfig) async throws -> RsyncPreviewResult {
        // Validate paths
        try validatePaths(config: config)

        // Build command with dry-run enabled
        var previewConfig = config
        previewConfig.dryRun = true
        let command = buildCommand(config: previewConfig)

        // Execute rsync and capture output
        let output = try await executeRsync(command: command)

        // Parse output into preview result
        return parseDryRunOutput(output)
    }

    func run(
        config: RsyncSyncConfig,
        progressContinuation: AsyncStream<RsyncProgress>.Continuation
    )
        async throws -> RsyncRunResult
    {
        // Validate paths
        try validatePaths(config: config)

        // Build command without dry-run
        var runConfig = config
        runConfig.dryRun = false
        let command = buildCommand(config: runConfig)

        // Execute rsync with progress streaming
        var errors: [String] = []
        var summary = (copy: 0, update: 0, delete: 0, skip: 0)

        // Send initial progress update
        progressContinuation.yield(
            RsyncProgress(
                message: L(.rsyncProgress),
                completed: 0,
                total: 0
            )
        )

        do {
            let output = try await executeRsync(command: command)

            // Parse output to extract summary statistics
            let lines = output.components(separatedBy: .newlines)
            var fileCount = 0
            for line in lines {
                // Look for rsync summary line pattern: "sent X bytes  received Y bytes  Z.ZZ bytes/sec"
                if line.contains("bytes") && line.contains("bytes/sec") {
                    // Extract numbers if available
                    fileCount = lines.count
                }

                // Also look for error lines
                if line.lowercased().contains("error")
                    || line.lowercased().contains("failed")
                {
                    errors.append(line)
                }
            }

            // Send final progress update
            progressContinuation.yield(
                RsyncProgress(
                    message: L(.rsyncComplete),
                    completed: fileCount,
                    total: fileCount
                )
            )

            summary = (copy: 0, update: 0, delete: 0, skip: 0)

            progressContinuation.finish()

            return RsyncRunResult(
                success: errors.isEmpty,
                errors: errors,
                summary: summary
            )
        } catch {
            errors.append(error.localizedDescription)
            progressContinuation.finish()
            return RsyncRunResult(
                success: false,
                errors: errors,
                summary: summary
            )
        }
    }

    // MARK: - Internal Helpers

    /// Validates that source and destination paths are valid directories
    /// - Parameter config: Configuration to validate
    /// - Throws: Error with localized message if validation fails
    func validatePaths(config: RsyncSyncConfig) throws {
        let fileManager = FileManager.default
        var isSourceDir: ObjCBool = false
        var isDestDir: ObjCBool = false

        // Check source
        let sourceExists = fileManager.fileExists(
            atPath: config.source.path,
            isDirectory: &isSourceDir
        )
        guard sourceExists else {
            throw RsyncError.sourceNotFound(path: config.source.path)
        }
        guard isSourceDir.boolValue else {
            throw RsyncError.sourceNotDirectory(path: config.source.path)
        }

        // Check destination
        let destExists = fileManager.fileExists(
            atPath: config.destination.path,
            isDirectory: &isDestDir
        )
        guard destExists else {
            throw RsyncError.destinationNotFound(path: config.destination.path)
        }
        guard isDestDir.boolValue else {
            throw RsyncError.destinationNotDirectory(
                path: config.destination.path
            )
        }

        // Check for same path
        guard config.source.path != config.destination.path else {
            throw RsyncError.sameSourceAndDestination
        }
    }

    /// Builds the rsync command arguments from configuration
    /// - Parameter config: Configuration to build command from
    /// - Returns: Array of arguments [flags..., source, destination]
    func buildArgs(config: RsyncSyncConfig) -> [String] {
        var args: [String] = []

        // Add flags from config
        args.append(contentsOf: config.effectiveFlags())

        // Add source path (with trailing slash for directory contents)
        let sourcePath =
            config.source.path.hasSuffix("/")
            ? config.source.path : config.source.path + "/"
        args.append(sourcePath)

        // Add destination path
        args.append(config.destination.path)

        return args
    }

    /// Builds the rsync command array from configuration (legacy compatibility)
    /// - Parameter config: Configuration to build command from
    /// - Returns: Array of command components [rsync, flags..., source, destination]
    func buildCommand(config: RsyncSyncConfig) -> [String] {
        var command = ["/usr/bin/rsync"]
        command.append(contentsOf: buildArgs(config: config))
        return command
    }

    /// Parses dry-run output with itemized changes into categorized results
    /// - Parameter output: Raw output from rsync with --itemize-changes
    /// - Returns: Categorized preview result
    func parseDryRunOutput(_ output: String) -> RsyncPreviewResult {
        var copied: [RsyncItem] = []
        var updated: [RsyncItem] = []
        var deleted: [RsyncItem] = []
        var skipped: [RsyncItem] = []

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }

            // Parse itemized change format: "YXcstpoguax path"
            // Y: update type (>, c, *, ., etc.)
            // X: file type (f=file, d=directory, L=symlink, etc.)
            let components = trimmedLine.split(
                separator: " ",
                maxSplits: 1,
                omittingEmptySubsequences: true
            )
            guard components.count == 2 else { continue }

            let changeCode = String(components[0])
            let path = String(components[1]).trimmingCharacters(
                in: .whitespaces
            )

            // Determine action based on change code
            if changeCode.hasPrefix("*deleting") {
                deleted.append(RsyncItem(relativePath: path, action: .delete))
            } else if changeCode.hasPrefix(">f") || changeCode.hasPrefix(">d") {
                // New file or directory
                copied.append(RsyncItem(relativePath: path, action: .copy))
            } else if changeCode.hasPrefix(".f") || changeCode.hasPrefix(".d") {
                // File exists, checking for changes
                if changeCode.contains("t") || changeCode.contains("s")
                    || changeCode.contains("p")
                {
                    // Time, size, or permissions changed
                    updated.append(
                        RsyncItem(relativePath: path, action: .update)
                    )
                } else {
                    // No changes
                    skipped.append(RsyncItem(relativePath: path, action: .skip))
                }
            } else if changeCode.hasPrefix("c") {
                // Changed file
                updated.append(RsyncItem(relativePath: path, action: .update))
            } else {
                // Unknown or skipped
                skipped.append(RsyncItem(relativePath: path, action: .skip))
            }
        }

        return RsyncPreviewResult(
            copied: copied,
            updated: updated,
            deleted: deleted,
            skipped: skipped
        )
    }

    // MARK: - Private Methods

    /// Executes rsync command and returns output using ToolRunner
    private func executeRsync(command: [String]) async throws -> String {
        let request = ToolRequest(
            executable: command[0],
            args: Array(command.dropFirst()),
            workingDirectory: nil
        )

        let response = try await toolRunner.run(request)

        if response.exitCode != 0 {
            let errorOutput = response.stderr.joined(separator: "\n")
            throw RsyncError.executionFailed(
                code: Int(response.exitCode),
                message: errorOutput
            )
        }

        return response.stdout.joined(separator: "\n")
    }
}

// MARK: - Error Types

enum RsyncError: LocalizedError {
    case sourceNotFound(path: String)
    case sourceNotDirectory(path: String)
    case destinationNotFound(path: String)
    case destinationNotDirectory(path: String)
    case sameSourceAndDestination
    case executionFailed(code: Int, message: String)
    case processError(Error)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            String(format: "%@: %@", L(.rsyncErrorSourceNotFound), path)
        case .sourceNotDirectory(let path):
            String(format: "%@: %@", L(.rsyncErrorSourceNotDirectory), path)
        case .destinationNotFound(let path):
            String(format: "%@: %@", L(.rsyncErrorDestinationNotFound), path)
        case .destinationNotDirectory(let path):
            String(
                format: "%@: %@",
                L(.rsyncErrorDestinationNotDirectory),
                path
            )
        case .sameSourceAndDestination:
            L(.rsyncErrorSameSourceDestination)
        case .executionFailed(let code, let message):
            String(
                format: "%@ (code: %d): %@",
                L(.rsyncErrorExecutionFailed),
                code,
                message
            )
        case .processError(let error):
            String(
                format: "%@: %@",
                L(.rsyncErrorExecutionFailed),
                error.localizedDescription
            )
        }
    }
}
