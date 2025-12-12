//
//  LocalFileSystemProvider.swift
//  Zenith Commander
//
//  Created by Zenith Commander on 2025/12/05.
//

import Foundation
import AppKit

/// 本地文件系统提供者
class LocalFileSystemProvider: FileSystemProvider {
    var scheme: String { "file" }
    private let fileManager = FileManager.default
    
    func loadDirectory(at path: URL) async throws -> [FileItem] {
        // 检查目录是否存在
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil)
        }
        
        // 检查读取权限
        guard fileManager.isReadableFile(atPath: path.path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: nil)
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            // Start accessing security scoped resource if needed
            let isSecured = path.startAccessingSecurityScopedResource()
            defer {
                if isSecured {
                    path.stopAccessingSecurityScopedResource()
                }
            }
            
            let contents = try fileManager.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey,
                    .isHiddenKey,
                ],
                options: [.skipsHiddenFiles] // 默认不显示隐藏文件，后续可以配置
            )
            
            var files = contents.compactMap { url in
                FileItem.fromURL(url)
            }.sorted { item1, item2 in
                if item1.type == .folder && item2.type != .folder {
                    return true
                } else if item1.type != .folder && item2.type == .folder {
                    return false
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
            
            // 如果不是根目录，添加父目录项
            if path.standardizedFileURL.path != "/" {
                let parentPath = path.standardizedFileURL.deletingLastPathComponent()
                let parentItem = FileItem.parentDirectoryItem(for: parentPath)
                files.insert(parentItem, at: 0)
            }
            
            return files
        }.value
    }
    
    func createDirectory(at path: URL, name: String) async throws -> FileItem {
        let uniqueName = generateUniqueFileName(for: name, in: path)
        let newPath = path.appendingPathComponent(uniqueName)
        
        return try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(writingItemAt: newPath, options: [], error: &coordinationError) { url in
                do {
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                } catch {
                    fileError = error
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
            
            return FileItem.fromURL(newPath)!
        }.value
    }
    
    func createFile(at path: URL, name: String) async throws -> FileItem {
        let uniqueName = generateUniqueFileName(for: name, in: path)
        let newPath = path.appendingPathComponent(uniqueName)
        
        return try await Task.detached {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var fileError: Error?
            
            coordinator.coordinate(writingItemAt: newPath, options: [], error: &coordinationError) { url in
                do {
                    guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
                        throw NSError(domain: "LocalFileSystemProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create file"])
                    }
                } catch {
                    fileError = error
                }
            }
            
            if let error = coordinationError { throw error }
            if let error = fileError { throw error }
            
            return FileItem.fromURL(newPath)!
        }.value
    }
    
    func delete(items: [FileItem]) async throws {
        try await Task.detached {
            for item in items {
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinationError: NSError?
                var fileError: Error?
                
                coordinator.coordinate(writingItemAt: item.path, options: .forDeleting, error: &coordinationError) { url in
                    do {
                        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    } catch {
                        fileError = error
                    }
                }
                
                if let error = coordinationError { throw error }
                if let error = fileError { throw error }
            }
        }.value
    }
    
    func move(items: [FileItem], to destination: URL) async throws {
        try await Task.detached {
            for item in items {
                let uniqueName = self.generateUniqueFileName(for: item.name, in: destination)
                let destURL = destination.appendingPathComponent(uniqueName)
                
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinationError: NSError?
                var fileError: Error?
                
                coordinator.coordinate(writingItemAt: item.path, options: .forMoving, writingItemAt: destURL, options: .forMoving, error: &coordinationError) { newSource, newDest in
                    do {
                        try FileManager.default.moveItem(at: newSource, to: newDest)
                    } catch {
                        fileError = error
                    }
                }
                
                if let error = coordinationError { throw error }
                if let error = fileError { throw error }
            }
        }.value
    }
    
    func copy(items: [FileItem], to destination: URL) async throws {
        try await Task.detached {
            for item in items {
                let uniqueName = self.generateUniqueFileName(for: item.name, in: destination)
                let destURL = destination.appendingPathComponent(uniqueName)
                
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinationError: NSError?
                var fileError: Error?
                
                // For copy, we need read access to source and write access to dest
                coordinator.coordinate(readingItemAt: item.path, options: [], writingItemAt: destURL, options: .forReplacing, error: &coordinationError) { newSource, newDest in
                    do {
                        try FileManager.default.copyItem(at: newSource, to: newDest)
                    } catch {
                        fileError = error
                    }
                }
                
                if let error = coordinationError { throw error }
                if let error = fileError { throw error }
            }
        }.value
    }
    
    func parentDirectory(of path: URL) -> URL {
        return path.deletingLastPathComponent()
    }
    
    func openFile(_ file: FileItem) async {
        _ = await MainActor.run {
            NSWorkspace.shared.open(file.path)
        }
    }
    
    // MARK: - Helper Methods
    
    internal func generateUniqueFileName(for fileName: String, in directory: URL) -> String {
        let destURL = directory.appendingPathComponent(fileName)
        if !fileManager.fileExists(atPath: destURL.path) {
            return fileName
        }
        
        let nameWithoutExtension: String
        let fileExtension: String
        
        if fileName.contains(".") && !fileName.hasPrefix(".") {
            let components = fileName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            if components.count == 2 {
                let lastDotIndex = fileName.lastIndex(of: ".")!
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
        while true {
            let numberedName = "\(nameWithoutExtension) Copy\(counter)\(fileExtension)"
            let numberedURL = directory.appendingPathComponent(numberedName)
            if !fileManager.fileExists(atPath: numberedURL.path) {
                return numberedName
            }
            counter += 1
            if counter > 10000 { return fileName } // Safety break
        }
    }
}
