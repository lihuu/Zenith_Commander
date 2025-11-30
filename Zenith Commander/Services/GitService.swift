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
    
    // MARK: - Git History
    
    /// 获取文件的 Git 历史记录
    /// - Parameters:
    ///   - file: 文件 URL
    ///   - limit: 最大返回数量，默认 50
    /// - Returns: Git 提交列表
    func getFileHistory(for file: URL, limit: Int = 50) -> [GitCommit] {
        guard isGitAvailable else { return [] }
        
        // 获取仓库根目录
        guard let rootPath = getRepositoryRoot(for: file) else {
            return []
        }
        
        // 计算相对路径
        let relativePath = file.path.replacingOccurrences(of: rootPath.path + "/", with: "")
        
        // 运行 git log 命令
        // 格式: hash|short_hash|author|email|timestamp|subject|body|parent_hashes
        let format = "%H|%h|%an|%ae|%at|%s|%b|%P"
        let args = [
            "log",
            "--format=\(format)",
            "-n", "\(limit)",
            "--follow",  // 跟踪文件重命名
            "--",
            relativePath
        ]
        
        guard let output = runGitCommand(args, at: rootPath) else {
            return []
        }
        
        return parseGitLogOutput(output)
    }
    
    /// 获取整个仓库的 Git 历史记录
    /// - Parameters:
    ///   - directory: 仓库目录
    ///   - limit: 最大返回数量，默认 50
    /// - Returns: Git 提交列表
    func getRepositoryHistory(at directory: URL, limit: Int = 50) -> [GitCommit] {
        guard isGitAvailable else { return [] }
        
        guard let rootPath = getRepositoryRoot(for: directory) else {
            return []
        }
        
        let format = "%H|%h|%an|%ae|%at|%s|%b|%P"
        let args = [
            "log",
            "--format=\(format)",
            "-n", "\(limit)"
        ]
        
        guard let output = runGitCommand(args, at: rootPath) else {
            return []
        }
        
        return parseGitLogOutput(output)
    }
    
    /// 获取指定 commit 的变更文件列表
    /// - Parameters:
    ///   - commitHash: commit hash
    ///   - directory: 仓库目录
    /// - Returns: 变更文件列表
    func getCommitChanges(for commitHash: String, at directory: URL) -> [GitFileChange] {
        guard isGitAvailable else { return [] }
        
        guard let rootPath = getRepositoryRoot(for: directory) else {
            return []
        }
        
        // 使用 --numstat 获取变更统计
        let args = [
            "diff-tree",
            "--no-commit-id",
            "--name-status",
            "-r",
            commitHash
        ]
        
        guard let output = runGitCommand(args, at: rootPath) else {
            return []
        }
        
        return parseCommitChanges(output)
    }
    
    /// 解析 git log 输出
    private func parseGitLogOutput(_ output: String) -> [GitCommit] {
        var commits: [GitCommit] = []
        
        // 按空行分割（每个 commit 之间有空行）
        let entries = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for entry in entries {
            let parts = entry.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }
            
            let hash = parts[0]
            let shortHash = parts[1]
            let author = parts[2]
            let email = parts[3]
            let timestamp = TimeInterval(parts[4]) ?? 0
            let subject = parts[5]
            let body = parts.count > 6 ? parts[6] : ""
            let parentHashesStr = parts.count > 7 ? parts[7] : ""
            let parentHashes = parentHashesStr.split(separator: " ").map(String.init)
            
            let commit = GitCommit(
                id: hash,
                shortHash: shortHash,
                message: subject,
                fullMessage: body.isEmpty ? subject : "\(subject)\n\n\(body)",
                author: author,
                authorEmail: email,
                date: Date(timeIntervalSince1970: timestamp),
                parentHashes: parentHashes
            )
            
            commits.append(commit)
        }
        
        return commits
    }
    
    /// 解析 commit 变更文件
    private func parseCommitChanges(_ output: String) -> [GitFileChange] {
        var changes: [GitFileChange] = []
        
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        
        for line in lines {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count >= 2 else { continue }
            
            let statusChar = String(parts[0])
            var filePath = String(parts[1])
            
            // 处理引号包裹的路径
            if filePath.hasPrefix("\"") && filePath.hasSuffix("\"") {
                filePath = String(filePath.dropFirst().dropLast())
                filePath = unescapeGitPath(filePath)
            }
            
            let status: GitFileStatus
            switch statusChar {
            case "M": status = .modified
            case "A": status = .added
            case "D": status = .deleted
            case "R": status = .renamed
            case "C": status = .copied
            default: status = .modified
            }
            
            let change = GitFileChange(
                id: filePath,
                path: filePath,
                status: status,
                additions: 0,  // 简化版本不获取行数
                deletions: 0
            )
            
            changes.append(change)
        }
        
        return changes
    }
    
    /// 获取目录下所有文件的 Git 状态
    /// - Parameters:
    ///   - directory: 目录路径
    ///   - includeUntracked: 是否包含未跟踪文件
    ///   - includeIgnored: 是否包含被忽略文件
    /// - Returns: 文件 URL 到状态的映射
    func getFileStatuses(in directory: URL, includeUntracked: Bool = true, includeIgnored: Bool = false) -> [URL: GitFileStatus] {
        guard isGitAvailable else { 
            return [:] 
        }
        
        // 检查是否是 Git 仓库
        guard let rootPath = getRepositoryRoot(for: directory) else {
            return [:]
        }
        
        // 运行 git status - 从仓库根目录获取所有状态
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
        
        // 从仓库根目录运行命令以获取完整路径
        guard let statusOutput = runGitCommand(args, at: rootPath) else {
            return [:]
        }
        
        // 解析状态
        var statuses: [URL: GitFileStatus] = [:]
        let lines = statusOutput.split(separator: "\n", omittingEmptySubsequences: true)
        
        for line in lines {
            guard line.count >= 3 else { continue }
            
            let statusChars = String(line.prefix(2))
            var filePath = String(line.dropFirst(3))
            
            // 移除引号（当路径包含空格时 Git 会添加引号）
            if filePath.hasPrefix("\"") && filePath.hasSuffix("\"") {
                filePath = String(filePath.dropFirst().dropLast())
            }
            
            // 处理 Git 的转义序列（如 \303\247 表示 UTF-8 字符）
            filePath = unescapeGitPath(filePath)
            
            // 获取文件名（处理重命名情况：old -> new）
            let fileName: String
            if filePath.contains(" -> ") {
                var newPath = String(filePath.split(separator: " -> ").last ?? Substring(filePath))
                // 重命名的新路径也可能有引号
                if newPath.hasPrefix("\"") && newPath.hasSuffix("\"") {
                    newPath = String(newPath.dropFirst().dropLast())
                }
                fileName = newPath
            } else {
                fileName = filePath
            }
            
            // 构建完整文件路径
            let fileURL = rootPath.appendingPathComponent(fileName)
            let fileDir = fileURL.deletingLastPathComponent()
            
            // 标准化路径以便比较
            let normalizedFileDir = fileDir.standardizedFileURL.path
            let normalizedDirectory = directory.standardizedFileURL.path
            
            // 检查是否在当前目录或子目录
            if normalizedFileDir == normalizedDirectory {
                // 文件直接在当前目录下
                let status = parseGitStatus(statusChars)
                statuses[fileURL.standardizedFileURL] = status
            } else if normalizedFileDir.hasPrefix(normalizedDirectory + "/") {
                // 文件在子目录中，标记父目录
                let status = parseGitStatus(statusChars)
                
                // 获取直接子目录
                let subPath = normalizedFileDir.replacingOccurrences(of: normalizedDirectory + "/", with: "")
                let directSubDir = subPath.split(separator: "/").first.map(String.init) ?? ""
                if !directSubDir.isEmpty {
                    let subDirURL = directory.appendingPathComponent(directSubDir).standardizedFileURL
                    // 子目录有修改的文件，标记为 modified
                    if statuses[subDirURL] == nil {
                        statuses[subDirURL] = .modified
                    }
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
    
    /// 解码 Git 的转义路径
    /// Git 对包含非 ASCII 字符的路径使用八进制转义序列
    private func unescapeGitPath(_ path: String) -> String {
        var result = ""
        var index = path.startIndex
        
        while index < path.endIndex {
            let char = path[index]
            
            if char == "\\" {
                let nextIndex = path.index(after: index)
                if nextIndex < path.endIndex {
                    let nextChar = path[nextIndex]
                    
                    // 检查是否是八进制序列 (如 \303\247)
                    if nextChar.isNumber {
                        // 尝试读取3位八进制数
                        var octalStr = ""
                        var octalIndex = nextIndex
                        while octalIndex < path.endIndex && octalStr.count < 3 {
                            let c = path[octalIndex]
                            if c >= "0" && c <= "7" {
                                octalStr.append(c)
                                octalIndex = path.index(after: octalIndex)
                            } else {
                                break
                            }
                        }
                        
                        if octalStr.count == 3, let octalValue = UInt8(octalStr, radix: 8) {
                            result.append(Character(UnicodeScalar(octalValue)))
                            index = octalIndex
                            continue
                        }
                    }
                    
                    // 处理其他转义字符
                    switch nextChar {
                    case "n": result.append("\n")
                    case "t": result.append("\t")
                    case "\\": result.append("\\")
                    case "\"": result.append("\"")
                    default: result.append(char); result.append(nextChar)
                    }
                    index = path.index(after: nextIndex)
                    continue
                }
            }
            
            result.append(char)
            index = path.index(after: index)
        }
        
        return result
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
