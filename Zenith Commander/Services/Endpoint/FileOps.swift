//
//  FileOps.swift
//  Zenith Commander
//
//  Core file operations protocol for the Endpoint architecture.
//  This is the only interface that GenericTransferPipeline depends on.
//  Returns protocol-agnostic FileEntry - no UI model dependencies.
//

import Foundation

/// Core file operations protocol
/// Defines operations that all file system implementations must provide.
/// This protocol is designed to be protocol-agnostic and supports generic transfer pipelines.
/// Returns FileEntry (not FileItem) to maintain clean layer separation.
protocol FileOps: AnyObject {
    
    // MARK: - Directory Operations
    
    /// List directory contents
    /// - Parameter path: Directory path
    /// - Returns: Array of FileEntry (protocol-agnostic)
    func list(at path: URL) async throws -> [FileEntry]
    
    /// Get file/directory metadata
    /// - Parameter path: Path to stat
    /// - Returns: FileEntry with metadata
    func stat(at path: URL) async throws -> FileEntry
    
    /// Check if path exists
    /// - Parameter path: Path to check
    /// - Returns: True if exists
    func exists(at path: URL) async throws -> Bool
    
    // MARK: - Create Operations
    
    /// Create a directory
    /// - Parameters:
    ///   - path: Parent directory path
    ///   - name: Name of new directory
    ///   - recursive: Create intermediate directories if needed
    /// - Returns: Created directory path
    func mkdir(at path: URL, name: String, recursive: Bool) async throws -> URL
    
    /// Create an empty file
    /// - Parameters:
    ///   - path: Parent directory path
    ///   - name: Name of new file
    /// - Returns: Created file path
    func createFile(at path: URL, name: String) async throws -> URL
    
    // MARK: - Modify Operations
    
    /// Rename/move within same endpoint
    /// - Parameters:
    ///   - from: Source path
    ///   - to: Destination path
    func rename(from source: URL, to destination: URL) async throws
    
    /// Move to trash (soft delete)
    /// - Parameter path: Path to trash
    func trash(at path: URL) async throws
    
    /// Delete permanently (hard delete)
    /// - Parameter path: Path to delete
    func delete(at path: URL) async throws
    
    // MARK: - Stream Operations (for transfers)
    
    /// Read file contents as async byte stream
    /// - Parameter path: Path to the file
    /// - Returns: Async stream of data chunks
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error>
    
    /// Write data stream to a file
    /// - Parameters:
    ///   - path: Destination file path
    ///   - data: Async stream of data chunks to write
    func write(to path: URL, data: AsyncThrowingStream<Data, Error>) async throws
}

// MARK: - Default Implementations

extension FileOps {
    /// Default implementation: exists via stat
    func exists(at path: URL) async throws -> Bool {
        do {
            _ = try await stat(at: path)
            return true
        } catch {
            return false
        }
    }
    
    /// Default: mkdir without recursion
    func mkdir(at path: URL, name: String) async throws -> URL {
        try await mkdir(at: path, name: name, recursive: false)
    }
    
    /// Default implementation for simple file read (non-streaming)
    func readData(from path: URL) async throws -> Data {
        var result = Data()
        for try await chunk in try await read(from: path) {
            result.append(chunk)
        }
        return result
    }
    
    /// Default implementation for simple file write (non-streaming)
    func writeData(_ data: Data, to path: URL) async throws {
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            continuation.yield(data)
            continuation.finish()
        }
        try await write(to: path, data: stream)
    }
}
