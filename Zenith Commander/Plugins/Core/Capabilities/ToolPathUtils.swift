//
//  ToolPathUtils.swift
//  Zenith Commander
//
//  工具路径解析工具类
//

import Foundation
import os.log

/// 工具路径解析工具
struct ToolPathUtils {
    static let candidatePaths = [
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.volta/bin/",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/",
        "/opt/homebrew/bin/",
        "/usr/local/bin/",
        "/usr/bin/",
    ]

    /// 从候选路径列表中查找可执行文件
    /// - Parameter candidatePaths: 候选路径列表
    /// - Returns: 找到的所有可执行文件路径
    static func resolveExecutablePaths(candidatePaths: [String]) -> [String] {
        let fileManager = FileManager.default
        var foundPaths: [String] = []

        for path in candidatePaths {
            if fileManager.isExecutableFile(atPath: path) {
                foundPaths.append(path)
            }
        }

        return foundPaths
    }

    static func commandAvailable(command: String) -> Bool {
        let candidatePaths = generateCandidatePaths(
            executableName: command,
            additionalPaths: self.candidatePaths.map { path in "\(path)/\(command)" })
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return true
            }
        }
        return false
    }

    /// 从候选路径列表中查找第一个可执行文件
    /// - Parameter candidatePaths: 候选路径列表
    /// - Returns: 找到的第一个可执行文件路径，如果没有找到返回 nil
    static func resolveFirstExecutablePath(candidatePaths: [String]) -> String? {
        let paths = resolveExecutablePaths(candidatePaths: candidatePaths)
        return paths.first
    }

    /// 生成包含 PATH 环境变量的候选路径列表
    /// - Parameters:
    ///   - executableName: 可执行文件名称（如 "git", "rsync"）
    ///   - additionalPaths: 额外的候选路径
    /// - Returns: 完整的候选路径列表
    static func generateCandidatePaths(
        executableName: String,
        additionalPaths: [String] = []
    ) -> [String] {
        var candidates = additionalPaths

        // 从 PATH 环境变量获取路径
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let pathCandidates = pathEnv.split(separator: ":").map { path in
                "\(path)/\(executableName)"
            }
            candidates.append(contentsOf: pathCandidates)
        }

        return candidates
    }

}
