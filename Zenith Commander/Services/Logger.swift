//
//  Logger.swift
//  Zenith Commander
//
//  统一日志服务，基于 Apple 的 os.Logger API
//  优点：
//  - 系统级优化，性能极佳
//  - 支持日志级别 (debug, info, warning, error, fault)
//  - Release 版本中 debug 日志自动禁用
//  - 可在 Console.app 中查看和过滤
//  - 支持隐私保护（敏感数据不会被记录）
//

import Foundation
import os.log

// MARK: - Logger 扩展

/// 应用程序日志记录器
/// 使用方式：Logger.app.debug("调试信息")
///          Logger.fileSystem.error("文件操作失败: \(error)")
extension Logger {
    
    /// 子系统标识符（使用 Bundle ID）
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.zenithcommander"
    
    // MARK: - 日志类别
    
    /// 通用应用日志
    static let app = Logger(subsystem: subsystem, category: "app")
    
    /// 文件系统操作日志
    static let fileSystem = Logger(subsystem: subsystem, category: "filesystem")
    
    /// 目录监控日志
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    
    /// 设置/配置日志
    static let settings = Logger(subsystem: subsystem, category: "settings")
    
    /// UI 相关日志
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// 导航日志
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
}

// MARK: - 便捷日志函数（可选）

/// 快速日志记录（仅在 DEBUG 模式下有效）
/// 使用方式：log("调试信息")
func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    Logger.app.debug("[\(fileName):\(line)] \(function) - \(message)")
    #endif
}

/// 快速错误日志
/// 使用方式：logError("操作失败", error: someError)
func logError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    if let error = error {
        Logger.app.error("[\(fileName):\(line)] \(function) - \(message): \(error.localizedDescription)")
    } else {
        Logger.app.error("[\(fileName):\(line)] \(function) - \(message)")
    }
}

// MARK: - 日志级别说明
/*
 os.Logger 提供以下日志级别（从低到高）：
 
 1. debug   - 调试信息，Release 版本中不会记录
 2. info    - 一般信息
 3. notice  - 重要信息（默认级别）
 4. warning - 警告（非致命错误）(通过 .warning 类型)
 5. error   - 错误
 6. fault   - 严重错误（可能导致崩溃）
 
 使用示例：
 Logger.fileSystem.debug("开始加载目录: \(path)")
 Logger.fileSystem.info("已加载 \(count) 个文件")
 Logger.fileSystem.warning("目录访问权限受限: \(path)")
 Logger.fileSystem.error("加载目录失败: \(error)")
 Logger.fileSystem.fault("致命错误: 文件系统损坏")
 
 隐私保护：
 - 默认情况下，动态字符串在 Release 版本中会被隐藏
 - 使用 \(path, privacy: .public) 显式公开
 - 使用 \(sensitiveData, privacy: .private) 显式私有
 
 在 Console.app 中查看：
 1. 打开 Console.app
 2. 选择设备/模拟器
 3. 在搜索框中输入 subsystem:com.zenithcommander
 4. 可按 category 过滤（如 filesystem、monitor 等）
 */
