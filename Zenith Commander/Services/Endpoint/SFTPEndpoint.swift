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
@MainActor
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
        self.kind = .sftp(host: "", port: 22)
    }
    
    /// Create an SFTP endpoint for a specific host
    init(host: String, port: Int = 22) {
        self.kind = .sftp(host: host, port: port)
    }
    
    func canHandle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "sftp" else { return false }
        
        if case .sftp(let host, _) = kind, host.isEmpty {
            return true
        }
        
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
    
    // MARK: - Directory Operations
    
    func list(at path: URL) async throws -> [FileEntry] {
        // Use existing provider to get FileItems, then convert to FileEntry
        let items = try await provider.loadDirectory(at: path)
        return items.compactMap { item -> FileEntry? in
            // Skip parent directory items
            if item.name == ".." { return nil }
            
            return FileEntry(
                name: item.name,
                url: item.path,
                type: FileEntryType(from: item.type),
                size: item.size,
                modifiedDate: item.modifiedDate,
                createdDate: item.createdDate,
                isHidden: item.isHidden,
                permissions: item.permissions.isEmpty ? nil : item.permissions
            )
        }
    }
    
    func stat(at path: URL) async throws -> FileEntry {
        // SFTP doesn't have a direct stat method in MFT
        // List the parent directory and filter for the target file
        let sftp = try provider.connection(for: path)
        let parentPath = path.deletingLastPathComponent().path
        let targetName = path.lastPathComponent
        
        return try await Task.detached {
            let items = try sftp.contentsOfDirectory(atPath: parentPath, maxItems: 0)
            
            guard let item = items.first(where: { $0.filename == targetName }) else {
                throw NSError(domain: "SFTP", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "File not found: \(targetName)"])
            }
            
            let type: FileEntryType = {
                if item.isDirectory { return .folder }
                if item.isSymlink { return .symlink }
                return .file
            }()
            
            // Create FileEntry with all values captured inside detached task
            let name = item.filename
            let size = Int64(item.size)
            let modDate = item.mtime
            let createDate = item.createTime
            let isHidden = item.filename.hasPrefix(".")
            let perms = String(format: "%o", item.permissions)
            let ext = path.pathExtension
            
            return FileEntry(
                name: name,
                url: path,
                type: type,
                size: size,
                modifiedDate: modDate,
                createdDate: createDate,
                isHidden: isHidden,
                permissions: perms
            )
        }.value
    }
    
    func exists(at path: URL) async throws -> Bool {
        do {
            _ = try await stat(at: path)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Create Operations
    
    func mkdir(at path: URL, name: String, recursive: Bool) async throws -> URL {
        let item = try await provider.createDirectory(at: path, name: name)
        return item.path
    }
    
    func createFile(at path: URL, name: String) async throws -> URL {
        let item = try await provider.createFile(at: path, name: name)
        return item.path
    }
    
    // MARK: - Modify Operations
    
    func rename(from source: URL, to destination: URL) async throws {
        let sftp = try provider.connection(for: source)
        try await Task.detached {
            try sftp.moveItem(atPath: source.path, toPath: destination.path)
        }.value
    }
    
    func trash(at path: URL) async throws {
        // SFTP has no trash - same as delete
        try await delete(at: path)
    }
    
    func delete(at path: URL) async throws {
        let sftp = try provider.connection(for: path)
        
        // Get file info to determine if directory
        let entry = try await stat(at: path)
        let isFolder = entry.type == .folder  // Capture value before detached task
        
        try await Task.detached {
            if isFolder {
                try sftp.removeDirectory(atPath: path.path)
            } else {
                try sftp.removeFile(atPath: path.path)
            }
        }.value
    }
    
    // MARK: - Stream Operations
    
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let sftp = try provider.connection(for: path)
                    
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
        var allData = Data()
        for try await chunk in data {
            allData.append(chunk)
        }
        
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
}

// MARK: - FileEntryType Conversion

extension FileEntryType {
    init(from fileType: FileType) {
        switch fileType {
        case .folder: self = .folder
        case .file: self = .file
        case .symlink: self = .symlink
        case .unknown: self = .unknown
        }
    }
}
