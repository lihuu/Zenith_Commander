//
//  BookmarkManagerTests.swift
//  Zenith CommanderTests
//
//  测试书签管理器的隔离性
//

import XCTest
@testable import Zenith_Commander

class BookmarkManagerTests: XCTestCase {
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
    
    func testPersistence() {
        // Add a bookmark
        let bookmark = BookmarkItem(
            name: "Test Folder",
            path: URL(fileURLWithPath: "/tmp"),
            type: .folder
        )
        bookmarkManager.add(bookmark)
        
        // Create a new instance with the same test directory
        let newManager = BookmarkManager(storageDirectory: testDirectory)
        
        // Verify the bookmark was persisted
        XCTAssertEqual(newManager.bookmarks.count, 1)
        XCTAssertEqual(newManager.bookmarks.first?.name, "Test Folder")
    }
    
    func testIsolation() {
        // Add a bookmark to test manager
        let bookmark = BookmarkItem(
            name: "Test Folder",
            path: URL(fileURLWithPath: "/tmp"),
            type: .folder
        )
        bookmarkManager.add(bookmark)
        
        // Production singleton should not be affected
        XCTAssertNotEqual(BookmarkManager.shared.bookmarks.count, bookmarkManager.bookmarks.count)
    }
}
