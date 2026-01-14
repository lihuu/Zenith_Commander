//
//  FileOps.swift
//  Zenith Commander
//
//  Core file operations protocol for the Endpoint architecture.
//  This is the only interface that GenericTransferPipeline depends on.
//

import Foundation

/// Core file operations protocol
/// Defines stream-based operations that all file system implementations must provide.
/// This protocol is designed to be protocol-agnostic and supports generic transfer pipelines.
protocol FileOps: AnyObject {
    /// Read file contents as async byte stream
    /// - Parameter path: Path to the file
    /// - Returns: Async stream of data chunks
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error>
    
    /// Write data stream to a file
    /// - Parameters:
    ///   - path: Destination file path
    ///   - data: Async stream of data chunks to write
    func write(to path: URL, data: AsyncThrowingStream<Data, Error>) async throws
    
    /// Delete a file or directory
    /// - Parameter path: Path to delete
    func delete(at path: URL) async throws
    
    /// List directory contents
    /// - Parameter path: Directory path
    /// - Returns: Array of FileItem (preserving existing type per user decision)
    func list(at path: URL) async throws -> [FileItem]
    
    /// Check if path exists
    /// - Parameter path: Path to check
    /// - Returns: True if exists
    func exists(at path: URL) async -> Bool
    
    /// Create a directory
    /// - Parameters:
    ///   - path: Parent directory path
    ///   - name: Name of new directory
    /// - Returns: Created directory path
    func createDirectory(at path: URL, name: String) async throws -> URL
    
    /// Create an empty file
    /// - Parameters:
    ///   - path: Parent directory path
    ///   - name: Name of new file
    /// - Returns: Created file path
    func createFile(at path: URL, name: String) async throws -> URL
    
    /// Get parent directory
    /// - Parameter path: Current path
    /// - Returns: Parent directory path
    func parentDirectory(of path: URL) -> URL
}

/// Extension for optional streaming support
/// Some implementations may provide simpler non-streaming operations
extension FileOps {
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
