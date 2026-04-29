//
//  LocalizationTests.swift
//  Zenith CommanderTests
//
//  Created by Zenith Commander on 2025/12/03.
//

import XCTest

@testable import Zenith_Commander

@MainActor
class LocalizationTests: XCTestCase {
    // MARK: - 系统语言检测测试

    func testCurrentLanguageIsValid() {
        // 当前语言应该是支持的语言之一
        let currentLanguage = LocalizationManager.shared.currentLanguage
        XCTAssertTrue(AppLanguage.allCases.contains(currentLanguage))
    }

    func testLocalizationReturnsNonEmptyString() {
        // 本地化字符串不应为空
        let okString = LocalizationManager.shared.localized(.ok)
        let cancelString = LocalizationManager.shared.localized(.cancel)

        XCTAssertFalse(okString.isEmpty)
        XCTAssertFalse(cancelString.isEmpty)
    }

    // MARK: - 本地化字符串测试

    func testEnglishStringsExist() {
        // 验证英文字符串存在
        let strings = LocalizedStrings.shared

        XCTAssertEqual(strings.get(.ok, for: .english), "OK")
        XCTAssertEqual(strings.get(.cancel, for: .english), "Cancel")
        XCTAssertEqual(strings.get(.menuNavigation, for: .english), "Navigation")
        XCTAssertEqual(strings.get(.menuView, for: .english), "View")
        XCTAssertEqual(strings.get(.menuHelp, for: .english), "Help")
    }

    func testChineseStringsExist() {
        // 验证中文字符串存在
        let strings = LocalizedStrings.shared

        XCTAssertEqual(strings.get(.ok, for: .chinese), "确定")
        XCTAssertEqual(strings.get(.cancel, for: .chinese), "取消")
        XCTAssertEqual(strings.get(.menuNavigation, for: .chinese), "导航")
        XCTAssertEqual(strings.get(.menuView, for: .chinese), "视图")
        XCTAssertEqual(strings.get(.menuHelp, for: .chinese), "帮助")
    }

    // MARK: - 菜单本地化测试

    func testMenuStringsEnglish() {
        let strings = LocalizedStrings.shared

        XCTAssertEqual(strings.get(.menuSettings, for: .english), "Settings...")
        XCTAssertEqual(strings.get(.menuShowHelp, for: .english), "Zenith Commander Help")
        XCTAssertEqual(strings.get(.menuCut, for: .english), "Cut")
        XCTAssertEqual(strings.get(.menuCopy, for: .english), "Copy")
        XCTAssertEqual(strings.get(.menuPaste, for: .english), "Paste")
        XCTAssertEqual(strings.get(.menuSelectAll, for: .english), "Select All")
        XCTAssertEqual(strings.get(.menuUndo, for: .english), "Undo")
        XCTAssertEqual(strings.get(.menuRedo, for: .english), "Redo")
    }

    func testMenuStringsChinese() {
        let strings = LocalizedStrings.shared

        XCTAssertEqual(strings.get(.menuSettings, for: .chinese), "设置...")
        XCTAssertEqual(strings.get(.menuShowHelp, for: .chinese), "Zenith Commander 帮助")
        XCTAssertEqual(strings.get(.menuCut, for: .chinese), "剪切")
        XCTAssertEqual(strings.get(.menuCopy, for: .chinese), "拷贝")
        XCTAssertEqual(strings.get(.menuPaste, for: .chinese), "粘贴")
        XCTAssertEqual(strings.get(.menuSelectAll, for: .chinese), "全选")
        XCTAssertEqual(strings.get(.menuUndo, for: .chinese), "撤销")
        XCTAssertEqual(strings.get(.menuRedo, for: .chinese), "重做")
    }

    // MARK: - 上下文菜单本地化测试

    func testContextMenuStringsEnglish() {
        let strings = LocalizedStrings.shared

        XCTAssertEqual(strings.get(.contextOpen, for: .english), "Open")
        XCTAssertEqual(strings.get(.contextOpenInTerminal, for: .english), "Open in Terminal")
        XCTAssertEqual(strings.get(.contextShowInFinder, for: .english), "Show in Finder")
        XCTAssertEqual(strings.get(.contextCopyFullPath, for: .english), "Copy Full Path")
        XCTAssertEqual(strings.get(.contextMoveToTrash, for: .english), "Move to Trash")
        XCTAssertEqual(strings.get(.contextNewFile, for: .english), "New File")
        XCTAssertEqual(strings.get(.contextNewFolder, for: .english), "New Folder")
        XCTAssertEqual(strings.get(.settingsAI, for: .english), "AI Tools")
        XCTAssertEqual(strings.get(.aiOpenToolHere, for: .english), "Open %@ Here")
    }

    func testContextMenuStringsChinese() {
        let strings = LocalizedStrings.shared

        XCTAssertEqual(strings.get(.contextOpen, for: .chinese), "打开")
        XCTAssertEqual(strings.get(.contextOpenInTerminal, for: .chinese), "在终端中打开")
        XCTAssertEqual(strings.get(.contextShowInFinder, for: .chinese), "在访达中显示")
        XCTAssertEqual(strings.get(.contextCopyFullPath, for: .chinese), "复制完整路径")
        XCTAssertEqual(strings.get(.contextMoveToTrash, for: .chinese), "移到废纸篓")
        XCTAssertEqual(strings.get(.contextNewFile, for: .chinese), "新建文件")
        XCTAssertEqual(strings.get(.contextNewFolder, for: .chinese), "新建文件夹")
        XCTAssertEqual(strings.get(.settingsAI, for: .chinese), "AI 工具")
        XCTAssertEqual(strings.get(.aiOpenToolHere, for: .chinese), "在此打开 %@")
    }

    // MARK: - AppLanguage 测试

    func testAppLanguageProperties() {
        // 测试英文属性
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.english.nativeName, "English")
        XCTAssertEqual(AppLanguage.english.icon, "🇺🇸")

        // 测试中文属性
        XCTAssertEqual(AppLanguage.chinese.rawValue, "zh-Hans")
        XCTAssertEqual(AppLanguage.chinese.nativeName, "简体中文")
        XCTAssertEqual(AppLanguage.chinese.icon, "🇨🇳")
    }

    func testAppLanguageAllCases() {
        // 确保只有两种语言
        XCTAssertEqual(AppLanguage.allCases.count, 2)
        XCTAssertTrue(AppLanguage.allCases.contains(.english))
        XCTAssertTrue(AppLanguage.allCases.contains(.chinese))
    }
}
