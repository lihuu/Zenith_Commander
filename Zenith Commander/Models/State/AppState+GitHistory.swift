//
//  AppState+GitHistory.swift
//  Zenith Commander
//
//  Git 历史相关状态与行为
//

import Foundation
import os.log

/// Git 历史分页常量
private enum GitHistoryPagination {
    static let pageSize = 50
}

extension AppState {
    /// 显示文件的 Git 历史
    func showGitHistoryForFile(_ file: FileItem) {
        // 先在主线程复制需要的值，避免在后台线程访问可能触发 UI 更新的属性
        let filePath = file.path

        gitHistoryFile = file
        gitHistoryLoading = true
        gitHistoryLoadingMore = false
        gitHistoryHasMore = true
        showGitHistory = true
        gitHistoryCommits = []

        // 异步加载历史
        Task {
            let page = await env.gitHistory.loadFileHistory(
                for: filePath,
                pageSize: GitHistoryPagination.pageSize,
                skip: 0
            )

            self.gitHistoryCommits = page.commits
            self.gitHistoryLoading = false
            self.gitHistoryHasMore = page.hasMore
        }
    }

    /// 加载更多文件历史
    func loadMoreGitHistoryForFile() {
        guard let file = gitHistoryFile,
            !gitHistoryLoadingMore,
            gitHistoryHasMore
        else { return }

        gitHistoryLoadingMore = true
        let currentCount = gitHistoryCommits.count
        let filePath = file.path

        Task {
            let page = await env.gitHistory.loadFileHistory(
                for: filePath,
                pageSize: GitHistoryPagination.pageSize,
                skip: currentCount
            )

            self.gitHistoryCommits.append(contentsOf: page.commits)
            self.gitHistoryLoadingMore = false
            self.gitHistoryHasMore = page.hasMore
        }
    }

    /// 显示当前选中文件的 Git 历史
    func showGitHistoryForCurrentFile() {
        Logger.git.debug("showGitHistoryForCurrentFile called")

        let files = currentPane.currentFiles
        let cursorIndex = currentPane.cursorIndex

        Logger.git.debug(
            "cursorIndex: \(cursorIndex), files.count: \(files.count)"
        )

        guard cursorIndex >= 0 && cursorIndex < files.count else {
            Logger.git.warning(
                "Invalid cursor index: \(cursorIndex) for files count: \(files.count)"
            )
            return
        }

        let file = files[cursorIndex]
        Logger.git.debug(
            "Selected file: \(file.name, privacy: .public), type: \(String(describing: file.type), privacy: .public)"
        )

        // 不显示文件夹和父目录的历史
        if file.type == .folder || file.isParentDirectory {
            Logger.git.info(
                "Cannot show history for folder or parent directory"
            )
            showToast(
                LocalizationManager.shared.localized(
                    .toastSelectFileForGitHistory
                )
            )
            return
        }

        showGitHistoryForFile(file)
    }

    /// 显示仓库的 Git 历史
    func showGitHistoryForRepo(at path: URL) {
        Logger.git.info(
            "showGitHistoryForRepo called for: \(path.path, privacy: .public)"
        )

        // 清除文件引用，表示是仓库级别的历史
        gitHistoryFile = nil
        gitHistoryLoading = true
        gitHistoryLoadingMore = false
        gitHistoryHasMore = true
        showGitHistory = true
        gitHistoryCommits = []
        gitHistoryRepoPath = path

        Logger.git.debug(
            "State updated: showGitHistory=true, gitHistoryLoading=true"
        )

        // 异步加载历史
        Task {
            let page = await env.gitHistory.loadRepositoryHistory(
                at: path,
                pageSize: GitHistoryPagination.pageSize,
                skip: 0
            )

            self.gitHistoryCommits = page.commits
            self.gitHistoryLoading = false
            self.gitHistoryHasMore = page.hasMore
            Logger.git.debug(
                "State updated: gitHistoryLoading=false, commits: \(page.commits.count)"
            )
        }
    }

    /// 加载更多仓库历史
    func loadMoreGitHistoryForRepo() {
        guard gitHistoryFile == nil,
            let repoPath = gitHistoryRepoPath,
            !gitHistoryLoadingMore,
            gitHistoryHasMore
        else { return }

        gitHistoryLoadingMore = true
        let currentCount = gitHistoryCommits.count

        Task {
            let page = await env.gitHistory.loadRepositoryHistory(
                at: repoPath,
                pageSize: GitHistoryPagination.pageSize,
                skip: currentCount
            )

            self.gitHistoryCommits.append(contentsOf: page.commits)
            self.gitHistoryLoadingMore = false
            self.gitHistoryHasMore = page.hasMore
        }
    }

    /// 加载更多历史（自动判断是文件还是仓库）
    func loadMoreGitHistory() {
        if gitHistoryFile != nil {
            loadMoreGitHistoryForFile()
        } else {
            loadMoreGitHistoryForRepo()
        }
    }

    /// 关闭 Git 历史面板
    func closeGitHistory() {
        Logger.git.debug("closeGitHistory called")
        showGitHistory = false
        gitHistoryFile = nil
        gitHistoryCommits = []
        gitHistoryHasMore = true
        gitHistoryLoadingMore = false
        gitHistoryRepoPath = nil
        Logger.git.debug("Git history panel closed and state cleared")
    }
}
