//
//  GitHistoryTests.swift
//  Zenith CommanderTests
//
//  Git 历史功能测试
//

import XCTest
@testable import Zenith_Commander

class GitHistoryTests: XCTestCase {
    
    func testGitCommitInitialization() {
        let date = Date()
        let commit = GitCommit(
            id: "abc123def456",
            shortHash: "abc123d",
            message: "Test commit",
            fullMessage: "Test commit\n\nDetails",
            author: "Test Author",
            authorEmail: "test@example.com",
            date: date,
            parentHashes: ["parent1"]
        )
        
        XCTAssertEqual(commit.id, "abc123def456")
        XCTAssertEqual(commit.shortHash, "abc123d")
        XCTAssertEqual(commit.message, "Test commit")
        XCTAssertEqual(commit.fullMessage, "Test commit\n\nDetails")
        XCTAssertEqual(commit.author, "Test Author")
        XCTAssertEqual(commit.authorEmail, "test@example.com")
        XCTAssertEqual(commit.date, date)
        XCTAssertEqual(commit.parentHashes, ["parent1"])
    }
    
    func testIsMergeCommit() {
        let normalCommit = GitCommit(
            id: "1", shortHash: "1", message: "msg", fullMessage: "msg",
            author: "a", authorEmail: "e", date: Date(),
            parentHashes: ["p1"]
        )
        XCTAssertFalse(normalCommit.isMergeCommit)
        
        let mergeCommit = GitCommit(
            id: "2", shortHash: "2", message: "msg", fullMessage: "msg",
            author: "a", authorEmail: "e", date: Date(),
            parentHashes: ["p1", "p2"]
        )
        XCTAssertTrue(mergeCommit.isMergeCommit)
        
        let initialCommit = GitCommit(
            id: "3", shortHash: "3", message: "msg", fullMessage: "msg",
            author: "a", authorEmail: "e", date: Date(),
            parentHashes: []
        )
        XCTAssertFalse(initialCommit.isMergeCommit)
    }
    
    func testGitRepositoryInfo() {
        let info = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: URL(fileURLWithPath: "/tmp/repo"),
            currentBranch: "main",
            isDetachedHead: false,
            ahead: 1,
            behind: 2,
            hasUncommittedChanges: true
        )
        
        XCTAssertTrue(info.isGitRepository)
        XCTAssertEqual(info.currentBranch, "main")
        XCTAssertEqual(info.branchDisplayText, "main")
        XCTAssertEqual(info.syncStatusText, "↑1 ↓2")
        
        let detachedInfo = GitRepositoryInfo(
            isGitRepository: true,
            rootPath: nil,
            currentBranch: nil,
            isDetachedHead: true,
            ahead: 0,
            behind: 0,
            hasUncommittedChanges: false
        )
        XCTAssertEqual(detachedInfo.branchDisplayText, "HEAD")
        XCTAssertNil(detachedInfo.syncStatusText)
        
        let notRepo = GitRepositoryInfo.notARepository
        XCTAssertFalse(notRepo.isGitRepository)
        XCTAssertNil(notRepo.branchDisplayText)
        XCTAssertNil(notRepo.syncStatusText)
    }
}
