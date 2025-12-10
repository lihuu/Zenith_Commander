//
//  RsyncService.swift
//  Zenith Commander
//
//  Service for executing rsync operations with preview and run capabilities
//

import Foundation

/// Service responsible for rsync operations
class RsyncService {
    
    // Singleton instance
    static let shared = RsyncService()
    
    private init() {}
    
    // MARK: - Public API
    
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
    
    /// Executes the actual rsync operation
    /// - Parameters:
    ///   - config: Configuration for the rsync operation
    ///   - progressStream: Async stream for progress updates
    /// - Returns: Final result with summary and any errors
    /// - Throws: Error if validation fails or rsync execution fails
    func run(config: RsyncSyncConfig, progress: AsyncStream<RsyncProgress>) async throws -> RsyncRunResult {
        // TODO: Implementation in Phase 5
        fatalError("Not implemented yet")
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
        let sourceExists = fileManager.fileExists(atPath: config.source.path, isDirectory: &isSourceDir)
        guard sourceExists else {
            throw RsyncError.sourceNotFound(path: config.source.path)
        }
        guard isSourceDir.boolValue else {
            throw RsyncError.sourceNotDirectory(path: config.source.path)
        }
        
        // Check destination
        let destExists = fileManager.fileExists(atPath: config.destination.path, isDirectory: &isDestDir)
        guard destExists else {
            throw RsyncError.destinationNotFound(path: config.destination.path)
        }
        guard isDestDir.boolValue else {
            throw RsyncError.destinationNotDirectory(path: config.destination.path)
        }
        
        // Check for same path
        guard config.source.path != config.destination.path else {
            throw RsyncError.sameSourceAndDestination
        }
    }
    
    /// Builds the rsync command array from configuration
    /// - Parameter config: Configuration to build command from
    /// - Returns: Array of command components [rsync, flags..., source, destination]
    func buildCommand(config: RsyncSyncConfig) -> [String] {
        var command = ["/usr/bin/rsync"]
        
        // Add flags from config
        command.append(contentsOf: config.effectiveFlags())
        
        // Add source path (with trailing slash for directory contents)
        let sourcePath = config.source.path.hasSuffix("/") ? config.source.path : config.source.path + "/"
        command.append(sourcePath)
        
        // Add destination path
        command.append(config.destination.path)
        
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
            guard !line.isEmpty else { continue }
            
            // Parse itemized change format: "YXcstpoguax path"
            // Y: update type (>, c, *, ., etc.)
            // X: file type (f=file, d=directory, L=symlink, etc.)
            let components = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard components.count == 2 else { continue }
            
            let changeCode = String(components[0])
            let path = String(components[1])
            
            // Determine action based on change code
            if changeCode.hasPrefix("*deleting") {
                deleted.append(RsyncItem(relativePath: path, action: .delete))
            } else if changeCode.hasPrefix(">f") || changeCode.hasPrefix(">d") {
                // New file or directory
                copied.append(RsyncItem(relativePath: path, action: .copy))
            } else if changeCode.hasPrefix(".f") || changeCode.hasPrefix(".d") {
                // File exists, checking for changes
                if changeCode.contains("t") || changeCode.contains("s") || changeCode.contains("p") {
                    // Time, size, or permissions changed
                    updated.append(RsyncItem(relativePath: path, action: .update))
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
    
    /// Executes rsync command and returns output
    private func executeRsync(command: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus != 0 {
                    continuation.resume(throwing: RsyncError.executionFailed(
                        code: Int(process.terminationStatus),
                        message: errorOutput
                    ))
                } else {
                    continuation.resume(returning: output)
                }
            } catch {
                continuation.resume(throwing: RsyncError.processError(error))
            }
        }
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
            return "Source path not found: \(path)"
        case .sourceNotDirectory(let path):
            return "Source path is not a directory: \(path)"
        case .destinationNotFound(let path):
            return "Destination path not found: \(path)"
        case .destinationNotDirectory(let path):
            return "Destination path is not a directory: \(path)"
        case .sameSourceAndDestination:
            return "Source and destination cannot be the same"
        case .executionFailed(let code, let message):
            return "Rsync failed with code \(code): \(message)"
        case .processError(let error):
            return "Process error: \(error.localizedDescription)"
        }
    }
}
