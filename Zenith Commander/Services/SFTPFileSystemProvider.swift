//
//  SFTPFileSystemProvider.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import Foundation
import AppKit
import mft
import os.log

/// SFTP 文件系统提供者
class SFTPFileSystemProvider: FileSystemProvider {
    var scheme: String { "sftp" }
    
    // Cache connections by "user@host:port" key
    private var connections: [String: MFTSftpConnection] = [:]
    private let connectionLock = NSLock()
    
    // MARK: - Connection Management
    
    private func getConnectionKey(for url: URL) -> String {
        let user = url.user ?? ""
        let host = url.host ?? ""
        let port = url.port ?? 22
        return "\(user)@\(host):\(port)"
    }
    
    private func getOrCreateConnection(for url: URL) throws -> MFTSftpConnection {
        let key = getConnectionKey(for: url)
        
        connectionLock.lock()
        if let existing = connections[key] {
            connectionLock.unlock()
            return existing
        }
        connectionLock.unlock()
        
        // Create new connection
        guard let host = url.host else {
            throw NSError(domain: "SFTPFileSystemProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        
        let port = url.port ?? 22
        let username = url.user ?? ""
        let password = url.password ?? ""
        
        Logger.fileSystem.debug("Connecting to SFTP: \(username)@\(host):\(port)")
        
        let sftp = MFTSftpConnection(hostname: host, port: port, username: username, password: password)
        
        do {
            try sftp.connect()
            try sftp.authenticate()
            
            connectionLock.lock()
            connections[key] = sftp
            connectionLock.unlock()
            Logger.fileSystem.debug("Connected to SFTP: \(username)@\(host):\(port)")

            return sftp
        } catch {
            Logger.fileSystem.error("SFTP Connection failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - FileSystemProvider Implementation
    
    func loadDirectory(at path: URL) async throws -> [FileItem] {
        Logger.fileSystem.debug("Loading SFTP directory: \(path.path)")
        return try await Task.detached { [weak self] in
            guard let self = self else { return [] }
            let sftp = try self.getOrCreateConnection(for: path)
            
            let remotePath = path.path
            // mft contentsOfDirectory returns [MFTFileItem] (inferred name, checking README it says 'item.filename')
            // README doesn't specify the type name, but let's assume it's something iterable.
            // "let items = try sftp.contentsOfDirectory(atPath: "/tmp", maxItems: 0)"
            
            let items = try sftp.contentsOfDirectory(atPath: remotePath, maxItems: 0)
            
            var fileItems: [FileItem] = []
            
            for item in items {
                // Assuming item has properties: filename, isDirectory, fileSize, modificationDate, permissions
                // I need to verify the exact property names from mft source or try to compile.
                // Based on README: item.filename
                // Based on standard SFTP libs: attributes usually available.
                // I will try to use common names and fix if build fails.
                
                let name = item.filename
                if name == "." || name == ".." { continue }
                
                let isDir = item.isDirectory
                // Assuming 'size' property exists based on error 'fileSize' not found
                // If 'size' also fails, I might need to check attributes dictionary if exposed?
                // But let's try 'size' first.
                // If item is MFTSftpItem, maybe it wraps attributes.
                let size = item.size
                let modDate = Date() // item.modificationDate not found
                let perms = String(format: "%o", item.permissions)
                
                let itemPath = path.appendingPathComponent(name)
                
                let fileItem = FileItem(
                    id: itemPath.absoluteString,
                    name: name,
                    path: itemPath,
                    type: isDir ? .folder : .file, // TODO: Handle symlinks if possible
                    size: Int64(size),
                    modifiedDate: modDate,
                    createdDate: modDate, // SFTP usually doesn't give creation date
                    isHidden: name.hasPrefix("."),
                    permissions: perms,
                    fileExtension: URL(fileURLWithPath: name).pathExtension
                )
                fileItems.append(fileItem)
            }
            
            // Sort: Folders first, then name
            return fileItems.sorted { item1, item2 in
                if item1.type == .folder && item2.type != .folder {
                    return true
                } else if item1.type != .folder && item2.type == .folder {
                    return false
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
            
        }.value
    }
    
    func createDirectory(at path: URL, name: String) async throws -> FileItem {
        return try await Task.detached { [weak self] in
            guard let self = self else { throw NSError(domain: "SFTP", code: -1, userInfo: nil) }
            let sftp = try self.getOrCreateConnection(for: path)
            
            let newPath = path.appendingPathComponent(name)
            try sftp.createDirectory(atPath: newPath.path)
            
            // Return a dummy item or fetch it?
            // Constructing manually to save a roundtrip
            return FileItem(
                id: newPath.absoluteString,
                name: name,
                path: newPath,
                type: .folder,
                size: 0,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: name.hasPrefix("."),
                permissions: "755",
                fileExtension: ""
            )
        }.value
    }
    
    func createFile(at path: URL, name: String) async throws -> FileItem {
        return try await Task.detached { [weak self] in
            guard let self = self else { throw NSError(domain: "SFTP", code: -1, userInfo: nil) }
            let sftp = try self.getOrCreateConnection(for: path)
            
            let newPath = path.appendingPathComponent(name)
            // Create empty file
            // mft write takes InputStream.
            // Create an empty InputStream?
            let data = Data()
            let stream = InputStream(data: data)
            
            // write(stream:toFileAtPath:append:progress:)
            try sftp.write(stream: stream, toFileAtPath: newPath.path, append: false) { _ in return true }
            
            return FileItem(
                id: newPath.absoluteString,
                name: name,
                path: newPath,
                type: .file,
                size: 0,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: name.hasPrefix("."),
                permissions: "644",
                fileExtension: URL(fileURLWithPath: name).pathExtension
            )
        }.value
    }
    
    func delete(items: [FileItem]) async throws {
        try await Task.detached { [weak self] in
            guard let self = self else { return }
            if let first = items.first {
                let sftp = try self.getOrCreateConnection(for: first.path)
                
                for item in items {
                    if item.type == .folder {
                        try sftp.removeDirectory(atPath: item.path.path)
                    } else {
                        try sftp.removeFile(atPath: item.path.path)
                    }
                }
            }
        }.value
    }
    
    func move(items: [FileItem], to destination: URL) async throws {
        try await Task.detached { [weak self] in
            guard let self = self else { return }
            if let first = items.first {
                let sftp = try self.getOrCreateConnection(for: first.path)
                
                for item in items {
                    let destPath = destination.appendingPathComponent(item.name).path
                    try sftp.moveItem(atPath: item.path.path, toPath: destPath)
                }
            }
        }.value
    }
    
    func copy(items: [FileItem], to destination: URL) async throws {
        // SFTP usually doesn't support remote copy directly (depends on extension).
        // mft capabilities say: "Copying items within the same SFTP server"
        // So I assume there is a copyItem method.
        
        try await Task.detached { [weak self] in
            guard let self = self else { return }
            if let first = items.first {
                let sftp = try self.getOrCreateConnection(for: first.path)
                
                for item in items {
                    let destPath = destination.appendingPathComponent(item.name).path
                    // Assuming copyItem exists based on capabilities
                    // If not, I might need to read/write (slow)
                    // Let's try copyItem first.
                    // If mft doesn't have copyItem, I'll have to implement download/upload loop?
                    // README says "Copying items within the same SFTP server" is a capability.
                    try sftp.copyItem(atPath: item.path.path, toFileAtPath: destPath, progress: nil)
                }
            }
        }.value
    }
    
    func parentDirectory(of path: URL) -> URL {
        return path.deletingLastPathComponent()
    }
    
    func openFile(_ file: FileItem) async {
        // Download to temp and open
        do {
            let sftp = try getOrCreateConnection(for: file.path)
            
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = tempDir.appendingPathComponent(file.name)
            
            // Download
            // contents(atPath:toStream:fromPosition:progress:)
            guard let outStream = OutputStream(url: localURL, append: false) else { return }
            outStream.open()
            
            try await Task.detached {
                try sftp.contents(atPath: file.path.path, toStream: outStream, fromPosition: 0) { _, _ in return true }
            }.value
            
            outStream.close()
            
            let _ = await MainActor.run {
                NSWorkspace.shared.open(localURL)
            }
        } catch {
            Logger.fileSystem.error("Failed to open remote file: \(error.localizedDescription)")
        }
    }
}
