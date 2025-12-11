//
//  StatusBarView.swift
//  Zenith Commander
//
//  底部状态栏
//

import SwiftUI

struct StatusBarView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let mode: AppMode
    let statusText: String
    let driveName: String
    let itemCount: Int
    let selectedCount: Int
    var gitInfo: GitRepositoryInfo? = nil
    var onDriveClick: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            // 模式指示器
            ModeIndicator(mode: mode)
            
            // Git 分支信息
            if let gitInfo = gitInfo, gitInfo.isGitRepository {
                GitBranchIndicator(gitInfo: gitInfo)
            }
            
            // 状态文本 - 驱动器名称可点击
            statusContent
            
            Spacer()
            
            // 选中计数
            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15))
                    .cornerRadius(3)
            }
            
            // 项目计数
            Text("\(itemCount) items")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)
            
            // 快捷键提示
            Text(keyHint)
                .font(.system(size: 10))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Theme.backgroundSecondary)
    }
    
    private var keyHint: String {
        switch mode {
        case .normal:
            return "? for help"
        case .visual:
            return "ESC to exit"
        case .command:
            return "Enter to execute"
        case .filter:
            return "Enter to confirm"
        case .driveSelect:
            return "j/k to navigate"
        case .aiAnalysis:
            return "ESC to close"
        case .rename:
            return "ESC to cancel"
        case .settings:
            return "ESC to close"
        case .help:
            return "ESC or ? to close"
        default:
            return "ESC to close"
        }
        
    }
    
    /// 状态内容 - 根据模式显示不同内容
    @ViewBuilder
    private var statusContent: some View {
        switch mode {
        case .command, .filter:
            // 命令模式和过滤模式显示输入内容
            Text(statusText)
                .accessibilityLabel(statusText)
                .accessibilityValue(statusText)
                .accessibilityIdentifier("status_text")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        default:
            // 普通模式显示可点击的驱动器名称
            HStack(spacing: 0) {
                // 可点击的驱动器名称
                Text(driveName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Theme.accent.opacity(0.1))
                    .cornerRadius(3)
                    .onTapGesture {
                        onDriveClick?()
                    }
                    .help("Click to switch drive (Shift+D)")
                    .accessibilityIdentifier("drive_name_button")
                
                // 分隔符和当前文件名
                Text(" | \(currentFileName)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .accessibilityLabel(statusText)
            .accessibilityIdentifier("status_text")
        }
    }
    
    /// 从 statusText 中提取当前文件名
    private var currentFileName: String {
        if let separatorIndex = statusText.firstIndex(of: "|") {
            let afterSeparator = statusText[statusText.index(after: separatorIndex)...]
            return afterSeparator.trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}

struct ModeIndicator: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let mode: AppMode
    
    var body: some View {
        Text(mode.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(mode.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(mode.backgroundColor)
            .cornerRadius(3)
            .accessibilityLabel(mode.rawValue)
            .accessibilityValue(mode.rawValue)
            .accessibilityIdentifier("mode_indicator")
    }
}

/// Git 分支指示器
struct GitBranchIndicator: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let gitInfo: GitRepositoryInfo
    
    var body: some View {
        HStack(spacing: 4) {
            // 分支图标
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(branchColor)
            
            // 分支名
            if let branch = gitInfo.branchDisplayText {
                Text(branch)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(branchColor)
                    .lineLimit(1)
            }
            
            // ahead/behind 状态
            if let syncStatus = gitInfo.syncStatusText {
                Text(syncStatus)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }
            
            // 未提交更改标记
            if gitInfo.hasUncommittedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Theme.backgroundTertiary)
        .cornerRadius(3)
        .accessibilityLabel("Git branch: \(gitInfo.branchDisplayText ?? "unknown")")
        .accessibilityIdentifier("git_branch_indicator")
    }
    
    private var branchColor: Color {
        if gitInfo.isDetachedHead {
            return .orange
        }
        return Theme.accent
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusBarView(
            mode: .normal,
            statusText: "Macintosh HD | Documents",
            driveName: "Macintosh HD",
            itemCount: 42,
            selectedCount: 0
        )
        
        StatusBarView(
            mode: .visual,
            statusText: "Macintosh HD | file.txt",
            driveName: "Macintosh HD",
            itemCount: 42,
            selectedCount: 3
        )
        
        StatusBarView(
            mode: .command,
            statusText: ":ai summarize this folder",
            driveName: "Macintosh HD",
            itemCount: 42,
            selectedCount: 0
        )
       
    }
    .background(Theme.background)
}
