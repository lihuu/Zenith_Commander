//
//  SFTPEndpoint.swift
//  Zenith Commander
//
//  SFTP file system endpoint implementation.
//  Wraps SFTPFileSystemProvider and provides FileOps interface.
//

import Foundation
import mft

/// SFTP file system endpoint
/// Handles sftp:// URLs and remote SFTP operations
/// Does NOT implement UndoSupportingEndpoint - undo not supported for remote operations
class SFTPEndpoint: FileEndpoint {
    /// Endpoint kind - empty host means "generic SFTP handler for any host"
    let kind: EndpointKind
    
    /// The underlying SFTPFileSystemProvider
    private let provider = SFTPFileSystemProvider()
    
    /// FileOps adapter for SFTP operations
    /// Stable instance, reused for the lifetime of this endpoint
    private lazy var _ops: SFTPFileOps = SFTPFileOps(provider: provider)
    
    var ops: FileOps { _ops }
    
    /// Create a generic SFTP endpoint (handles any SFTP host)
    init() {
        // Empty host = generic handler for any SFTP URL
        self.kind = .sftp(host: "", port: 22)
    }
    
    /// Create an SFTP endpoint for a specific host
    init(host: String, port: Int = 22) {
        self.kind = .sftp(host: host, port: port)
    }
    
    func canHandle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "sftp" else { return false }
        
        // If this is a generic handler (empty host), accept any SFTP URL
        if case .sftp(let host, _) = kind, host.isEmpty {
            return true
        }
        
        // Otherwise, check specific host match
        if case .sftp(let eHost, let ePort) = kind {
            let urlHost = url.host ?? ""
            let urlPort = url.port ?? 22
            return eHost == urlHost && ePort == urlPort
        }
        
        return false
    }
    
    /// Get SFTP connection for direct access (used by pipeline)
    func connection(for url: URL) throws -> MFTSftpConnection {
        try provider.connection(for: url)
    }
}

/// SFTP file operations implementation
class SFTPFileOps: FileOps {
    private let provider: SFTPFileSystemProvider
    
    init(provider: SFTPFileSystemProvider) {
        self.provider = provider
    }
    
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let sftp = try provider.connection(for: path)
                    
                    // Read file contents
                    // Using a temp file approach for now
                    let tempFile = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                    
                    try await Task.detached {
                        guard let outputStream = OutputStream(url: tempFile, append: false) else {
                            throw NSError(domain: "SFTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create output stream"])
                        }
                        outputStream.open()
                        defer { outputStream.close() }
                        
                        try sftp.contents(
                            atPath: path.path,
                            toStream: outputStream,
                            fromPosition: 0
                        ) { _, _ in true }
                    }.value
                    
                    // Stream the temp file
                    let data = try Data(contentsOf: tempFile)
                    try? FileManager.default.removeItem(at: tempFile)
                    
                    let chunkSize = 64 * 1024
                    var offset = 0
                    while offset < data.count {
                        let end = min(offset + chunkSize, data.count)
                        continuation.yield(Data(data[offset..<end]))
                        offset = end
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func write(to path: URL, data: AsyncThrowingStream<Data, Error>) async throws {
        // Collect all data first
        var allData = Data()
        for try await chunk in data {
            allData.append(chunk)
        }
        
        // Write via temp file + upload
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try allData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        try await Task.detached { [provider] in
            let sftp = try provider.connection(for: path)
            
            guard let inputStream = InputStream(url: tempFile) else {
                throw NSError(domain: "SFTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create input stream"])
            }
            inputStream.open()
            defer { inputStream.close() }
            
            try sftp.write(
                stream: inputStream,
                toFileAtPath: path.path,
                append: false
            ) { _ in true }
        }.value
    }
    
    func delete(at path: URL) async throws {
        guard let item = FileItem.fromURL(path) else {
            throw NSError(domain: "SFTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid path"])
        }
        try await provider.delete(items: [item])
    }
    
    func list(at path: URL) async throws -> [FileItem] {
        try await provider.loadDirectory(at: path)
    }
    
    func exists(at path: URL) async -> Bool {
        do {
            _ = try await provider.loadDirectory(at: path)
            return true
        } catch {
            return false
        }
    }
    
    func createDirectory(at path: URL, name: String) async throws -> URL {
        let item = try await provider.createDirectory(at: path, name: name)
        return item.path
    }
    
    func createFile(at path: URL, name: String) async throws -> URL {
        let item = try await provider.createFile(at: path, name: name)
        return item.path
    }
    
    func parentDirectory(of path: URL) -> URL {
        provider.parentDirectory(of: path)
    }
}
