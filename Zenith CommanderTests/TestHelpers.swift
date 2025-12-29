//
//  TestHelpers.swift
//  Zenith CommanderTests
//
//  测试辅助工具
//

import Foundation
import XCTest

/// 测试辅助工具类
class TestHelpers {
    /// 创建临时测试目录
    /// - Returns: 临时目录 URL
    static func createTestDirectory() -> URL {
        let temp = FileManager.default.temporaryDirectory
        let testDir = temp.appendingPathComponent("ZenithCommanderTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }
    
    /// 清理测试目录
    /// - Parameter url: 要清理的目录 URL
    static func cleanupTestDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// 创建测试用 UserDefaults
    /// - Returns: 独立的 UserDefaults 实例用于测试
    static func createTestUserDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults
    }
    
    /// 清理测试用 UserDefaults
    /// - Parameter userDefaults: 要清理的 UserDefaults 实例
    static func cleanupTestUserDefaults(_ userDefaults: UserDefaults) {
        if let suiteName = userDefaults.dictionaryRepresentation().first?.key {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
    }
}
