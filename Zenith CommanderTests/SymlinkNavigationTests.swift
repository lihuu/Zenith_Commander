//
//  SymlinkNavigationTests.swift
//  Zenith CommanderTests
//
//  Tests for symlink navigation behavior
//

import Foundation
import Testing
@testable import Zenith_Commander

@MainActor
struct SymlinkNavigationTests {
    
    // MARK: - Test Setup Helpers
    
    /// Create a temporary test directory with symlinks
    private func createTestEnvironment() throws -> (tempDir: URL, folderLink: URL, fileLink: URL, cleanup: () -> Void) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithSymlinkTest_\(UUID().uuidString)")
        
        // Create test structure
        let realFolder = tempDir.appendingPathComponent("real_folder")
        let realFile = tempDir.appendingPathComponent("real_file.txt")
        let folderLink = tempDir.appendingPathComponent("link_to_folder")
        let fileLink = tempDir.appendingPathComponent("link_to_file")
        
        // Create directories and files
        try fileManager.createDirectory(at: realFolder, withIntermediateDirectories: true)
        fileManager.createFile(atPath: realFile.path, contents: "test content".data(using: .utf8))
        
        // Create symlinks
        try fileManager.createSymbolicLink(at: folderLink, withDestinationURL: realFolder)
        try fileManager.createSymbolicLink(at: fileLink, withDestinationURL: realFile)
        
        let cleanup: () -> Void = {
            _ = try? fileManager.removeItem(at: tempDir)
        }
        
        return (tempDir, folderLink, fileLink, cleanup)
    }
    
    // MARK: - FileItem Symlink Detection Tests
    
    @Test func testSymlinkFileItemType() throws {
        let (tempDir, folderLink, fileLink, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Create FileItems from symlinks
        let folderLinkItem = FileItem.fromURL(folderLink)
        let fileLinkItem = FileItem.fromURL(fileLink)
        
        // Both should be identified as symlinks
        #expect(folderLinkItem?.isSymlink == true)
        #expect(fileLinkItem?.isSymlink == true)
        
        // isFolder should be false for symlinks (that's why we need the fix)
        #expect(folderLinkItem?.isFolder == false)
        #expect(fileLinkItem?.isFolder == false)
    }
    
    // MARK: - Symlink Resolution Tests
    
    @Test func testSymlinkToFolderResolution() throws {
        let (tempDir, folderLink, _, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Resolve the symlink
        let resolvedPath = folderLink.resolvingSymlinksInPath()
        
        // Check that resolved path is a directory
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolvedPath.path, isDirectory: &isDir)
        
        #expect(exists)
        #expect(isDir.boolValue)
        #expect(resolvedPath.lastPathComponent == "real_folder")
    }
    
    @Test func testSymlinkToFileResolution() throws {
        let (tempDir, _, fileLink, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Resolve the symlink
        let resolvedPath = fileLink.resolvingSymlinksInPath()
        
        // Check that resolved path is a file
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolvedPath.path, isDirectory: &isDir)
        
        #expect(exists)
        #expect(!isDir.boolValue)
        #expect(resolvedPath.lastPathComponent == "real_file.txt")
    }
    
    // MARK: - Navigation Logic Tests
    
    @Test func testShouldNavigateIntoSymlinkFolder() throws {
        let (tempDir, folderLink, _, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Create a FileItem for the folder symlink
        guard let fileItem = FileItem.fromURL(folderLink) else {
            Issue.record("Failed to create FileItem from folder symlink")
            return
        }
        
        // Simulate the navigation logic from enterDirectory()
        var shouldNavigate = fileItem.isFolder
        var targetPath = fileItem.path
        
        if fileItem.isSymlink {
            let resolvedPath = fileItem.path.resolvingSymlinksInPath()
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolvedPath.path, isDirectory: &isDir), isDir.boolValue {
                targetPath = resolvedPath
                shouldNavigate = true
            }
        }
        
        // Should navigate into the folder
        #expect(shouldNavigate)
        #expect(targetPath.lastPathComponent == "real_folder")
    }
    
    @Test func testShouldNotNavigateIntoSymlinkFile() throws {
        let (tempDir, _, fileLink, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Create a FileItem for the file symlink
        guard let fileItem = FileItem.fromURL(fileLink) else {
            Issue.record("Failed to create FileItem from file symlink")
            return
        }
        
        // Simulate the navigation logic from enterDirectory()
        var shouldNavigate = fileItem.isFolder
        var targetPath = fileItem.path
        
        if fileItem.isSymlink {
            let resolvedPath = fileItem.path.resolvingSymlinksInPath()
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: resolvedPath.path, isDirectory: &isDir), isDir.boolValue {
                targetPath = resolvedPath
                shouldNavigate = true
            }
        }
        
        // Should NOT navigate, should open file instead
        #expect(!shouldNavigate)
    }
    
    // MARK: - AppState Integration Tests
    
    @Test func testAppStateEnterDirectoryWithSymlink() async throws {
        let (tempDir, folderLink, _, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Create AppState and navigate to temp directory
        let appState = AppState()
        let service = FileSystemService.shared
        
        // Load the temp directory
        let files = await service.loadDirectory(at: tempDir)
        appState.currentPane.activeTab.currentPath = tempDir
        appState.currentPane.activeTab.files = files
        
        // Find the folder symlink in the file list
        guard let symlinkIndex = files.firstIndex(where: { $0.name == "link_to_folder" }) else {
            Issue.record("Folder symlink not found in directory listing")
            return
        }
        
        // Move cursor to symlink
        appState.currentPane.activeTab.cursorFileId = files[symlinkIndex].id
        
        // Execute enterDirectory
        await appState.enterDirectory()
        
        // Should have navigated to the resolved folder
        let currentPath = appState.currentPane.activeTab.currentPath
        #expect(currentPath.lastPathComponent == "real_folder")
    }
    
    @Test func testAppStateDoubleClickSymlinkFolder() async throws {
        let (tempDir, folderLink, _, cleanup) = try createTestEnvironment()
        defer { cleanup() }
        
        // Create AppState and navigate to temp directory
        let appState = AppState()
        let service = FileSystemService.shared
        
        // Load the temp directory
        let files = await service.loadDirectory(at: tempDir)
        appState.leftPane.activeTab.currentPath = tempDir
        appState.leftPane.activeTab.files = files
        
        // Find the folder symlink in the file list
        guard let symlinkFile = files.first(where: { $0.name == "link_to_folder" }) else {
            Issue.record("Folder symlink not found in directory listing")
            return
        }
        
        // Execute double click on left pane
        await appState.handleMouseDoubleClick(fileId: symlinkFile.id, paneSide: .left)
        
        // Should have navigated to the resolved folder
        let currentPath = appState.leftPane.activeTab.currentPath
        #expect(currentPath.lastPathComponent == "real_folder")
    }
}
