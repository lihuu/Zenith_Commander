//
//  PaneViewTests.swift
//  Zenith CommanderTests
//
//  Tests for PaneView logic via PaneState and AppState
//

import XCTest
@testable import Zenith_Commander

final class PaneViewTests: XCTestCase {
    
    var appState: AppState!
    
    @MainActor
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    @MainActor
    func testPaneSideProperty() {
        // Test that left and right panes have correct side properties
        XCTAssertEqual(appState.leftPane.side, .left, "Left pane should have side .left")
        XCTAssertEqual(appState.rightPane.side, .right, "Right pane should have side .right")
    }
    
    @MainActor
    func testPresentRsyncSheetFromLeftPane() {
        // Simulate invoking presentRsyncSheet from left pane
        let pane = appState.leftPane
        
        // This effectively tests the logic: appState.presentRsyncSheet(sourceIsLeft: pane.side == .left)
        // which was the fix applied to PaneView.swift
        
        let sourceIsLeft = (pane.side == .left)
        XCTAssertTrue(sourceIsLeft, "Left pane side comparison should be true")
        
        appState.presentRsyncSheet(sourceIsLeft: sourceIsLeft)
        
        XCTAssertTrue(appState.rsyncUIState.showConfigSheet, "Rsync sheet should be shown")
        
        // Verify config is set up correctly for left -> right
        XCTAssertEqual(appState.rsyncUIState.config?.source, appState.leftPane.activeTab.currentPath)
        XCTAssertEqual(appState.rsyncUIState.config?.destination, appState.rightPane.activeTab.currentPath)
    }
    
    @MainActor
    func testPresentRsyncSheetFromRightPane() {
        // Simulate invoking presentRsyncSheet from right pane
        let pane = appState.rightPane
        
        // This effectively tests the logic: appState.presentRsyncSheet(sourceIsLeft: pane.side == .left)
        
        let sourceIsLeft = (pane.side == .left)
        XCTAssertFalse(sourceIsLeft, "Right pane side comparison should be false")
        
        appState.presentRsyncSheet(sourceIsLeft: sourceIsLeft)
        
        XCTAssertTrue(appState.rsyncUIState.showConfigSheet, "Rsync sheet should be shown")
        
        // Verify config is set up correctly for right -> left
        XCTAssertEqual(appState.rsyncUIState.config?.source, appState.rightPane.activeTab.currentPath)
        XCTAssertEqual(appState.rsyncUIState.config?.destination, appState.leftPane.activeTab.currentPath)
    }
}
