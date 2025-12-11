//
//  FileSystemServiceTests.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/8/25.
//


import Testing
import Foundation
@testable import Zenith_Commander

struct FileSystemServiceTests {
    
    @Test func testSingletonInstance() {
        let service1 = FileSystemService.shared
        let service2 = FileSystemService.shared
        
        #expect(service1 === service2)
    }
    
    @Test func testLoadDirectory() async {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        let files = await service.loadDirectory(at: homeDir)
        
        // 主目录应该有文件
        #expect(!files.isEmpty)
    }
    
    @Test func testParentDirectory() {
        let service = FileSystemService.shared
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        
        let parent = service.parentDirectory(of: path)
        
        #expect(parent.lastPathComponent == "test")
    }
    
    @Test func testRootParentDirectory() {
        let service = FileSystemService.shared
        let rootPath = URL(fileURLWithPath: "/")
        
        let parent = service.parentDirectory(of: rootPath)
        
        #expect(parent.path == "/")
    }
    
    @Test func testGetMountedVolumes() {
        let service = FileSystemService.shared
        
        let volumes = service.getMountedVolumes()
        
        // 至少应该有一个卷（系统盘）
        #expect(!volumes.isEmpty)
    }
    
    @Test func testDirectoryExistsCheck() {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        #expect(service.directoryExists(at: homeDir) == true)
    }
    
    @Test func testDirectoryNotExistsCheck() {
        let service = FileSystemService.shared
        let fakePath = URL(fileURLWithPath: "/nonexistent/path/12345")
        
        #expect(service.directoryExists(at: fakePath) == false)
    }
    
    @Test func testHasReadPermission() {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        #expect(service.hasReadPermission(for: homeDir) == true)
    }
    
    @Test func testLoadDirectoryWithPermissionCheck() async {
        let service = FileSystemService.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        let result = await service.loadDirectoryWithPermissionCheck(at: homeDir)
        
        switch result {
        case .success(let files):
            #expect(!files.isEmpty)
        case .permissionDenied:
            // 如果权限被拒绝，也是有效的结果
            #expect(true)
        case .notFound:
            #expect(false, "Home directory should exist")
        case .error:
            #expect(false, "Should not error on home directory")
        }
    }
    

    
    // MARK: - New File 测试
    
    @Test func testCreateFile_Basic() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建新文件
        let createdURL = try await service.createFile(at: tempDir, name: "test.txt")
        
        // 验证文件被创建
        #expect(fileManager.fileExists(atPath: createdURL.path))
        #expect(createdURL.lastPathComponent == "test.txt")
    }
    
    @Test func testCreateFile_WithConflict_AutoRename() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建已存在的文件
        let existingFile = tempDir.appendingPathComponent("test.txt")
        fileManager.createFile(atPath: existingFile.path, contents: nil)
        
        // 创建同名文件应该自动重命名
        let createdURL = try await service.createFile(at: tempDir, name: "test.txt")
        
        // 验证文件被创建且名称被修改
        #expect(fileManager.fileExists(atPath: createdURL.path))
        #expect(createdURL.lastPathComponent == "test Copy1.txt")
    }
    
    @Test func testCreateFile_MultipleConflicts() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建多个冲突的文件
        fileManager.createFile(atPath: tempDir.appendingPathComponent("untitled.txt").path, contents: nil)
        fileManager.createFile(atPath: tempDir.appendingPathComponent("untitled Copy.txt").path, contents: nil)
        
        // 创建同名文件应该自动重命名为 Copy1
        let createdURL = try await service.createFile(at: tempDir, name: "untitled.txt")
        
        // 验证文件被创建且名称被正确修改
        #expect(fileManager.fileExists(atPath: createdURL.path))
        #expect(createdURL.lastPathComponent == "untitled Copy1.txt")
    }
    
    @Test func testCreateFile_EmptyFile() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建新文件
        let createdURL = try await service.createFile(at: tempDir, name: "empty.txt")
        
        // 验证文件是空的
        let data = try Data(contentsOf: createdURL)
        #expect(data.isEmpty)
    }
    
    // MARK: - New Folder 测试
    
    @Test func testCreateDirectory_Basic() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建新文件夹
        let createdURL = try await service.createDirectory(at: tempDir, name: "NewFolder")
        
        // 验证文件夹被创建
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: createdURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(createdURL.lastPathComponent == "NewFolder")
    }
    
    @Test func testCreateDirectory_WithConflict_AutoRename() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建已存在的文件夹
        let existingFolder = tempDir.appendingPathComponent("untitled folder")
        try fileManager.createDirectory(at: existingFolder, withIntermediateDirectories: false)
        
        // 创建同名文件夹应该自动重命名
        let createdURL = try await service.createDirectory(at: tempDir, name: "untitled folder")
        
        // 验证文件夹被创建且名称被修改
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: createdURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(createdURL.lastPathComponent == "untitled folder Copy1")
    }
    
    @Test func testCreateDirectory_MultipleConflicts() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建多个冲突的文件夹
        try fileManager.createDirectory(at: tempDir.appendingPathComponent("untitled folder"), withIntermediateDirectories: false)
        try fileManager.createDirectory(at: tempDir.appendingPathComponent("untitled folder Copy"), withIntermediateDirectories: false)
        try fileManager.createDirectory(at: tempDir.appendingPathComponent("untitled folder Copy1"), withIntermediateDirectories: false)
        
        // 创建同名文件夹应该自动重命名为 Copy2
        let createdURL = try await service.createDirectory(at: tempDir, name: "untitled folder")
        
        // 验证文件夹被创建且名称被正确修改
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: createdURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(createdURL.lastPathComponent == "untitled folder Copy2")
    }
    
    @Test func testCreateDirectory_ConflictWithFile() async throws {
        let service = FileSystemService.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建一个同名的文件（不是文件夹）
        let existingFile = tempDir.appendingPathComponent("MyFolder")
        fileManager.createFile(atPath: existingFile.path, contents: nil)
        
        // 创建同名文件夹应该自动重命名
        let createdURL = try await service.createDirectory(at: tempDir, name: "MyFolder")
        
        // 验证文件夹被创建且名称被修改
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: createdURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(createdURL.lastPathComponent == "MyFolder Copy1")
    }
}