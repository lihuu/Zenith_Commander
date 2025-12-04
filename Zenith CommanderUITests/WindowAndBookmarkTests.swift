
import XCTest

final class WindowAndBookmarkTests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Handle permission dialogs
        addUIInterruptionMonitor(withDescription: "Permission Alert") { (alert) -> Bool in
            let button = alert.buttons["Allow"]
            if button.exists {
                button.tap()
                return true
            }
            return false
        }
    }
    
    @MainActor
    func testBookmarkBarToggle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-testDirectory", "/tmp"]
        app.launch()
        app.activate()
        
        let window = app.windows.firstMatch
        if window.waitForExistence(timeout: 5) {
            window.click()
        }
        
        let bookmarkBar = app.otherElements["BookmarkBar"]
        
        // Initial state: Visible
        XCTAssertTrue(bookmarkBar.exists, "Bookmark bar should be visible initially")
        
        // Toggle off
        app.typeText("b")
        
        // Wait for animation/update
        let hiddenPredicate = NSPredicate(format: "exists == false")
        expectation(for: hiddenPredicate, evaluatedWith: bookmarkBar, handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
        
        XCTAssertFalse(bookmarkBar.exists, "Bookmark bar should be hidden after pressing 'b'")
        
        // Toggle on
        app.typeText("b")
        
        let visiblePredicate = NSPredicate(format: "exists == true")
        expectation(for: visiblePredicate, evaluatedWith: bookmarkBar, handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
        
        XCTAssertTrue(bookmarkBar.exists, "Bookmark bar should be visible again after pressing 'b'")
    }
    
    @MainActor
    func testWindowMaximizeRestore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-testDirectory", "/tmp"]
        app.launch()
        app.activate()
        
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should exist")
        
        let initialFrame = window.frame
        
        let bookmarkBar = app.otherElements["BookmarkBar"]
        XCTAssertTrue(bookmarkBar.exists, "Bookmark bar must be visible for this test")
        
        // Double click on the bookmark bar to maximize
        bookmarkBar.doubleClick()
        
        // Wait for animation
        Thread.sleep(forTimeInterval: 1.0)
        
        let maximizedFrame = window.frame
        
        // Check if size changed
        XCTAssertNotEqual(initialFrame, maximizedFrame, "Window frame should change after double click")
        
        // Double click again to restore
        bookmarkBar.doubleClick()
        
        Thread.sleep(forTimeInterval: 1.0)
        
        let restoredFrame = window.frame
        
        // It should be close to initial frame
        XCTAssertEqual(restoredFrame.width, initialFrame.width, accuracy: 1.0)
        XCTAssertEqual(restoredFrame.height, initialFrame.height, accuracy: 1.0)
    }
}
