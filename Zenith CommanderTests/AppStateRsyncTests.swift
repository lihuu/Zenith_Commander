//
//  AppStateRsyncTests.swift
//  Zenith CommanderTests
//
//  Unit tests for AppState rsync flow
//

import XCTest
@testable import Zenith_Commander

final class AppStateRsyncTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
        
        // Setup test directories for left and right panes
        let tempDir = NSTemporaryDirectory()
        let leftPath = (tempDir as NSString).appendingPathComponent("test_left_\(UUID().uuidString)")
        let rightPath = (tempDir as NSString).appendingPathComponent("test_right_\(UUID().uuidString)")
        
        try? FileManager.default.createDirectory(atPath: leftPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: rightPath, withIntermediateDirectories: true)
        
        appState.leftPane.path = leftPath
        appState.rightPane.path = rightPath
    }
    
    override func tearDown() {
        // Cleanup test directories
        if let leftPath = appState?.leftPane.path {
            try? FileManager.default.removeItem(atPath: leftPath)
        }
        if let rightPath = appState?.rightPane.path {
            try? FileManager.default.removeItem(atPath: rightPath)
        }
        appState = nil
        super.tearDown()
    }
    
    // MARK: - presentRsyncSheet Tests (T061)
    
    func testPresentRsyncSheet_LeftAsSource() {
        // When
        appState.presentRsyncSheet(sourceIsLeft: true)
        
        // Then
        XCTAssertTrue(appState.rsyncUIState.isPresented)
        XCTAssertEqual(appState.rsyncUIState.config.source.path, appState.leftPane.path)
        XCTAssertEqual(appState.rsyncUIState.config.destination.path, appState.rightPane.path)
        XCTAssertEqual(appState.rsyncUIState.config.mode, .update) // Default mode
    }
    
    func testPresentRsyncSheet_RightAsSource() {
        // When
        appState.presentRsyncSheet(sourceIsLeft: false)
        
        // Then
        XCTAssertTrue(appState.rsyncUIState.isPresented)
        XCTAssertEqual(appState.rsyncUIState.config.source.path, appState.rightPane.path)
        XCTAssertEqual(appState.rsyncUIState.config.destination.path, appState.leftPane.path)
    }
    
    func testDismissRsyncSheet() {
        // Given
        appState.presentRsyncSheet(sourceIsLeft: true)
        XCTAssertTrue(appState.rsyncUIState.isPresented)
        
        // When
        appState.dismissRsyncSheet()
        
        // Then
        XCTAssertFalse(appState.rsyncUIState.isPresented)
        XCTAssertEqual(appState.rsyncUIState.currentView, .config)
    }
    
    func testUpdateConfig() {
        // Given
        appState.presentRsyncSheet(sourceIsLeft: true)
        var newConfig = appState.rsyncUIState.config
        newConfig.mode = .mirror
        newConfig.preserveAttributes = true
        newConfig.deleteExtras = true
        
        // When
        appState.updateConfig(newConfig)
        
        // Then
        XCTAssertEqual(appState.rsyncUIState.config.mode, .mirror)
        XCTAssertTrue(appState.rsyncUIState.config.preserveAttributes)
        XCTAssertTrue(appState.rsyncUIState.config.deleteExtras)
    }
    
    func testRsyncUIState_InitialState() {
        // Given/When
        let uiState = RsyncUIState()
        
        // Then
        XCTAssertFalse(uiState.isPresented)
        XCTAssertEqual(uiState.currentView, .config)
        XCTAssertNil(uiState.previewResult)
        XCTAssertNil(uiState.runResult)
        XCTAssertFalse(uiState.isLoading)
        XCTAssertNil(uiState.error)
    }
    
    func testRsyncUIState_ViewTransitions() {
        // Given
        appState.presentRsyncSheet(sourceIsLeft: true)
        
        // When transitioning to preview
        appState.rsyncUIState.currentView = .preview
        
        // Then
        XCTAssertEqual(appState.rsyncUIState.currentView, .preview)
        
        // When transitioning to running
        appState.rsyncUIState.currentView = .running
        
        // Then
        XCTAssertEqual(appState.rsyncUIState.currentView, .running)
        
        // When transitioning to complete
        appState.rsyncUIState.currentView = .complete
        
        // Then
        XCTAssertEqual(appState.rsyncUIState.currentView, .complete)
    }
    
    func testRsyncConfig_Validation() {
        // Given
        appState.presentRsyncSheet(sourceIsLeft: true)
        let config = appState.rsyncUIState.config
        
        // When/Then
        XCTAssertTrue(config.isValid())
        
        // Test invalid config (same source and destination)
        var invalidConfig = config
        invalidConfig.destination = config.source
        XCTAssertFalse(invalidConfig.isValid())
    }
    
    func testRsyncConfig_EffectiveFlags() {
        // Given
        appState.presentRsyncSheet(sourceIsLeft: true)
        var config = appState.rsyncUIState.config
        
        // When: Update mode
        config.mode = .update
        let updateFlags = config.effectiveFlags()
        
        // Then
        XCTAssertTrue(updateFlags.contains("-u"))
        
        // When: Mirror mode with deleteExtras
        config.mode = .mirror
        config.deleteExtras = true
        let mirrorFlags = config.effectiveFlags()
        
        // Then
        XCTAssertTrue(mirrorFlags.contains("--delete"))
        
        // When: Preserve attributes
        config.preserveAttributes = true
        let preserveFlags = config.effectiveFlags()
        
        // Then
        XCTAssertTrue(preserveFlags.contains("-a") || preserveFlags.contains("-rlptgoD"))
        
        // When: Custom mode
        config.mode = .custom
        config.customFlags = "-z --compress"
        let customFlags = config.effectiveFlags()
        
        // Then
        XCTAssertTrue(customFlags.contains("-z"))
        XCTAssertTrue(customFlags.contains("--compress"))
    }
}
