//
//  ExternalToolchain.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/28/25.
//

import Foundation

/// Resolve external tools and pick the best available one.
struct ExternalToolchain: Sendable {
    static let shared = ExternalToolchain()

    let rgPath: String?
    let fdPath: String?
    let findPath: String
    let fzfPath: String?
    let gitPath: String?
    let rsyncPath: String?

    static let candidatePaths = [
        "/opt/homebrew/bin/",
        "/usr/local/bin/",
        "/usr/bin/",
    ]

    init() {
        rgPath = Self.resolveTool("rg")
        fdPath = Self.resolveTool("fd")
        fzfPath = Self.resolveTool("fzf")
        findPath = Self.resolveTool("fd") ?? "/usr/bin/find"
        gitPath = Self.resolveTool("git")
        rsyncPath = Self.resolveTool("rsync")
    }

    var preferredListTool: FileListTool {
        if rgPath != nil { return .rg }
        if fdPath != nil { return .fd }
        return .find
    }

    func isToolAvailable(_ tool: FileListTool) -> Bool {
        return switch tool {
        case .rg:
            rgPath != nil
        case .fd:
            fdPath != nil
        case .git:
            gitPath != nil
        case .rsync:
            rsyncPath != nil
        case .find:
            true
        case .fzf:
            fzfPath != nil
        }
    }

    /// Resolve tool path using predefined paths first, fallback to which.
    private static func resolveTool(_ name: String) -> String? {
        // 1) Try predefined paths
        let candidates = ToolPathUtils.generateCandidatePaths(
            executableName: name,
            additionalPaths: ToolPathUtils.candidatePaths.map { "\($0)\(name)" }
        )
        if let found = ToolPathUtils.resolveFirstExecutablePath(
            candidatePaths: candidates
        ) {
            return found
        }

        // 2) Fallback to which command
        return whichFallback(name)
    }

    /// Fallback: use which command to locate tool.
    private static func whichFallback(_ name: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["which", name]

        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()

        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return path.isEmpty ? nil : path
    }

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

    static func isToolAvailable(command: String) -> Bool {
        let candidatePaths = generateCandidatePaths(
            executableName: command,
            additionalPaths: candidatePaths.map { path in "\(path)/\(command)" }
        )
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
    static func resolveFirstExecutablePath(candidatePaths: [String]) -> String?
    {
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
