//
//  GitHistoryView.swift
//  Zenith Commander
//
//  Git 历史记录面板视图
//

import SwiftUI

/// Git 历史面板视图
struct GitHistoryPanelView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let fileName: String
    let commits: [GitCommit]
    let isLoading: Bool
    let onClose: () -> Void
    let onCommitSelected: (GitCommit) -> Void
    
    @State private var selectedCommitId: String?
    @State private var hoveredCommitId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 内容区域
            if isLoading {
                loadingView
            } else if commits.isEmpty {
                emptyView
            } else {
                commitListView
            }
        }
        .background(Theme.background)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(Theme.accent)
            
            Text(L(.gitHistory))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            
            Text(fileName)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Text("\(commits.count) \(L(.gitCommits))")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(4)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.backgroundSecondary)
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
            Text(L(.gitLoadingHistory))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(Theme.textTertiary)
            
            Text(L(.gitNoHistory))
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Commit List
    
    private var commitListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(commits) { commit in
                    GitCommitRowView(
                        commit: commit,
                        isSelected: selectedCommitId == commit.id,
                        isHovered: hoveredCommitId == commit.id
                    )
                    .onTapGesture {
                        selectedCommitId = commit.id
                        onCommitSelected(commit)
                    }
                    .onHover { isHovered in
                        hoveredCommitId = isHovered ? commit.id : nil
                    }
                    
                    if commit.id != commits.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }
}

// MARK: - Commit Row View

struct GitCommitRowView: View {
    let commit: GitCommit
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // Commit hash
            Text(commit.shortHash)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.accent)
                .frame(width: 60, alignment: .leading)
            
            // Commit message
            Text(commit.message)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Date
            Text(commit.relativeDate)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 70, alignment: .trailing)
            
            // Author
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                
                Text(commit.author)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .contentShape(Rectangle())
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Theme.selection
        } else if isHovered {
            return Theme.backgroundSecondary.opacity(0.5)
        }
        return .clear
    }
}

// MARK: - Resizable Panel Container

/// 可调整大小的底部面板容器
struct ResizableBottomPanel<Content: View>: View {
    @Binding var height: CGFloat
    @Binding var isVisible: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let content: () -> Content
    
    @State private var isDragging = false
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // 拖动手柄
                dragHandle
                
                // 内容
                content()
                    .frame(height: height)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var dragHandle: some View {
        Rectangle()
            .fill(isDragging ? Theme.accent : Theme.border)
            .frame(height: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.textTertiary)
                    .frame(width: 40, height: 3)
            )
            .contentShape(Rectangle().size(width: .infinity, height: 12))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = height - value.translation.height
                        height = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { isHovered in
                if isHovered {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let sampleCommits = [
        GitCommit(
            id: "abc123def456",
            shortHash: "abc123d",
            message: "Fix path parsing for git status",
            fullMessage: "Fix path parsing for git status\n\nThis commit fixes the issue with quoted paths.",
            author: "lihu",
            authorEmail: "lihu@example.com",
            date: Date().addingTimeInterval(-3600),
            parentHashes: ["parent1"]
        ),
        GitCommit(
            id: "def456ghi789",
            shortHash: "def456g",
            message: "Add git status integration",
            fullMessage: "Add git status integration",
            author: "lihu",
            authorEmail: "lihu@example.com",
            date: Date().addingTimeInterval(-86400),
            parentHashes: ["parent2"]
        ),
        GitCommit(
            id: "ghi789jkl012",
            shortHash: "ghi789j",
            message: "Initial commit",
            fullMessage: "Initial commit",
            author: "lihu",
            authorEmail: "lihu@example.com",
            date: Date().addingTimeInterval(-172800),
            parentHashes: []
        )
    ]
    
    GitHistoryPanelView(
        fileName: "GitService.swift",
        commits: sampleCommits,
        isLoading: false,
        onClose: {},
        onCommitSelected: { _ in }
    )
    .frame(height: 200)
}
