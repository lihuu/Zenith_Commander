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
        
        // Create test files and folders
        try "".write(to: testDirectory.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "".write(to: testDirectory.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: testDirectory.appendingPathComponent("folder1"), withIntermediateDirectories: true, attributes: nil)
        
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

    // MARK: - 3. 文件导航测试 (Normal Mode)
    @MainActor
    func test_3_1_FileNavigation() throws {
        let leftPane = app.descendants(matching: .any)["left_pane"]

        let file1 = leftPane.staticTexts["file_row_file1.txt"]
        XCTAssertTrue(file1.waitForExistence(timeout: 2), "file1.txt should exist")

        // Helper to find the focused element
        func findFocusedElement() -> XCUIElement? {
            let predicate = NSPredicate(format: "value CONTAINS 'focused'")
            let focusedElements = app.staticTexts.containing(predicate)
            if focusedElements.count > 0 {
                return focusedElements.firstMatch
            }
            return nil
        }

        // 1. Find initial focused element
        guard let initialFocusedElement = findFocusedElement() else {
            XCTFail("No element was focused initially")
            return
        }
        let initialLabel = initialFocusedElement.label

        // 2. Press 'j' and check focus changes
        app.typeKey("j", modifierFlags: [])
        guard let secondFocusedElement = findFocusedElement() else {
            XCTFail("No element was focused after pressing 'j'")
            return
        }
        XCTAssertNotEqual(secondFocusedElement.label, initialLabel, "Focus should have moved down")

        // 3. Press 'k' and check focus moves back
        app.typeKey("k", modifierFlags: [])
        guard let thirdFocusedElement = findFocusedElement() else {
            XCTFail("No element was focused after pressing 'k'")
            return
        }
        XCTAssertEqual(thirdFocusedElement.label, initialLabel, "Focus should have moved back up")
        
        // 4. Navigate into folder
        let folder1 = leftPane.staticTexts["file_row_folder1"]
        XCTAssertTrue(folder1.exists, "folder1 should exist")
        
        // Keep pressing 'k' until folder1 is focused
        var safety = 0
        while findFocusedElement()?.label != "folder1" && safety < 5 {
            app.typeKey("k", modifierFlags: [])
            safety += 1
        }
        guard findFocusedElement()?.label == "folder1" else {
            XCTFail("Could not navigate to folder1")
            return
        }

        app.typeKey("l", modifierFlags: [])
        
        let breadcrumb = app.buttons["folder1"]
        XCTAssertTrue(breadcrumb.waitForExistence(timeout: 2), "Breadcrumb should show 'folder1'")
        
        // 5. Navigate back with 'h'
        app.typeKey("h", modifierFlags: [])
        
        XCTAssertTrue(file1.waitForExistence(timeout: 2), "Should be back in test directory")
    }
}
