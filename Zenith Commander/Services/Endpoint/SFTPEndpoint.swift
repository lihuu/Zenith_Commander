//
//  SFTPEndpoint.swift
//  Zenith Commander
//
//  SFTP file system endpoint implementation.
//  Self-contained with connection management - does NOT depend on SFTPFileSystemProvider.
//  SFTPFileSystemProvider should call this, not vice versa.
//

import Foundation
import mft
import os.log

/// SFTP file system endpoint
/// Handles sftp:// URLs and remote SFTP operations
/// Does NOT implement UndoSupportingEndpoint - undo not supported for remote operations
@MainActor
class SFTPEndpoint: FileEndpoint {
    /// Endpoint kind - empty host means "generic SFTP handler for any host"
    let kind: EndpointKind
    
    /// FileOps adapter for SFTP operations
    /// Stable instance, reused for the lifetime of this endpoint
    private lazy var _ops: SFTPFileOps = SFTPFileOps(endpoint: self)
    
    var ops: FileOps { _ops }
    
    // MARK: - Connection Management
    
    /// Cache connections by "user@host:port" key
    /// Using nonisolated(unsafe) because MFTSftpConnection is not Sendable,
    /// but we ensure thread safety via connectionLock
    private nonisolated(unsafe) var connections: [String: MFTSftpConnection] = [:]
    private let connectionLock = NSLock()
    
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
    
    // MARK: - Connection Access
    
    nonisolated private func getConnectionKey(for url: URL) -> String {
        let user = url.user ?? ""
        let host = url.host ?? ""
        let port = url.port ?? 22
        return "\(user)@\(host):\(port)"
    }
    
    /// Get or create SFTP connection for URL
    nonisolated func connection(for url: URL) throws -> MFTSftpConnection {
        let key = getConnectionKey(for: url)
        
        connectionLock.lock()
        if let existing = connections[key] {
            connectionLock.unlock()
            return existing
        }
        connectionLock.unlock()
        
        // Create new connection
        guard let host = url.host else {
            throw NSError(
                domain: "SFTPEndpoint",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing host"]
            )
        }
        
        let port = url.port ?? 22
        let username = url.user ?? ""
        let password = url.password ?? ""
        
        Logger.fileSystem.debug(
            "Connecting to SFTP: \(username)@\(host):\(port)"
        )
        
        let sftp = MFTSftpConnection(
            hostname: host,
            port: port,
            username: username,
            password: password
        )
        
        do {
            try sftp.connect()
            try sftp.authenticate()
            
            connectionLock.lock()
            connections[key] = sftp
            connectionLock.unlock()
            Logger.fileSystem.debug(
                "Connected to SFTP: \(username)@\(host):\(port)"
            )
            
            return sftp
        } catch {
            Logger.fileSystem.error(
                "SFTP Connection failed: \(error.localizedDescription)"
            )
            throw error
        }
    }
}

/// SFTP file operations implementation
/// Self-contained - uses SFTPEndpoint directly, no provider dependency
class SFTPFileOps: FileOps {
    private weak var endpoint: SFTPEndpoint?
    
    init(endpoint: SFTPEndpoint) {
        self.endpoint = endpoint
    }
    
    // MARK: - Connection Helper
    
    private func getConnection(for url: URL) throws -> MFTSftpConnection {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        return try endpoint.connection(for: url)
    }
    
    // MARK: - Directory Operations
    
    func list(at path: URL) async throws -> [FileEntry] {
        // Capture what we need before Task.detached
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        
        return try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: path)
            let remotePath = path.path
            let items = try sftp.contentsOfDirectory(atPath: remotePath, maxItems: 0)
            
            var entries: [FileEntry] = []
            
            for item in items {
                let name = item.filename
                if name == "." || name == ".." { continue }
                
                let type: FileEntryType = {
                    if item.isDirectory { return .folder }
                    if item.isSymlink { return .symlink }
                    return .file
                }()
                
                let itemPath = path.appendingPathComponent(name)
                
                entries.append(FileEntry(
                    name: name,
                    url: itemPath,
                    type: type,
                    size: Int64(item.size),
                    modifiedDate: item.mtime,
                    createdDate: item.createTime,
                    isHidden: name.hasPrefix("."),
                    permissions: String(format: "%o", item.permissions)
                ))
            }
            
            return entries
        }.value
    }
    
    func stat(at path: URL) async throws -> FileEntry {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        let parentPath = path.deletingLastPathComponent().path
        let targetName = path.lastPathComponent
        
        return try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: path)
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
            
            let name = item.filename
            let size = Int64(item.size)
            let modDate = item.mtime
            let createDate = item.createTime
            let isHidden = item.filename.hasPrefix(".")
            let perms = String(format: "%o", item.permissions)
            
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
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        let newPath = path.appendingPathComponent(name)
        
        try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: path)
            try sftp.createDirectory(atPath: newPath.path)
        }.value
        
        return newPath
    }
    
    func createFile(at path: URL, name: String) async throws -> URL {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        let newPath = path.appendingPathComponent(name)
        
        try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: path)
            let data = Data()
            let stream = InputStream(data: data)
            try sftp.write(
                stream: stream,
                toFileAtPath: newPath.path,
                append: false
            ) { _ in true }
        }.value
        
        return newPath
    }
    
    // MARK: - Modify Operations
    
    func rename(from source: URL, to destination: URL) async throws {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: source)
            try sftp.moveItem(atPath: source.path, toPath: destination.path)
        }.value
    }
    
    func trash(at path: URL) async throws {
        // SFTP has no trash - same as delete
        try await delete(at: path)
    }
    
    func delete(at path: URL) async throws {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        let entry = try await stat(at: path)
        let isFolder = entry.type == .folder
        
        try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: path)
            if isFolder {
                try sftp.removeDirectory(atPath: path.path)
            } else {
                try sftp.removeFile(atPath: path.path)
            }
        }.value
    }
    
    // MARK: - Stream Operations
    
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error> {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        
        return AsyncThrowingStream { continuation in
            Task.detached { [endpoint] in
                do {
                    let sftp = try endpoint.connection(for: path)
                    
                    let tempFile = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                    
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
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        
        var allData = Data()
        for try await chunk in data {
            allData.append(chunk)
        }
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try allData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: path)
            
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
    
    // MARK: - Copy Operation
    
    func copy(from source: URL, to destination: URL) async throws {
        guard let endpoint = endpoint else {
            throw NSError(domain: "SFTPFileOps", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Endpoint deallocated"])
        }
        
        try await Task.detached { [endpoint] in
            let sftp = try endpoint.connection(for: source)
            try sftp.copyItem(
                atPath: source.path,
                toFileAtPath: destination.path,
                progress: nil
            )
        }.value
    }
    
    // MARK: - Open File
    
    func openFile(at path: URL) async throws {
        // TODO: Remote file open - download to temp and open with NSWorkspace
        throw NSError(
            domain: "SFTPFileOps",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Opening remote files is not yet supported. Download the file first."]
        )
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
