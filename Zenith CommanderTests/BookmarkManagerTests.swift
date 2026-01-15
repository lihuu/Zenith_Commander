//
//  BookmarkManagerTests.swift
//  Zenith CommanderTests
//
//  测试书签管理器的隔离性
//

import XCTest
@testable import Zenith_Commander

@MainActor
class BookmarkManagerTestsNew: XCTestCase {
    var testDirectory: URL!
    var bookmarkManager: BookmarkManager!
    
    override func setUp() {
        super.setUp()
        testDirectory = TestHelpers.createTestDirectory()
        bookmarkManager = BookmarkManager(storageDirectory: testDirectory)
    }
    
    override func tearDown() {
        TestHelpers.cleanupTestDirectory(testDirectory)
        super.tearDown()
    }
    
    func testAddBookmark() {
        let bookmark = BookmarkItem(
            name: "Test Folder",
            path: URL(fileURLWithPath: "/tmp"),
            type: .folder
        )
        
        bookmarkManager.add(bookmark)
        
        XCTAssertEqual(bookmarkManager.bookmarks.count, 1)
        XCTAssertEqual(bookmarkManager.bookmarks.first?.name, "Test Folder")
    }
    
    
    func testIsolation() {
        // Clear shared instance to known state
        let sharedCount = BookmarkManager.shared.bookmarks.count
        
        // Add a bookmark to test manager
        let uniquePath = URL(fileURLWithPath: "/tmp/unique-\(UUID().uuidString)")
        let bookmark = BookmarkItem(
            name: "Test Folder",
            path: uniquePath,
            type: .folder
        )
        bookmarkManager.add(bookmark)
        
        // Production singleton should not contain this specific bookmark
        XCTAssertFalse(BookmarkManager.shared.contains(path: uniquePath))
        XCTAssertEqual(bookmarkManager.bookmarks.count, 1)
    }
}
