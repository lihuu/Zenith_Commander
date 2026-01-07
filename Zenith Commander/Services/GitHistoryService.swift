//
//  GitHistoryService.swift
//  Zenith Commander
//
//  Git history data loading service.
//

import Foundation

struct GitHistoryPage {
    let commits: [GitCommit]
    let hasMore: Bool
}

protocol GitHistoryFetching {
    func getFileHistory(
        for file: URL,
        limit: Int,
        skip: Int
    ) async -> [GitCommit]

    func getRepositoryHistory(
        at directory: URL,
        limit: Int,
        skip: Int
    ) async -> [GitCommit]
}

protocol GitHistoryServicing {
    func loadFileHistory(
        for file: URL,
        pageSize: Int,
        skip: Int
    ) async -> GitHistoryPage

    func loadRepositoryHistory(
        at path: URL,
        pageSize: Int,
        skip: Int
    ) async -> GitHistoryPage
}

final class GitHistoryService: GitHistoryServicing {
    private let gitService: GitHistoryFetching

    init(gitService: GitHistoryFetching = GitService.shared) {
        self.gitService = gitService
    }

    func loadFileHistory(
        for file: URL,
        pageSize: Int,
        skip: Int
    ) async -> GitHistoryPage {
        let commits = await gitService.getFileHistory(
            for: file,
            limit: pageSize,
            skip: skip
        )
        return GitHistoryPage(commits: commits, hasMore: commits.count >= pageSize)
    }

    func loadRepositoryHistory(
        at path: URL,
        pageSize: Int,
        skip: Int
    ) async -> GitHistoryPage {
        let commits = await gitService.getRepositoryHistory(
            at: path,
            limit: pageSize,
            skip: skip
        )
        return GitHistoryPage(commits: commits, hasMore: commits.count >= pageSize)
    }
}

extension GitService: GitHistoryFetching {}
