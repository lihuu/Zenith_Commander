//
//  GitHistoryView.swift
//  Zenith Commander
//
//  Git 历史记录面板视图
//

import OSLog
import SwiftUI
import os.log

// Helper function to access localization
private func L(_ key: LocalizedStringKey) -> String {
    LocalizationManager.shared.localized(key)
}

/// Git 历史面板视图
struct GitHistoryPanelView: View {
    let context: PluginContext
    @ObservedObject private var themeManager = ThemeManager.shared

    let fileName: String
    let commits: [GitCommit]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let onClose: () -> Void
    let onCommitSelected: (GitCommit) -> Void
    let onLoadMore: () -> Void

    @State private var selectedCommitId: String?
    @State private var hoveredCommitId: String?
    @State private var showingCommitDetail: GitCommit?

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
        .sheet(item: $showingCommitDetail) { commit in
            GitCommitDetailView(commit: commit)
        }
        .onAppear {
            context.logger.info(
                "GitHistoryPanelView appeared - fileName: \(fileName), commits: \(commits.count)")
        }
        .onDisappear {
            context.logger.info("GitHistoryPanelView disappeared")
        }
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
                    makeCommitRow(for: commit)

                    if commit.id != commits.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }

                // 加载更多区域
                if hasMore || isLoadingMore {
                    loadMoreView
                }
            }
        }
    }

    private var loadMoreView: some View {
        Group {
            if isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L(.gitLoadingMore))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if hasMore {
                Button(action: onLoadMore) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                        Text(L(.gitLoadMore))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.backgroundSecondary.opacity(0.5))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onAppear {
                    // 自动加载更多（无限滚动）
                    onLoadMore()
                }
            }
        }
    }

    @ViewBuilder
    private func makeCommitRow(for commit: GitCommit) -> some View {
        GitCommitRowView(
            commit: commit,
            isSelected: selectedCommitId == commit.id,
            isHovered: hoveredCommitId == commit.id
        )
        .equatable()
        .onTapGesture {
            selectedCommitId = commit.id
            onCommitSelected(commit)
        }
        .contextMenu {
            Button(L(.gitShowDetails)) {
                showingCommitDetail = commit
            }

            Button(L(.gitCopyHash)) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(commit.id, forType: .string)
            }
        }
        .onHover { isHovered in
            hoveredCommitId = isHovered ? commit.id : nil
        }
    }
}

// MARK: - Commit Detail View

/// Git 提交详情视图
struct GitCommitDetailView: View {
    let commit: GitCommit
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L(.gitCommitDetails))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Theme.backgroundSecondary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 基本信息
                    Group {
                        detailRow(icon: "number", title: L(.gitCommitHash), value: commit.id)
                        detailRow(
                            icon: "person", title: L(.gitCommitAuthor),
                            value: "\(commit.author) <\(commit.authorEmail)>")
                        detailRow(
                            icon: "calendar", title: L(.gitCommitDate), value: commit.formattedDate)
                        if !commit.parentHashes.isEmpty {
                            detailRow(
                                icon: "arrow.turn.up.left", title: L(.gitCommitParent),
                                value: commit.parentHashes.joined(separator: ", "))
                        }
                    }

                    Divider()

                    // 提交信息
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L(.gitCommitMessage), systemImage: "text.alignleft")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Text(commit.fullMessage)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.backgroundSecondary.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
        .background(Theme.background)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(Theme.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Commit Row View

/// 优化的 Git Commit 行视图 - 使用 Equatable 减少重绘
struct GitCommitRowView: View, Equatable {
    let commit: GitCommit
    let isSelected: Bool
    let isHovered: Bool

    static func == (lhs: GitCommitRowView, rhs: GitCommitRowView) -> Bool {
        lhs.commit.id == rhs.commit.id && lhs.isSelected == rhs.isSelected
            && lhs.isHovered == rhs.isHovered
    }

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

// MARK: - Preview

#Preview {
    let mockContext = PluginContext(
        panes: { PanesSnapshot(leftPath: "/test/path", rightPath: "/test/path2", active: .left) },
        dispatch: { _ in },
        logger: Logger(subsystem: "preview", category: "git"),
        toolRunner: ProcessToolRunner()
    )

    let sampleCommits = [
        GitCommit(
            id: "abc123def456",
            shortHash: "abc123d",
            message: "Fix path parsing for git status",
            fullMessage:
                "Fix path parsing for git status\n\nThis commit fixes the issue with quoted paths.",
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
            date: Date().addingTimeInterval(-172_800),
            parentHashes: []
        ),
    ]

    GitHistoryPanelView(
        context: mockContext,
        fileName: "GitService.swift",
        commits: sampleCommits,
        isLoading: false,
        isLoadingMore: false,
        hasMore: true,
        onClose: {},
        onCommitSelected: { _ in },
        onLoadMore: {}
    )
    .frame(height: 200)
}
