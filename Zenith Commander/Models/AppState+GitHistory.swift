//
//  AppState+GitHistory.swift
//  Zenith Commander
//
//  Git 历史相关状态与行为
//

import Foundation
import os.log

extension AppState {
    /// 显示文件的 Git 历史
    func showGitHistoryForFile(_ file: FileItem) {
        // 先在主线程复制需要的值，避免在后台线程访问可能触发 UI 更新的属性
        let filePath = file.path

        gitHistoryFile = file
        gitHistoryLoading = true
        showGitHistory = true

        // 异步加载历史
        Task {
            let commits = await GitService.shared.getFileHistory(for: filePath)

            self.gitHistoryCommits = commits
            self.gitHistoryLoading = false
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
            showToast("Select a file to view Git history")
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
        showGitHistory = true

        Logger.git.debug(
            "State updated: showGitHistory=true, gitHistoryLoading=true"
        )

        // 异步加载历史
        Task {
            let commits = await GitService.shared.getRepositoryHistory(at: path)

            self.gitHistoryCommits = commits
            self.gitHistoryLoading = false
            Logger.git.debug(
                "State updated: gitHistoryLoading=false, commits: \(commits.count)"
            )
        }
    }

    /// 关闭 Git 历史面板
    func closeGitHistory() {
        Logger.git.debug("closeGitHistory called")
        showGitHistory = false
        gitHistoryFile = nil
        gitHistoryCommits = []
        Logger.git.debug("Git history panel closed and state cleared")
    }
}
