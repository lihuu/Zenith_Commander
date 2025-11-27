//
//  AcceptanceUITests.swift
//  Zenith CommanderUITests
//
//  验收测试 - UI 测试部分
//

import XCTest

final class AcceptanceUITests: XCTestCase {

    var app: XCUIApplication!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Create a temporary directory for this test run
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
        testDirectory = temporaryDirectoryURL
        
        app = XCUIApplication()
        // Use launch arguments to pass the test directory path
        app.launchArguments = ["-testDirectory", testDirectory.path]
        app.launch()
        
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "The main window should appear within 5 seconds.")
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        if let testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }
    
    /// Helper to wait for an element's label to match.
    func waitFor(element: XCUIElement, label: String, timeout: TimeInterval = 3) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("Failed to wait for element \(element.debugDescription) to have label '\(label)'. Current label: \(element.label)")
        }
    }
    
    // MARK: - 1. 基础 UI 与布局测试 (UI & Layout)
    
    @MainActor
    func test_1_1_AppLaunchesAndHasTwoPanes() throws {
        let window = app.windows.firstMatch
        
        let leftPane = window.descendants(matching: .any)["left_pane"]
        XCTAssertTrue(leftPane.exists, "The left pane should exist.")
        
        let rightPane = window.descendants(matching: .any)["right_pane"]
        XCTAssertTrue(rightPane.exists, "The right pane should exist.")
    }

    // MARK: - 2. 核心交互逻辑 (Core Interaction)
    
    @MainActor
    func test_2_1_PaneActivationOnClick() throws {
        let window = app.windows.firstMatch
        let leftPane = window.descendants(matching: .any)["left_pane"]
        let rightPane = window.descendants(matching: .any)["right_pane"]

        let leftHeader = app.descendants(matching: .any)["left_pane_header"]
        let rightHeader = app.descendants(matching: .any)["right_pane_header"]
        
        // Initially, the left pane should be active
        waitFor(element: leftHeader, label: "active")
        waitFor(element: rightHeader, label: "inactive")
        
        // Click the right pane to activate it
        rightPane.click()
        
        // Now, the right pane should be active
        waitFor(element: leftHeader, label: "inactive")
        waitFor(element: rightHeader, label: "active")
        
        // Click the left pane to activate it again
        leftPane.click()
        
        // The left pane should be active again
        waitFor(element: leftHeader, label: "active")
        waitFor(element: rightHeader, label: "inactive")
    }
    
    @MainActor
    func test_2_2_PaneSwitchingWithTabKey() throws {
        let leftHeader = app.descendants(matching: .any)["left_pane_header"]
        let rightHeader = app.descendants(matching: .any)["right_pane_header"]
        
        // Initial state: left is active
        waitFor(element: leftHeader, label: "active")
        waitFor(element: rightHeader, label: "inactive")
        
        // Press Tab to switch to the right pane
        app.typeKey(.tab, modifierFlags: [])
        
        // Check if right pane is active
        waitFor(element: leftHeader, label: "inactive")
        waitFor(element: rightHeader, label: "active")
        
        // Press Tab again to switch back to the left pane
        app.typeKey(.tab, modifierFlags: [])
        
        // Check if left pane is active again
        waitFor(element: leftHeader, label: "active")
        waitFor(element: rightHeader, label: "inactive")
    }

    // MARK: - 4. 模态操作引擎测试 (Command Mode)
    
    @MainActor
    func test_4_1_CommandMode() throws {
        let modeIndicator = app.staticTexts["mode_indicator"]
        let statusText = app.staticTexts["status_text"]
        
        // 1. Enter Command Mode
        app.typeKey(":", modifierFlags: [.shift])
        waitFor(element: modeIndicator, label: "COMMAND")
        
        // 2. Type a command
        app.typeText("foo")
        XCTAssertEqual(statusText.label, ":foo")
        
        // 3. Execute command and check for toast
        app.typeKey(.return, modifierFlags: [])
        let toast = app.staticTexts["Unknown command: foo"]
        XCTAssertTrue(toast.waitForExistence(timeout: 1))
        
        // 4. Wait for toast to disappear and mode to return to normal
        let toastDisappeared = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: toastDisappeared, object: toast)
        wait(for: [expectation], timeout: 3)
        
        waitFor(element: modeIndicator, label: "NORMAL")
        
        // 5. Test cancelling with Escape key
        app.typeKey(":", modifierFlags: [.shift])
        waitFor(element: modeIndicator, label: "COMMAND")
        app.typeText("bar")
        XCTAssertEqual(statusText.label, ":bar")
        app.typeKey(.escape, modifierFlags: [])
        
        // Check mode is back to normal and no toast appeared
        waitFor(element: modeIndicator, label: "NORMAL")
        XCTAssertFalse(app.staticTexts["Unknown command: bar"].exists)
    }
}