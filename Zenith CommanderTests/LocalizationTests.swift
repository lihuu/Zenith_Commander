//
//  LocalizationTests.swift
//  Zenith CommanderTests
//
//  Created by Zenith Commander on 2025/12/03.
//

import XCTest
@testable import Zenith_Commander

class LocalizationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset to English before each test
        LocalizationManager.shared.setLanguage(.english)
    }
    
    func testContextMenuLocalizationEnglish() {
        // Given
        LocalizationManager.shared.setLanguage(.english)
        
        // When & Then
        XCTAssertEqual(LocalizationManager.shared.localized(.contextOpen), "Open")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextOpenInTerminal), "Open in Terminal")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextRemoveFromBookmarks), "Remove from Bookmarks")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextAddToBookmarks), "Add to Bookmarks (⌘B)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextCopyYank), "Copy (y)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextPaste), "Paste (p)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextShowInFinder), "Show in Finder")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextCopyFullPath), "Copy Full Path")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextMoveToTrash), "Move to Trash")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextRefresh), "Refresh (R)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextNewFile), "New File")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextNewFolder), "New Folder")
    }
    
    func testContextMenuLocalizationChinese() {
        // Given
        LocalizationManager.shared.setLanguage(.chinese)
        
        // When & Then
        XCTAssertEqual(LocalizationManager.shared.localized(.contextOpen), "打开")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextOpenInTerminal), "在终端中打开")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextRemoveFromBookmarks), "从书签中移除")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextAddToBookmarks), "添加到书签 (⌘B)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextCopyYank), "复制 (y)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextPaste), "粘贴 (p)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextShowInFinder), "在访达中显示")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextCopyFullPath), "复制完整路径")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextMoveToTrash), "移到废纸篓")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextRefresh), "刷新 (R)")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextNewFile), "新建文件")
        XCTAssertEqual(LocalizationManager.shared.localized(.contextNewFolder), "新建文件夹")
    }
}
