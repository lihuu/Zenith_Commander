//
//  LocalEndpoint.swift
//  Zenith Commander
//
//  Local file system endpoint implementation.
//  Wraps LocalFileSystemProvider and provides FileOps interface.
//

import Foundation

/// Local file system endpoint
/// Handles file:// URLs and local file operations
class LocalEndpoint: FileEndpoint {
    let scheme = "file"
    
    /// Undo manager for local operations (user decision: stays in LocalFileOps)
    var undoManager: UndoManager?
    
    /// The underlying LocalFileSystemProvider
    private let provider = LocalFileSystemProvider()
    
    /// FileOps adapter for local operations
    private lazy var _ops: LocalFileOps = LocalFileOps(endpoint: self, provider: provider)
    
    var ops: FileOps { _ops }
    
    func canHandle(_ url: URL) -> Bool {
        url.isFileURL || url.scheme == nil || url.scheme == "file"
    }
}

/// Local file operations implementation
class LocalFileOps: FileOps {
    private weak var endpoint: LocalEndpoint?
    private let provider: LocalFileSystemProvider
    private let fileManager = FileManager.default
    
    init(endpoint: LocalEndpoint, provider: LocalFileSystemProvider) {
        self.endpoint = endpoint
        self.provider = provider
    }
    
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let data = try Data(contentsOf: path)
                    // Chunk the data for streaming (64KB chunks)
                    let chunkSize = 64 * 1024
                    var offset = 0
                    while offset < data.count {
                        let end = min(offset + chunkSize, data.count)
                        let chunk = data[offset..<end]
                        continuation.yield(Data(chunk))
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
        try allData.write(to: path)
    }
    
    func delete(at path: URL) async throws {
        // Use provider's delete for undo support
        if let undoManager = endpoint?.undoManager {
            provider.undoManager = undoManager
            defer { provider.undoManager = nil }
        }
        
        guard let item = FileItem.fromURL(path) else {
            try fileManager.trashItem(at: path, resultingItemURL: nil)
            return
        }
        try await provider.delete(items: [item])
    }
    
    func list(at path: URL) async throws -> [FileItem] {
        try await provider.loadDirectory(at: path)
    }
    
    func exists(at path: URL) async -> Bool {
        fileManager.fileExists(atPath: path.path)
    }
    
    func createDirectory(at path: URL, name: String) async throws -> URL {
        if let undoManager = endpoint?.undoManager {
            provider.undoManager = undoManager
            defer { provider.undoManager = nil }
        }
        let item = try await provider.createDirectory(at: path, name: name)
        return item.path
    }
    
    func createFile(at path: URL, name: String) async throws -> URL {
        if let undoManager = endpoint?.undoManager {
            provider.undoManager = undoManager
            defer { provider.undoManager = nil }
        }
        let item = try await provider.createFile(at: path, name: name)
        return item.path
    }
    
    func parentDirectory(of path: URL) -> URL {
        provider.parentDirectory(of: path)
    }
}

// MARK: - Local-specific extensions for undo support

extension LocalFileOps {
    /// Move with undo support (local-only)
    func move(items: [FileItem], to destination: URL) async throws {
        if let undoManager = endpoint?.undoManager {
            provider.undoManager = undoManager
            defer { provider.undoManager = nil }
        }
        try await provider.move(items: items, to: destination)
    }
    
    /// Copy with undo support (local-only)
    func copy(items: [FileItem], to destination: URL) async throws {
        if let undoManager = endpoint?.undoManager {
            provider.undoManager = undoManager
            defer { provider.undoManager = nil }
        }
        try await provider.copy(items: items, to: destination)
    }
}
