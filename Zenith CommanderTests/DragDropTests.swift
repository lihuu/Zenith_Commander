//
//  DragDropTests.swift
//  Zenith CommanderTests
//
//  Tests for drag-and-drop file move/copy functionality
//

import XCTest
@testable import Zenith_Commander

final class DragDropTests: XCTestCase {
    var tempDirectory: URL!
    var sourceFolder: URL!
    var destFolder: URL!
    var testFile: URL!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZenithCommanderDragDropTests")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        // Create source and destination folders
        sourceFolder = tempDirectory.appendingPathComponent("source")
        destFolder = tempDirectory.appendingPathComponent("dest")

        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

        // Create a test file in source folder
        testFile = sourceFolder.appendingPathComponent("testfile.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
    }

    @MainActor
    override func tearDown() async throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - File Move Tests

    @MainActor
    func testMoveFileToFolder() async throws {
        // Test moving a file to a different folder
        let destURL = destFolder.appendingPathComponent(testFile.lastPathComponent)

        // Verify source exists and dest doesn't
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Source file should exist")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destURL.path), "Destination should not exist yet")

        // Perform move
        try FileManager.default.moveItem(at: testFile, to: destURL)

        // Verify move succeeded
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path), "Source file should be gone")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "File should exist at destination")

        // Verify content
        let content = try String(contentsOf: destURL, encoding: .utf8)
        XCTAssertEqual(content, "Test content", "File content should be preserved")
    }

    @MainActor
    func testCopyFileToFolder() async throws {
        // Test copying a file to a different folder
        let destURL = destFolder.appendingPathComponent(testFile.lastPathComponent)

        // Verify source exists and dest doesn't
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Source file should exist")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destURL.path), "Destination should not exist yet")

        // Perform copy
        try FileManager.default.copyItem(at: testFile, to: destURL)

        // Verify copy succeeded
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Source file should still exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "File should exist at destination")

        // Verify content in both locations
        let sourceContent = try String(contentsOf: testFile, encoding: .utf8)
        let destContent = try String(contentsOf: destURL, encoding: .utf8)
        XCTAssertEqual(sourceContent, "Test content", "Source content should be unchanged")
        XCTAssertEqual(destContent, "Test content", "Destination content should match source")
    }

    @MainActor
    func testMoveMultipleFilesToFolder() async throws {
        // Create multiple test files
        let file1 = sourceFolder.appendingPathComponent("file1.txt")
        let file2 = sourceFolder.appendingPathComponent("file2.txt")
        let file3 = sourceFolder.appendingPathComponent("file3.txt")

        try "Content 1".write(to: file1, atomically: true, encoding: .utf8)
        try "Content 2".write(to: file2, atomically: true, encoding: .utf8)
        try "Content 3".write(to: file3, atomically: true, encoding: .utf8)

        let files = [file1, file2, file3]

        // Move all files
        for file in files {
            let destURL = destFolder.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.moveItem(at: file, to: destURL)
        }

        // Verify all files moved
        for file in files {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "Source \(file.lastPathComponent) should be gone")
            let destURL = destFolder.appendingPathComponent(file.lastPathComponent)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "\(file.lastPathComponent) should exist at destination")
        }
    }

    @MainActor
    func testMoveToSameDirectory() async throws {
        // Test that moving to the same directory creates a copy instead
        let destURL = sourceFolder.appendingPathComponent("testfile_copy.txt")

        // Perform copy (since move in same directory doesn't make sense)
        try FileManager.default.copyItem(at: testFile, to: destURL)

        // Verify both files exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Original should still exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "Copy should exist")
    }

    // MARK: - Name Collision Tests

    @MainActor
    func testMoveWithExistingFileName() async throws {
        // Create a file with same name in destination
        let existingFile = destFolder.appendingPathComponent(testFile.lastPathComponent)
        try "Existing content".write(to: existingFile, atomically: true, encoding: .utf8)

        // Attempt to move should fail
        XCTAssertThrowsError(try FileManager.default.moveItem(at: testFile, to: existingFile)) { error in
            // Verify it's a file exists error
            XCTAssertTrue((error as NSError).code == NSFileWriteFileExistsError, "Should be a file exists error")
        }

        // Verify original files unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Source should still exist")
        let existingContent = try String(contentsOf: existingFile, encoding: .utf8)
        XCTAssertEqual(existingContent, "Existing content", "Existing file should be unchanged")
    }

    @MainActor
    func testGenerateUniqueFileName() async throws {
        // Test generating unique filename when destination exists
        let existingFile = destFolder.appendingPathComponent(testFile.lastPathComponent)
        try "Existing content".write(to: existingFile, atomically: true, encoding: .utf8)

        // Generate unique URL
        let uniqueURL = generateUniqueURL(for: existingFile)

        XCTAssertNotEqual(uniqueURL, existingFile, "Unique URL should be different")
        XCTAssertFalse(FileManager.default.fileExists(atPath: uniqueURL.path), "Unique URL should not exist yet")

        // Move to unique URL
        try FileManager.default.moveItem(at: testFile, to: uniqueURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: uniqueURL.path), "File should exist at unique URL")
    }

    // MARK: - Folder Operations

    @MainActor
    func testMoveFolderToFolder() async throws {
        // Create a folder with files
        let subFolder = sourceFolder.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subFolder, withIntermediateDirectories: true)

        let fileInSubfolder = subFolder.appendingPathComponent("nested.txt")
        try "Nested content".write(to: fileInSubfolder, atomically: true, encoding: .utf8)

        // Move entire folder
        let destSubfolder = destFolder.appendingPathComponent(subFolder.lastPathComponent)
        try FileManager.default.moveItem(at: subFolder, to: destSubfolder)

        // Verify folder and contents moved
        XCTAssertFalse(FileManager.default.fileExists(atPath: subFolder.path), "Source folder should be gone")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destSubfolder.path), "Folder should exist at destination")

        let destFile = destSubfolder.appendingPathComponent("nested.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destFile.path), "Nested file should exist")

        let content = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertEqual(content, "Nested content", "Nested file content should be preserved")
    }

    // MARK: - Helper Functions

    private func generateUniqueURL(for url: URL) -> URL {
        var destURL = url
        var counter = 1
        let fileExtension = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent
        let directory = url.deletingLastPathComponent()

        while FileManager.default.fileExists(atPath: destURL.path) {
            let newName = "\(baseName) \(counter)"
            destURL = directory.appendingPathComponent(newName)
            if !fileExtension.isEmpty {
                destURL = destURL.appendingPathExtension(fileExtension)
            }
            counter += 1
        }

        return destURL
    }
}
