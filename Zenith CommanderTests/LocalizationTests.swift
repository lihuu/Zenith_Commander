//
//  LocalizationTests.swift
//  Zenith CommanderTests
//
//  Created by Zenith Commander on 2025/12/03.
//

import XCTest
import Combine
@testable import Zenith_Commander

class LocalizationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset to English before each test
        LocalizationManager.shared.setLanguage(.english)
    }
    
    override func tearDown() {
        // Reset to English after each test
        LocalizationManager.shared.setLanguage(.english)
        super.tearDown()
    }
    
    // MARK: - 语言切换基础测试
    
    func testLanguageSwitchToChineseThenBack() {
        // Given - 初始为英文
        LocalizationManager.shared.setLanguage(.english)
        XCTAssertEqual(LocalizationManager.shared.currentLanguage, .english)
        
        // When - 切换到中文
        LocalizationManager.shared.setLanguage(.chinese)
        
        // Then - 应该是中文
        XCTAssertEqual(LocalizationManager.shared.currentLanguage, .chinese)
        XCTAssertEqual(LocalizationManager.shared.localized(.ok), "确定")
        XCTAssertEqual(LocalizationManager.shared.localized(.cancel), "取消")
        
        // When - 切换回英文
        LocalizationManager.shared.setLanguage(.english)
        
        // Then - 应该是英文
        XCTAssertEqual(LocalizationManager.shared.currentLanguage, .english)
        XCTAssertEqual(LocalizationManager.shared.localized(.ok), "OK")
        XCTAssertEqual(LocalizationManager.shared.localized(.cancel), "Cancel")
    }
    
    func testLanguagePersistence() {
        // Given
        let languageKey = "app_language"
        
        // When - 设置中文
        LocalizationManager.shared.setLanguage(.chinese)
        
        // Then - UserDefaults 应该保存了中文设置
        let savedLanguage = UserDefaults.standard.string(forKey: languageKey)
        XCTAssertEqual(savedLanguage, AppLanguage.chinese.rawValue)
        
        // When - 设置英文
        LocalizationManager.shared.setLanguage(.english)
        
        // Then - UserDefaults 应该保存了英文设置
        let savedEnglish = UserDefaults.standard.string(forKey: languageKey)
        XCTAssertEqual(savedEnglish, AppLanguage.english.rawValue)
    }
    
    func testAppleLanguagesIsSyncedWithAppLanguage() {
        // When - 设置中文
        LocalizationManager.shared.setLanguage(.chinese)
        
        // Then - AppleLanguages 应该同步更新
        let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertNotNil(appleLanguages)
        XCTAssertEqual(appleLanguages?.first, AppLanguage.chinese.rawValue)
        
        // When - 设置英文
        LocalizationManager.shared.setLanguage(.english)
        
        // Then
        let appleLanguagesEn = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(appleLanguagesEn?.first, AppLanguage.english.rawValue)
    }
    
    // MARK: - 菜单栏本地化测试
    
    func testMenuLocalizationEnglish() {
        // Given
        LocalizationManager.shared.setLanguage(.english)
        
        // Then
        XCTAssertEqual(LocalizationManager.shared.localized(.menuNavigation), "Navigation")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuView), "View")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuHelp), "Help")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuSettings), "Settings...")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuShowHelp), "Zenith Commander Help")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuCut), "Cut")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuCopy), "Copy")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuPaste), "Paste")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuSelectAll), "Select All")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuUndo), "Undo")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuRedo), "Redo")
    }
    
    func testMenuLocalizationChinese() {
        // Given
        LocalizationManager.shared.setLanguage(.chinese)
        
        // Then
        XCTAssertEqual(LocalizationManager.shared.localized(.menuNavigation), "导航")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuView), "视图")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuHelp), "帮助")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuSettings), "设置...")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuShowHelp), "Zenith Commander 帮助")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuCut), "剪切")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuCopy), "拷贝")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuPaste), "粘贴")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuSelectAll), "全选")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuUndo), "撤销")
        XCTAssertEqual(LocalizationManager.shared.localized(.menuRedo), "重做")
    }
    
    // MARK: - 上下文菜单本地化测试
    
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
    
    // MARK: - 设置页面本地化测试
    
    func testSettingsLocalizationEnglish() {
        // Given
        LocalizationManager.shared.setLanguage(.english)
        
        // Then
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsLanguage), "Language")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartRequired), "Restart required for menu language to take effect")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartTitle), "Restart Required")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartNow), "Restart Now")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartLater), "Restart Later")
    }
    
    func testSettingsLocalizationChinese() {
        // Given
        LocalizationManager.shared.setLanguage(.chinese)
        
        // Then
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsLanguage), "语言")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartRequired), "需要重启应用以使菜单语言生效")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartTitle), "需要重启")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartNow), "立即重启")
        XCTAssertEqual(LocalizationManager.shared.localized(.settingsRestartLater), "稍后重启")
    }
    
    // MARK: - 调试测试：检查当前语言状态
    
    func testDebugPrintLanguageState() {
        // 打印当前 UserDefaults 中的语言设置
        let appLanguage = UserDefaults.standard.string(forKey: "app_language")
        let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        
        print("=== 语言设置调试信息 ===")
        print("app_language (UserDefaults): \(appLanguage ?? "nil")")
        print("AppleLanguages (UserDefaults): \(appleLanguages ?? [])")
        print("LocalizationManager.currentLanguage: \(LocalizationManager.shared.currentLanguage.rawValue)")
        print("LocalizationManager.currentLanguage.nativeName: \(LocalizationManager.shared.currentLanguage.nativeName)")
        print("===========================")
        
        // 验证一致性
        XCTAssertEqual(appLanguage, LocalizationManager.shared.currentLanguage.rawValue,
                       "app_language 应该和 LocalizationManager.currentLanguage 一致")
    }
    
    func testLanguageChangeNotification() {
        // Given
        var notificationReceived = false
        let expectation = XCTestExpectation(description: "Language change notification")
        
        // 订阅变更
        let cancellable = LocalizationManager.shared.$currentLanguage
            .dropFirst() // 跳过初始值
            .sink { language in
                notificationReceived = true
                expectation.fulfill()
            }
        
        // When
        LocalizationManager.shared.setLanguage(.chinese)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(notificationReceived)
        
        cancellable.cancel()
    }
}
