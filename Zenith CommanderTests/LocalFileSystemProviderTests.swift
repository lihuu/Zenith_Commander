//
//  LocalFileSystemProviderTests.swift
//  Zenith CommanderTests
//
//  Tests for local file system operations using FileSystemService.
//  Updated to use the new endpoint architecture.
//

import Foundation
import Testing
@testable import Zenith_Commander

@MainActor
struct LocalFileSystemProviderTests {
    // MARK: - File Operations Tests

    @Test func deleteFile() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("todelete.txt")
        fileManager.createFile(atPath: fileURL.path, contents: Data("hello".utf8))

        guard let item = await FileItem.fromURL(fileURL) else {
            Issue.record("Failed to create FileItem from URL")
            return
        }
        try await service.trashFiles([item])

        // Should be in trash or deleted
        #expect(!fileManager.fileExists(atPath: fileURL.path))
    }

    @Test func moveFile() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let sourceDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_Src_\(UUID().uuidString)")
        let destDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_Dest_\(UUID().uuidString)")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: sourceDir)
            try? fileManager.removeItem(at: destDir)
        }

        let fileName = "moveMe.txt"
        let sourceURL = sourceDir.appendingPathComponent(fileName)
        fileManager.createFile(atPath: sourceURL.path, contents: Data("move".utf8))

        guard let item = await FileItem.fromURL(sourceURL) else {
            Issue.record("Failed to create FileItem from URL")
            return
        }
        try await service.moveFiles([item], to: destDir)

        #expect(!fileManager.fileExists(atPath: sourceURL.path))
        #expect(fileManager.fileExists(atPath: destDir.appendingPathComponent(fileName).path))
    }

    @Test func copyFile() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let sourceDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_Src_\(UUID().uuidString)")
        let destDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_Dest_\(UUID().uuidString)")
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: sourceDir)
            try? fileManager.removeItem(at: destDir)
        }

        let fileName = "copyMe.txt"
        let sourceURL = sourceDir.appendingPathComponent(fileName)
        fileManager.createFile(atPath: sourceURL.path, contents: Data("copy".utf8))

        guard let item = await FileItem.fromURL(sourceURL) else {
            Issue.record("Failed to create FileItem from URL")
            return
        }
        try await service.copyFiles([item], to: destDir)

        #expect(fileManager.fileExists(atPath: sourceURL.path))
        #expect(fileManager.fileExists(atPath: destDir.appendingPathComponent(fileName).path))
    }

    // MARK: - Auto-rename Tests (via createDirectory/createFile)

    @Test func createFile_WithConflict_AutoRename() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Create an existing file
        let existingFile = tempDir.appendingPathComponent("test.txt")
        fileManager.createFile(atPath: existingFile.path, contents: nil)

        // Creating a file with the same name should auto-rename
        let createdURL = try await service.createFile(at: tempDir, name: "test.txt")

        #expect(fileManager.fileExists(atPath: createdURL.path))
        #expect(createdURL.lastPathComponent == "test Copy1.txt")
    }

    @Test func createDirectory_WithConflict_AutoRename() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Create an existing folder
        let existingFolder = tempDir.appendingPathComponent("MyFolder")
        try fileManager.createDirectory(at: existingFolder, withIntermediateDirectories: false)

        // Creating a folder with the same name should auto-rename
        let createdURL = try await service.createDirectory(at: tempDir, name: "MyFolder")

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: createdURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(createdURL.lastPathComponent == "MyFolder Copy1")
    }

    @Test func createFile_NoExtension_AutoRename() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Create an existing file without extension
        let existingFile = tempDir.appendingPathComponent("README")
        fileManager.createFile(atPath: existingFile.path, contents: nil)

        // Creating a file with the same name should auto-rename
        let createdURL = try await service.createFile(at: tempDir, name: "README")

        #expect(fileManager.fileExists(atPath: createdURL.path))
        #expect(createdURL.lastPathComponent == "README Copy1")
    }

    @Test func createFile_HiddenFile_AutoRename() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Create an existing hidden file
        let existingFile = tempDir.appendingPathComponent(".gitignore")
        fileManager.createFile(atPath: existingFile.path, contents: nil)

        // Creating a file with the same name should auto-rename
        let createdURL = try await service.createFile(at: tempDir, name: ".gitignore")

        #expect(fileManager.fileExists(atPath: createdURL.path))
        #expect(createdURL.lastPathComponent == ".gitignore Copy1")
    }
}
