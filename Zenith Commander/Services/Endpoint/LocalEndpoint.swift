//
//  LocalEndpoint.swift
//  Zenith Commander
//
//  Local file system endpoint implementation.
//  Wraps file operations and provides FileOps interface.
//

import AppKit
import Foundation

/// Local file system endpoint
/// Handles file:// URLs and local file operations
/// Implements UndoSupportingEndpoint for reversible operations
@MainActor
class LocalEndpoint: FileEndpoint, UndoSupportingEndpoint {
    /// Local endpoint kind - singleton pattern
    let kind: EndpointKind = .local
    
    /// Undo manager for local operations (per UndoSupportingEndpoint)
    var undoManager: UndoManager?
    
    /// FileOps adapter for local operations
    /// Stable instance, reused for the lifetime of this endpoint
    private lazy var _ops: LocalFileOps = LocalFileOps(endpoint: self)
    
    var ops: FileOps { _ops }
    
    func canHandle(_ url: URL) -> Bool {
        url.isFileURL || url.scheme == nil || url.scheme == "file"
    }
}

/// Local file operations implementation
/// All IO operations are implemented here - no IO in FileItem
/// Note: This class is NOT MainActor isolated to allow use from Task.detached
class LocalFileOps: FileOps {
    private weak var endpoint: LocalEndpoint?
    
    init(endpoint: LocalEndpoint) {
        self.endpoint = endpoint
    }
    
    // MARK: - Security Scoped Resource Helper (nonisolated, no stored state)
    
    /// Execute block with security-scoped resource access
    nonisolated private func withSecurityScope<T>(for url: URL, _ block: () throws -> T) rethrows -> T {
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try block()
    }
    
    nonisolated private func withSecurityScopeAsync<T>(for url: URL, _ block: () async throws -> T) async rethrows -> T {
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await block()
    }
    
    // MARK: - FileEntry Factory (nonisolated)
    
    /// Create FileEntry from URL using file attributes
    nonisolated private func makeEntry(from url: URL) -> FileEntry? {
        let fileManager = FileManager.default  // Local instance, not stored property
        
        return withSecurityScope(for: url) {
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
                return nil
            }
            
            let fileType: FileEntryType = {
                if let typeAttr = attributes[.type] as? FileAttributeType {
                    switch typeAttr {
                    case .typeDirectory: return .folder
                    case .typeSymbolicLink: return .symlink
                    case .typeRegular: return .file
                    default: return .unknown
                    }
                }
                return .unknown
            }()
            
            return FileEntry(
                name: url.lastPathComponent,
                url: url,
                type: fileType,
                size: attributes[.size] as? Int64,
                modifiedDate: attributes[.modificationDate] as? Date,
                createdDate: attributes[.creationDate] as? Date,
                isHidden: url.lastPathComponent.hasPrefix("."),
                permissions: (attributes[.posixPermissions] as? Int).map { String(format: "%o", $0) }
            )
        }
    }
    
    // MARK: - Directory Operations
    
    func list(at path: URL) async throws -> [FileEntry] {
        let resolvedPath = path.resolvingSymlinksInPath()
        let fileManager = FileManager.default
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedPath.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTDIR),
                          userInfo: [NSLocalizedDescriptionKey: "Not a directory"])
        }
        
        // Check read permission
        guard fileManager.isReadableFile(atPath: resolvedPath.path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: nil)
        }
        
        return try await Task.detached(priority: .userInitiated) { [self] in
            let fileManager = FileManager.default  // Local instance for detached task
            
            // Security scope handled by makeEntry for each URL
            let contents = try fileManager.contentsOfDirectory(
                at: resolvedPath,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey,
                    .isHiddenKey,
                ],
                options: [.skipsHiddenFiles]
            )
            
            return contents.compactMap { makeEntry(from: $0) }
                .sorted { e1, e2 in
                    // Sort by folder first, then name
                    let e1IsFolder = e1.type == .folder
                    let e2IsFolder = e2.type == .folder
                    if e1IsFolder && !e2IsFolder { return true }
                    if !e1IsFolder && e2IsFolder { return false }
                    return e1.name.localizedCaseInsensitiveCompare(e2.name) == .orderedAscending
                }
        }.value
    }
    
    func stat(at path: URL) async throws -> FileEntry {
        guard let entry = makeEntry(from: path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError,
                          userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        return entry
    }
    
    func exists(at path: URL) async throws -> Bool {
        FileManager.default.fileExists(atPath: path.path)
    }
    
    // MARK: - Create Operations
    
    func mkdir(at path: URL, name: String, recursive: Bool) async throws -> URL {
        let uniqueName = generateUniqueFileName(for: name, in: path)
        let newPath = path.appendingPathComponent(uniqueName)
        
        try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(writingItemAt: newPath, options: [], error: &coordinationError) { url in
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: recursive)
                } catch {
                    fileError = error
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
        }.value
        
        // Register undo
        await MainActor.run { [weak self] in
            self?.endpoint?.undoManager?.registerUndo(withTarget: self!) { ops in
                Task {
                    try? await ops.delete(at: newPath)
                }
            }
            self?.endpoint?.undoManager?.setActionName("Create Directory")
        }
        
        return newPath
    }
    
    func createFile(at path: URL, name: String) async throws -> URL {
        let uniqueName = generateUniqueFileName(for: name, in: path)
        let newPath = path.appendingPathComponent(uniqueName)
        
        try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(writingItemAt: newPath, options: [], error: &coordinationError) { url in
                guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
                    fileError = NSError(domain: "LocalFileOps", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to create file"])
                    return
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
        }.value
        
        // Register undo
        await MainActor.run { [weak self] in
            self?.endpoint?.undoManager?.registerUndo(withTarget: self!) { ops in
                Task {
                    try? await ops.delete(at: newPath)
                }
            }
            self?.endpoint?.undoManager?.setActionName("Create File")
        }
        
        return newPath
    }
    
    // MARK: - Modify Operations
    
    func rename(from source: URL, to destination: URL) async throws {
        try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(
                writingItemAt: source, options: .forMoving,
                writingItemAt: destination, options: .forMoving,
                error: &coordinationError
            ) { src, dest in
                do {
                    try FileManager.default.moveItem(at: src, to: dest)
                } catch {
                    fileError = error
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
        }.value
        
        // Register undo
        await MainActor.run { [weak self] in
            self?.endpoint?.undoManager?.registerUndo(withTarget: self!) { ops in
                Task {
                    try? await ops.rename(from: destination, to: source)
                }
            }
            self?.endpoint?.undoManager?.setActionName("Rename")
        }
    }
    
    func trash(at path: URL) async throws {
        let fileManager = FileManager.default
        let originalParent = path.deletingLastPathComponent()
        let originalName = path.lastPathComponent
        var isDir: ObjCBool = false
        let wasFolder = fileManager.fileExists(atPath: path.path, isDirectory: &isDir) && isDir.boolValue
        
        try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(writingItemAt: path, options: .forDeleting, error: &coordinationError) { url in
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    fileError = error
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
        }.value
        
        // Register undo (recreate empty file/folder)
        await MainActor.run { [weak self] in
            self?.endpoint?.undoManager?.registerUndo(withTarget: self!) { ops in
                Task {
                    if wasFolder {
                        _ = try? await ops.mkdir(at: originalParent, name: originalName, recursive: false)
                    } else {
                        _ = try? await ops.createFile(at: originalParent, name: originalName)
                    }
                }
            }
            self?.endpoint?.undoManager?.setActionName("Move to Trash")
        }
    }
    
    func delete(at path: URL) async throws {
        try await Task.detached {
            try FileManager.default.removeItem(at: path)
        }.value
    }
    
    // MARK: - Stream Operations
    
    func read(from path: URL) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task { [self] in
                do {
                    let data = try await withSecurityScopeAsync(for: path) {
                        try Data(contentsOf: path)
                    }
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
        try await withSecurityScopeAsync(for: path) {
            try allData.write(to: path)
        }
    }
    
    // MARK: - Copy Operation
    
    func copy(from source: URL, to destination: URL) async throws {
        // Auto-rename if destination exists
        let destDir = destination.deletingLastPathComponent()
        let uniqueName = generateUniqueFileName(for: destination.lastPathComponent, in: destDir)
        let finalDest = destDir.appendingPathComponent(uniqueName)
        
        try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(
                readingItemAt: source, options: [],
                writingItemAt: finalDest, options: .forReplacing,
                error: &coordinationError
            ) { src, dest in
                do {
                    try FileManager.default.copyItem(at: src, to: dest)
                } catch {
                    fileError = error
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
        }.value
        
        // Register undo
        await MainActor.run { [weak self] in
            self?.endpoint?.undoManager?.registerUndo(withTarget: self!) { ops in
                Task {
                    try? await ops.trash(at: finalDest)
                }
            }
            self?.endpoint?.undoManager?.setActionName("Copy")
        }
    }
    
    // MARK: - Open File
    
    func openFile(at path: URL) async throws {
        let _ = await MainActor.run {
            NSWorkspace.shared.open(path)
        }
    }
    
    // MARK: - Helpers (nonisolated)
    
    nonisolated private func generateUniqueFileName(for fileName: String, in directory: URL) -> String {
        let fileManager = FileManager.default
        let destURL = directory.appendingPathComponent(fileName)
        if !fileManager.fileExists(atPath: destURL.path) {
            return fileName
        }
        
        let nameWithoutExtension: String
        let fileExtension: String
        
        if fileName.contains("."), !fileName.hasPrefix(".") {
            if let lastDotIndex = fileName.lastIndex(of: ".") {
                nameWithoutExtension = String(fileName[..<lastDotIndex])
                fileExtension = String(fileName[lastDotIndex...])
            } else {
                nameWithoutExtension = fileName
                fileExtension = ""
            }
        } else {
            nameWithoutExtension = fileName
            fileExtension = ""
        }
        
        var counter = 1
        while counter < 10000 {
            let numberedName = "\(nameWithoutExtension) Copy\(counter)\(fileExtension)"
            let numberedURL = directory.appendingPathComponent(numberedName)
            if !fileManager.fileExists(atPath: numberedURL.path) {
                return numberedName
            }
            counter += 1
        }
        return fileName
    }
}

// MARK: - Batch Operations (for compatibility)

extension LocalFileOps {
    /// Move multiple items (for compatibility with existing code)
    func move(items: [FileEntry], to destination: URL) async throws {
        for item in items {
            let uniqueName = generateUniqueFileName(for: item.name, in: destination)
            let destPath = destination.appendingPathComponent(uniqueName)
            try await rename(from: item.url, to: destPath)
        }
    }
    
    /// Copy multiple items (for compatibility with existing code)
    func copy(items: [FileEntry], to destination: URL) async throws {
        var copiedPaths: [URL] = []
        
        for item in items {
            let uniqueName = generateUniqueFileName(for: item.name, in: destination)
            let destPath = destination.appendingPathComponent(uniqueName)
            
            try await Task.detached {
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinationError: NSError?
                var fileError: Error?
                
                coordinator.coordinate(
                    readingItemAt: item.url, options: [],
                    writingItemAt: destPath, options: .forReplacing,
                    error: &coordinationError
                ) { src, dest in
                    do {
                        try FileManager.default.copyItem(at: src, to: dest)
                    } catch {
                        fileError = error
                    }
                }
                
                if let error = coordinationError { throw error }
                if let error = fileError { throw error }
            }.value
            
            copiedPaths.append(destPath)
        }
        
        // Register undo
        await MainActor.run { [weak self] in
            self?.endpoint?.undoManager?.registerUndo(withTarget: self!) { ops in
                Task {
                    for path in copiedPaths {
                        try? await ops.trash(at: path)
                    }
                }
            }
            self?.endpoint?.undoManager?.setActionName("Copy Files")
        }
    }
}
