//
//  GitService.swift
//  Zenith Commander
//
//  Git 服务 - 提供 Git 状态查询功能
//

import Foundation
import os.log

/// Git 服务 - 单例
class GitService {
    static let shared = GitService()
    
    /// 缓存
    private var cache: [URL: GitStatusCacheEntry] = [:]
    
    /// 缓存锁
    private let cacheLock = NSLock()
    
    /// 缓存过期时间（秒）
    private let cacheTTL: TimeInterval = 5.0
    
    /// Git 命令超时时间（秒）
    private let commandTimeout: TimeInterval = 2.0
    
    /// Git 是否可用（延迟检测）
    private lazy var isGitAvailable: Bool = {
        checkGitAvailable()
    }()
    
    private init() {}
    
    // MARK: - Public API
    
    /// 检查 Git 是否已安装
    /// - Returns: Git 是否可用
    func isGitInstalled() -> Bool {
        return isGitAvailable
    }
    
    /// 检查目录是否在 Git 仓库中
    /// - Parameter path: 要检查的目录
    /// - Returns: 是否是 Git 仓库
    func isGitRepository(at path: URL) -> Bool {
        guard isGitAvailable else { return false }
        
        // 检查是否存在 .git 目录或文件
        let gitPath = path.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitPath.path) {
            return true
        }
        
        // 使用 git rev-parse 检查是否在仓库中
        let result = runGitCommand(["rev-parse", "--is-inside-work-tree"], at: path)
        return result?.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
    
    /// 获取 Git 仓库根目录
    /// - Parameter path: 当前目录
    /// - Returns: 仓库根目录，如果不在仓库中则返回 nil
    func getRepositoryRoot(for path: URL) -> URL? {
        guard isGitAvailable else { return nil }
        
        guard let result = runGitCommand(["rev-parse", "--show-toplevel"], at: path) else {
            return nil
        }
        
        let rootPath = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty else { return nil }
        
        return URL(fileURLWithPath: rootPath)
    }
    
    /// 获取仓库信息（分支、ahead/behind 等）
    /// - Parameter path: 目录路径
    /// - Returns: 仓库信息
    func getRepositoryInfo(at path: URL) -> GitRepositoryInfo {
        guard isGitAvailable else { return .notARepository }
        
        // 检查缓存
        if let cached = getCachedEntry(for: path), !cached.isExpired(ttl: cacheTTL) {
            return cached.repositoryInfo
        }
        
        // 检查是否是 Git 仓库
        guard let rootPath = getRepositoryRoot(for: path) else {
            return .notARepository
        }
        
        // 获取当前分支
        var currentBranch: String?
        var isDetachedHead = false
        
        if let branchResult = runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], at: path) {
            let branch = branchResult.trimmingCharacters(in: .whitespacesAndNewlines)
            if branch == "HEAD" {
                isDetachedHead = true
                // 尝试获取短 commit hash
                if let hashResult = runGitCommand(["rev-parse", "--short", "HEAD"], at: path) {
                    currentBranch = hashResult.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                currentBranch = branch
            }
        }
        
        // 获取 ahead/behind
        var ahead = 0
        var behind = 0
        
        if let trackingResult = runGitCommand(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], at: path) {
            let parts = trackingResult.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if parts.count >= 2 {
                behind = Int(parts[0]) ?? 0
                ahead = Int(parts[1]) ?? 0
            }
        }
        
        // 检查是否有未提交的更改
        let hasUncommittedChanges: Bool
        if let statusResult = runGitCommand(["status", "--porcelain"], at: path) {
            hasUncommittedChanges = !statusResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            hasUncommittedChanges = false
        }
        
        return GitRepositoryInfo(
            isGitRepository: true,
            rootPath: rootPath,
            currentBranch: currentBranch,
            isDetachedHead: isDetachedHead,
            ahead: ahead,
            behind: behind,
            hasUncommittedChanges: hasUncommittedChanges
        )
    }
    
    /// 获取目录下所有文件的 Git 状态
    /// - Parameters:
    ///   - directory: 目录路径
    ///   - includeUntracked: 是否包含未跟踪文件
    ///   - includeIgnored: 是否包含被忽略文件
    /// - Returns: 文件 URL 到状态的映射
    func getFileStatuses(in directory: URL, includeUntracked: Bool = true, includeIgnored: Bool = false) -> [URL: GitFileStatus] {
        guard isGitAvailable else { return [:] }
        
        // 检查是否是 Git 仓库
        guard let rootPath = getRepositoryRoot(for: directory) else {
            return [:]
        }
        
        // 获取相对路径
        let relativePath = directory.path.replacingOccurrences(of: rootPath.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // 运行 git status
        var args = ["status", "--porcelain"]
        
        // 处理未跟踪文件选项
        if includeUntracked {
            args.append("-uall")
        } else {
            args.append("-uno")
        }
        
        // 处理被忽略文件选项
        if includeIgnored {
            args.append("--ignored")
        }
        
        if !relativePath.isEmpty {
            args.append(contentsOf: ["--", relativePath])
        }
        
        guard let statusOutput = runGitCommand(args, at: directory) else {
            return [:]
        }
        
        // 解析状态
        var statuses: [URL: GitFileStatus] = [:]
        let lines = statusOutput.split(separator: "\n", omittingEmptySubsequences: true)
        
        for line in lines {
            guard line.count >= 3 else { continue }
            
            let statusChars = String(line.prefix(2))
            let filePath = String(line.dropFirst(3))
            
            // 获取文件名（处理重命名情况：old -> new）
            let fileName: String
            if filePath.contains(" -> ") {
                fileName = String(filePath.split(separator: " -> ").last ?? Substring(filePath))
            } else {
                fileName = filePath
            }
            
            // 只处理当前目录下的文件
            let fileURL = rootPath.appendingPathComponent(fileName)
            let fileDir = fileURL.deletingLastPathComponent()
            
            // 检查是否在当前目录或子目录
            if fileDir.path == directory.path || fileDir.path.hasPrefix(directory.path + "/") {
                let status = parseGitStatus(statusChars)
                
                // 如果文件在子目录，标记目录
                if fileDir.path != directory.path {
                    // 获取直接子目录名
                    let subPath = fileDir.path.replacingOccurrences(of: directory.path + "/", with: "")
                    let directSubDir = subPath.split(separator: "/").first.map(String.init) ?? ""
                    if !directSubDir.isEmpty {
                        let subDirURL = directory.appendingPathComponent(directSubDir)
                        // 如果目录已有状态且不是 modified，保持原状态
                        if statuses[subDirURL] == nil || statuses[subDirURL] == .clean {
                            statuses[subDirURL] = .modified
                        }
                    }
                } else {
                    statuses[fileURL] = status
                }
            }
        }
        
        return statuses
    }
    
    /// 清除缓存
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }
    
    /// 清除特定目录的缓存
    func clearCache(for directory: URL) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: directory)
    }
    
    // MARK: - Private Methods
    
    /// 检查 Git 是否可用
    private func checkGitAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "--version"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// 运行 Git 命令（带超时）
    private func runGitCommand(_ arguments: [String], at directory: URL) -> String? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = directory
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        // 设置超时
        let timeoutWorkItem = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        
        do {
            try process.run()
            
            // 设置超时定时器
            DispatchQueue.global().asyncAfter(deadline: .now() + commandTimeout, execute: timeoutWorkItem)
            
            process.waitUntilExit()
            timeoutWorkItem.cancel()
            
            guard process.terminationStatus == 0 else {
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            Logger.fileSystem.error("Git command failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 解析 Git 状态字符
    private func parseGitStatus(_ statusChars: String) -> GitFileStatus {
        guard statusChars.count >= 2 else { return .clean }
        
        let index = statusChars.first ?? " "
        let workTree = statusChars.dropFirst().first ?? " "
        
        // 优先检查工作区状态
        switch workTree {
        case "M": return .modified
        case "D": return .deleted
        case "?": return .untracked
        case "!": return .ignored
        case "U": return .conflict
        default: break
        }
        
        // 检查索引状态
        switch index {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "U": return .conflict
        default: break
        }
        
        return .clean
    }
    
    /// 获取缓存条目
    private func getCachedEntry(for directory: URL) -> GitStatusCacheEntry? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[directory]
    }
    
    /// 设置缓存条目
    private func setCacheEntry(for directory: URL, fileStatuses: [String: GitFileStatus], repositoryInfo: GitRepositoryInfo) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache[directory] = GitStatusCacheEntry(
            fileStatuses: fileStatuses,
            repositoryInfo: repositoryInfo,
            timestamp: Date()
        )
    }
}
