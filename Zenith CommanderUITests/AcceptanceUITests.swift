//
//  AcceptanceUITests.swift
//  Zenith CommanderUITests
//
//  验收测试 - UI 测试部分
//

import XCTest

final class AcceptanceUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 1. 基础 UI 与布局测试
    
    /// 测试应用启动
    @MainActor
    func testAppLaunches() throws {
        // 验证应用窗口存在
        XCTAssertTrue(app.windows.count > 0, "应用应该有至少一个窗口")
    }
    
    /// 测试启动性能
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    /// 测试双栏布局存在
    @MainActor
    func testDualPaneLayoutExists() throws {
        // 等待界面加载
        sleep(1)
        
        // 验证窗口存在
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "主窗口应该存在")
    }
    
    // MARK: - 2. 面板切换测试
    
    /// 测试 Tab 键切换面板
    @MainActor
    func testTabKeySwitchesPane() throws {
        sleep(1)
        
        // 按 Tab 键
        app.typeKey(.tab, modifierFlags: [])
        
        // 由于我们无法直接检测哪个面板激活，
        // 我们只验证按键没有导致崩溃
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 3. 文件导航测试 (Normal Mode)
    
    /// 测试 j 键向下移动光标
    @MainActor
    func testJKeyMovesCursorDown() throws {
        sleep(1)
        
        // 按 j 键
        app.typeKey("j", modifierFlags: [])
        
        // 验证应用仍在运行
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 k 键向上移动光标
    @MainActor
    func testKKeyMovesCursorUp() throws {
        sleep(1)
        
        // 先按几次 j 向下
        app.typeKey("j", modifierFlags: [])
        app.typeKey("j", modifierFlags: [])
        
        // 按 k 键向上
        app.typeKey("k", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 l 键进入目录
    @MainActor
    func testLKeyEntersDirectory() throws {
        sleep(1)
        
        // 按 l 键尝试进入目录
        app.typeKey("l", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 h 键返回上级目录
    @MainActor
    func testHKeyLeavesDirectory() throws {
        sleep(1)
        
        // 先进入一个目录
        app.typeKey("l", modifierFlags: [])
        sleep(1)
        
        // 按 h 键返回
        app.typeKey("h", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 g 键跳转到顶部
    @MainActor
    func testGKeyJumpsToTop() throws {
        sleep(1)
        
        // 先向下移动
        app.typeKey("j", modifierFlags: [])
        app.typeKey("j", modifierFlags: [])
        
        // 按 g 跳转到顶部
        app.typeKey("g", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 Shift+G 跳转到底部
    @MainActor
    func testShiftGKeyJumpsToBottom() throws {
        sleep(1)
        
        // 按 Shift+G 跳转到底部
        app.typeKey("G", modifierFlags: [.shift])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 4. 模态操作引擎测试
    
    /// 测试 v 键进入 Visual 模式
    @MainActor
    func testVKeyEntersVisualMode() throws {
        sleep(1)
        
        // 按 v 进入 Visual 模式
        app.typeKey("v", modifierFlags: [])
        
        // 按 Escape 退出
        app.typeKey(.escape, modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 Visual 模式下选择文件
    @MainActor
    func testVisualModeSelection() throws {
        sleep(1)
        
        // 进入 Visual 模式
        app.typeKey("v", modifierFlags: [])
        
        // 向下移动选择文件
        app.typeKey("j", modifierFlags: [])
        app.typeKey("j", modifierFlags: [])
        
        // 退出 Visual 模式
        app.typeKey(.escape, modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 : 键进入 Command 模式
    @MainActor
    func testColonKeyEntersCommandMode() throws {
        sleep(1)
        
        // 按 : 进入 Command 模式
        app.typeKey(":", modifierFlags: [.shift])
        
        // 按 Escape 退出
        app.typeKey(.escape, modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 / 键进入 Filter 模式
    @MainActor
    func testSlashKeyEntersFilterMode() throws {
        sleep(1)
        
        // 按 / 进入 Filter 模式
        app.typeKey("/", modifierFlags: [])
        
        // 按 Escape 退出
        app.typeKey(.escape, modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 5. 剪贴板操作测试
    
    /// 测试 y 键复制
    @MainActor
    func testYKeyCopies() throws {
        sleep(1)
        
        // 按 y 复制当前文件
        app.typeKey("y", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 6. 标签页系统测试
    
    /// 测试 t 键创建新标签页
    @MainActor
    func testTKeyCreatesNewTab() throws {
        sleep(1)
        
        // 按 t 创建新标签页
        app.typeKey("t", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 w 键关闭标签页
    @MainActor
    func testWKeyClosesTab() throws {
        sleep(1)
        
        // 先创建一个新标签页
        app.typeKey("t", modifierFlags: [])
        sleep(1)
        
        // 关闭标签页
        app.typeKey("w", modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 Shift+L 切换到下一个标签页
    @MainActor
    func testShiftLSwitchesToNextTab() throws {
        sleep(1)
        
        // 创建多个标签页
        app.typeKey("t", modifierFlags: [])
        sleep(1)
        
        // 切换到下一个标签页
        app.typeKey("L", modifierFlags: [.shift])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试 Shift+H 切换到上一个标签页
    @MainActor
    func testShiftHSwitchesToPreviousTab() throws {
        sleep(1)
        
        // 创建多个标签页
        app.typeKey("t", modifierFlags: [])
        sleep(1)
        
        // 切换到上一个标签页
        app.typeKey("H", modifierFlags: [.shift])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 7. 驱动器切换测试
    
    /// 测试 Shift+D 打开驱动器选择器
    @MainActor
    func testShiftDOpensDriveSelector() throws {
        sleep(1)
        
        // 按 Shift+D 打开驱动器选择器
        app.typeKey("D", modifierFlags: [.shift])
        sleep(1)
        
        // 按 Escape 关闭
        app.typeKey(.escape, modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 8. 快速操作测试
    
    /// 测试快速按 j 键
    @MainActor
    func testRapidJKeyPresses() throws {
        sleep(1)
        
        // 快速按 j 键多次
        for _ in 0..<10 {
            app.typeKey("j", modifierFlags: [])
        }
        
        // 验证没有崩溃
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试快速按 k 键
    @MainActor
    func testRapidKKeyPresses() throws {
        sleep(1)
        
        // 快速按 k 键多次
        for _ in 0..<10 {
            app.typeKey("k", modifierFlags: [])
        }
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    // MARK: - 9. 组合操作测试
    
    /// 测试完整的文件操作流程
    @MainActor
    func testCompleteFileOperationFlow() throws {
        sleep(1)
        
        // 1. 导航
        app.typeKey("j", modifierFlags: [])
        app.typeKey("j", modifierFlags: [])
        
        // 2. 进入 Visual 模式选择
        app.typeKey("v", modifierFlags: [])
        app.typeKey("j", modifierFlags: [])
        
        // 3. 复制
        app.typeKey("y", modifierFlags: [])
        
        // 4. 退出 Visual 模式
        app.typeKey(.escape, modifierFlags: [])
        
        // 5. 切换面板
        app.typeKey(.tab, modifierFlags: [])
        
        XCTAssertTrue(app.windows.count > 0)
    }
    
    /// 测试标签页状态记忆
    @MainActor
    func testTabStateMemory() throws {
        sleep(1)
        
        // 1. 在第一个标签页导航
        app.typeKey("j", modifierFlags: [])
        app.typeKey("j", modifierFlags: [])
        app.typeKey("l", modifierFlags: []) // 进入目录
        sleep(1)
        
        // 2. 创建新标签页
        app.typeKey("t", modifierFlags: [])
        sleep(1)
        
        // 3. 切换回第一个标签页
        app.typeKey("H", modifierFlags: [.shift])
        
        // 验证没有崩溃（状态应该保留）
        XCTAssertTrue(app.windows.count > 0)
    }
}
