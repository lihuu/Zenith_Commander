//
//  LocalFileSystemProviderTests.swift
//  Zenith CommanderTests
//
//  Created by Gemini CLI on 2025/12/08.
//

import Testing
import Foundation
@testable import Zenith_Commander

@MainActor
struct LocalFileSystemProviderTests {
    
    // MARK: - 自动重命名测试
    
    @Test func testGenerateUniqueFileName_NoConflict() {
        let provider = LocalFileSystemProvider()
        // 使用一个不存在的文件名
        let uniqueName = "UniqueTestFile_\(UUID().uuidString).txt"
        let tempDir = FileManager.default.temporaryDirectory
        
        // Accessing private method via @testable
        let result = provider.generateUniqueFileName(for: uniqueName, in: tempDir)
        
        // 没有冲突时，应该返回原名
        #expect(result == uniqueName)
    }
    
    @Test func testGenerateUniqueFileName_WithConflict_AddsCopySuffix() throws {
        let provider = LocalFileSystemProvider()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建一个已存在的文件
        let existingFile = tempDir.appendingPathComponent("test.txt")
        fileManager.createFile(atPath: existingFile.path, contents: nil)
        
        // Accessing private method via @testable
        let result = provider.generateUniqueFileName(for: "test.txt", in: tempDir)
        
        // 应该添加 Copy 后缀
        #expect(result == "test Copy1.txt")
    }
    
    @Test func testGenerateUniqueFileName_WithMultipleConflicts() throws {
        let provider = LocalFileSystemProvider()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建多个冲突的文件
        let existingFile1 = tempDir.appendingPathComponent("test.txt")
        let existingFile2 = tempDir.appendingPathComponent("test Copy.txt")
        let existingFile3 = tempDir.appendingPathComponent("test Copy1.txt")
        
        fileManager.createFile(atPath: existingFile1.path, contents: nil)
        fileManager.createFile(atPath: existingFile2.path, contents: nil)
        fileManager.createFile(atPath: existingFile3.path, contents: nil)
        
        // Accessing private method via @testable
        let result = provider.generateUniqueFileName(for: "test.txt", in: tempDir)
        
        // 应该返回 Copy2
        #expect(result == "test Copy2.txt")
    }
    
    @Test func testGenerateUniqueFileName_NoExtension() throws {
        let provider = LocalFileSystemProvider()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建无扩展名的文件
        let existingFile = tempDir.appendingPathComponent("README")
        fileManager.createFile(atPath: existingFile.path, contents: nil)
        
        // Accessing private method via @testable
        let result = provider.generateUniqueFileName(for: "README", in: tempDir)
        
        // 无扩展名的文件应该在末尾添加 Copy
        #expect(result == "README Copy1")
    }
    
    @Test func testGenerateUniqueFileName_HiddenFile() throws {
        let provider = LocalFileSystemProvider()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建隐藏文件
        let existingFile = tempDir.appendingPathComponent(".gitignore")
        fileManager.createFile(atPath: existingFile.path, contents: nil)
        
        // Accessing private method via @testable
        let result = provider.generateUniqueFileName(for: ".gitignore", in: tempDir)
        
        // 隐藏文件应该在末尾添加 Copy
        #expect(result == ".gitignore Copy1")
    }
    
    @Test func testGenerateUniqueFileName_FolderConflict() throws {
        let provider = LocalFileSystemProvider()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ZenithTest_\(UUID().uuidString)")
        
        // 创建测试目录
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // 创建已存在的文件夹
        let existingFolder = tempDir.appendingPathComponent("MyFolder")
        try fileManager.createDirectory(at: existingFolder, withIntermediateDirectories: false)
        
        // Accessing private method via @testable
        let result = provider.generateUniqueFileName(for: "MyFolder", in: tempDir)
        
        // 文件夹也应该添加 Copy 后缀
        #expect(result == "MyFolder Copy1")
    }
}