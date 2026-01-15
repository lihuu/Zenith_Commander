//
//  PaneViewTests.swift
//  Zenith CommanderTests
//
//  Tests for PaneView logic via PaneState and AppState
//

import XCTest

@testable import Zenith_Commander

@MainActor
final class PaneViewTests: XCTestCase {
    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    func testPaneSideProperty() {
        // Test that left and right panes have correct side properties
        XCTAssertEqual(appState.leftPane.side, .left, "Left pane should have side .left")
        XCTAssertEqual(appState.rightPane.side, .right, "Right pane should have side .right")
    }

}

