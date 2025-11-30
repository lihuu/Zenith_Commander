//
//  GitStatus.swift
//  Zenith Commander
//
//  Git 状态模型
//

import SwiftUI

// MARK: - Git 文件状态

/// Git 文件状态枚举
enum GitFileStatus: String, Equatable {
    case modified = "M"           // 已修改
    case added = "A"              // 新增（已暂存）
    case deleted = "D"            // 已删除
    case renamed = "R"            // 重命名
    case copied = "C"             // 复制
    case untracked = "?"          // 未跟踪
    case ignored = "!"            // 已忽略
    case conflict = "U"           // 冲突
    case clean = ""               // 干净（已提交）
    
    /// 状态显示文本
    var displayText: String {
        switch self {
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .untracked: return "?"
        case .ignored: return "!"
        case .conflict: return "U"
        case .clean: return ""
        }
    }
    
    /// 状态颜色
    var color: Color {
        switch self {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .cyan
        case .untracked: return .gray
        case .ignored: return .gray.opacity(0.5)
        case .conflict: return .red
        case .clean: return .clear
        }
    }
    
    /// 是否应该显示
    var shouldDisplay: Bool {
        self != .clean && self != .ignored
    }
    
    /// 状态描述
    var description: String {
        switch self {
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        case .conflict: return "Conflict"
        case .clean: return "Clean"
        }
    }
}

// MARK: - Git 仓库信息

/// Git 仓库信息
struct GitRepositoryInfo: Equatable {
    /// 是否是 Git 仓库
    let isGitRepository: Bool
    
    /// 仓库根目录
    let rootPath: URL?
    
    /// 当前分支名
    let currentBranch: String?
    
    /// 是否处于分离 HEAD 状态
    let isDetachedHead: Bool
    
    /// 领先远程的提交数
    let ahead: Int
    
    /// 落后远程的提交数
    let behind: Int
    
    /// 是否有未提交的更改
    let hasUncommittedChanges: Bool
    
    /// 非 Git 仓库的默认值
    static var notARepository: GitRepositoryInfo {
        GitRepositoryInfo(
            isGitRepository: false,
            rootPath: nil,
            currentBranch: nil,
            isDetachedHead: false,
            ahead: 0,
            behind: 0,
            hasUncommittedChanges: false
        )
    }
    
    /// 分支显示文本
    var branchDisplayText: String? {
        guard isGitRepository else { return nil }
        
        if isDetachedHead {
            return "HEAD"
        }
        return currentBranch
    }
    
    /// ahead/behind 显示文本
    var syncStatusText: String? {
        guard isGitRepository else { return nil }
        
        var parts: [String] = []
        if ahead > 0 {
            parts.append("↑\(ahead)")
        }
        if behind > 0 {
            parts.append("↓\(behind)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - Git 状态缓存

/// Git 状态缓存条目
struct GitStatusCacheEntry {
    let fileStatuses: [String: GitFileStatus]
    let repositoryInfo: GitRepositoryInfo
    let timestamp: Date
    
    /// 检查缓存是否过期
    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}
