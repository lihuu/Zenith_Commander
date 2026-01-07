//
//  GitHistoryServiceTests.swift
//  Zenith CommanderTests
//

import XCTest
@testable import Zenith_Commander

@MainActor
final class GitHistoryServiceTests: XCTestCase {
    final class StubGitHistoryFetcher: GitHistoryFetching {
        let fileCommits: [GitCommit]
        let repoCommits: [GitCommit]

        init(fileCommits: [GitCommit], repoCommits: [GitCommit]) {
            self.fileCommits = fileCommits
            self.repoCommits = repoCommits
        }

        func getFileHistory(
            for file: URL,
            limit: Int,
            skip: Int
        ) async -> [GitCommit] {
            Array(fileCommits.dropFirst(skip).prefix(limit))
        }

        func getRepositoryHistory(
            at directory: URL,
            limit: Int,
            skip: Int
        ) async -> [GitCommit] {
            Array(repoCommits.dropFirst(skip).prefix(limit))
        }
    }

    private func makeCommit(id: String) -> GitCommit {
        GitCommit(
            id: id,
            shortHash: String(id.prefix(7)),
            message: "Commit \(id)",
            fullMessage: "Commit \(id)",
            author: "Author",
            authorEmail: "author@example.com",
            date: Date(),
            parentHashes: []
        )
    }

    func testLoadFileHistorySetsHasMoreWhenPageFilled() async {
        let commits = [makeCommit(id: "a1"), makeCommit(id: "b2")]
        let service = GitHistoryService(
            gitService: StubGitHistoryFetcher(
                fileCommits: commits,
                repoCommits: []
            )
        )

        let page = await service.loadFileHistory(
            for: URL(fileURLWithPath: "/tmp/file.txt"),
            pageSize: 2,
            skip: 0
        )

        XCTAssertEqual(page.commits, commits)
        XCTAssertTrue(page.hasMore)
    }

    func testLoadRepositoryHistorySetsHasMoreFalseWhenShortPage() async {
        let commits = [makeCommit(id: "c3")]
        let service = GitHistoryService(
            gitService: StubGitHistoryFetcher(
                fileCommits: [],
                repoCommits: commits
            )
        )

        let page = await service.loadRepositoryHistory(
            at: URL(fileURLWithPath: "/tmp"),
            pageSize: 2,
            skip: 0
        )

        XCTAssertEqual(page.commits, commits)
        XCTAssertFalse(page.hasMore)
    }
}
