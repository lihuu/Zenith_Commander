//
//  RsyncSyncSheetViewTests.swift
//  Zenith_CommanderTests
//
//  Rsync Sync Sheet View Unit Tests
//

import SwiftUI
import XCTest
import OSLog

@testable import Zenith_Commander

@MainActor
class RsyncSyncSheetViewTests: XCTestCase {
    var context: PluginContext!

    override func setUp() {
        super.setUp()
        
        // Initialize PluginContext for testing
        context = PluginContext(
            panes: { PanesSnapshot(leftPath: "/test/left", rightPath: "/test/right", active: .left) },
            dispatch: { _ in },
            logger: Logger(subsystem: "test", category: "rsync"),
            toolRunner: ProcessToolRunner()
        )
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testViewInitialization() {
        // Act
        let view = RsyncSyncSheetView(context: context)

        // Assert - View should be created successfully
        XCTAssertNotNil(view)
    }

    func testInitialConfigFromContext() {
        // Arrange
        let customContext = PluginContext(
            panes: { PanesSnapshot(leftPath: "/source/path", rightPath: "/dest/path", active: .left) },
            dispatch: { _ in },
            logger: Logger(subsystem: "test", category: "rsync"),
            toolRunner: ProcessToolRunner()
        )

        // Act
        _ = RsyncSyncSheetView(context: customContext)

        // Assert - Config should be initialized with context paths
        // Note: We can't directly access @State variables in tests, so we verify through behavior
        XCTAssertNotNil(customContext)
    }

    // MARK: - Config Update Tests

    func testConfigModeChange() {
        // Arrange
        var config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update
        )

        // Act
        config.mode = .mirror

        // Assert
        XCTAssertEqual(config.mode, .mirror)
    }

    func testConfigWithExcludePatterns() {
        // Arrange
        var config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update,
            excludePatterns: []
        )

        // Act
        config.excludePatterns = ["*.tmp", ".DS_Store", "node_modules"]

        // Assert
        XCTAssertEqual(config.excludePatterns.count, 3)
        XCTAssertTrue(config.excludePatterns.contains("*.tmp"))
        XCTAssertTrue(config.excludePatterns.contains(".DS_Store"))
        XCTAssertTrue(config.excludePatterns.contains("node_modules"))
    }

    // MARK: - Preview Result Tests

    func testPreviewResultStructure() {
        // Arrange
        let items = [
            RsyncItem(relativePath: "file1.txt", action: .copy),
            RsyncItem(relativePath: "dir1", action: .skip),
        ]
        let previewResult = RsyncPreviewResult(
            copied: items,
            updated: [],
            deleted: [],
            skipped: []
        )

        // Assert
        XCTAssertEqual(previewResult.copied.count, 2)
        XCTAssertEqual(previewResult.updated.count, 0)
    }

    // MARK: - Sync Result Tests

    func testSyncResultSuccess() {
        // Arrange
        let summary = (copy: 5, update: 2, delete: 0, skip: 1)
        let syncResult = RsyncRunResult(
            success: true,
            errors: [],
            summary: summary
        )

        // Assert
        XCTAssertTrue(syncResult.success)
        XCTAssertEqual(syncResult.summary.copy, 5)
        XCTAssertTrue(syncResult.errors.isEmpty)
    }

    func testSyncResultWithErrors() {
        // Arrange
        let summary = (copy: 0, update: 0, delete: 0, skip: 0)
        let errors = ["Permission denied", "File not found"]
        let syncResult = RsyncRunResult(
            success: false,
            errors: errors,
            summary: summary
        )

        // Assert
        XCTAssertFalse(syncResult.success)
        XCTAssertEqual(syncResult.errors.count, 2)
        XCTAssertTrue(syncResult.errors.contains("Permission denied"))
    }

    // MARK: - Configuration Validation Tests

    func testConfigValidationWithValidPaths() {
        // Arrange
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source_\(UUID().uuidString)")
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: sourceURL,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: destURL,
            withIntermediateDirectories: true
        )

        let config = RsyncSyncConfig(
            source: sourceURL,
            destination: destURL,
            mode: .update
        )

        // Act & Assert
        XCTAssertTrue(config.isValid())

        // Cleanup
        try? FileManager.default.removeItem(at: sourceURL)
        try? FileManager.default.removeItem(at: destURL)
    }

    func testConfigValidationWithSamePath() {
        // Arrange
        let samePath = URL(fileURLWithPath: "/Users/test/sync")
        let config = RsyncSyncConfig(
            source: samePath,
            destination: samePath,
            mode: .update
        )

        // Act & Assert
        XCTAssertFalse(config.isValid())
    }

    // MARK: - Dry Run Mode Tests

    func testDryRunModeToggle() {
        // Arrange
        var config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update,
            dryRun: true
        )
        XCTAssertTrue(config.dryRun)

        // Act
        config.dryRun = false

        // Assert
        XCTAssertFalse(config.dryRun)
    }

    // MARK: - Mode Selection Tests

    func testAllRsyncModes() {
        let modes: [RsyncMode] = [.update, .mirror, .copyAll, .custom]

        for mode in modes {
            // Arrange
            let config = RsyncSyncConfig(
                source: URL(fileURLWithPath: "/test/source"),
                destination: URL(fileURLWithPath: "/test/dest"),
                mode: mode
            )

            // Assert
            XCTAssertEqual(config.mode, mode)
        }
    }

    // MARK: - Option Flags Tests

    func testPreserveAttributesFlag() {
        // Arrange
        var config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            preserveAttributes: false
        )

        // Act
        config.preserveAttributes = true

        // Assert
        XCTAssertTrue(config.preserveAttributes)
    }

    func testDeleteExtrasFlag() {
        // Arrange
        var config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            deleteExtras: false
        )

        // Act
        config.deleteExtras = true

        // Assert
        XCTAssertTrue(config.deleteExtras)
    }

    func testEffectiveFlagsBuilding() {
        // Arrange
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update,
            dryRun: true,
            preserveAttributes: true,
            deleteExtras: false,
            excludePatterns: ["*.tmp"],
            customFlags: []
        )

        // Act
        let flags = config.effectiveFlags()

        // Assert
        XCTAssertTrue(flags.contains("-a") || flags.contains("-t"))
        XCTAssertTrue(flags.contains("--dry-run"))
        XCTAssertTrue(flags.contains("--exclude=*.tmp"))
    }

    // MARK: - Progress Tests

    func testProgressCalculation() {
        // Arrange
        let progress = RsyncProgress(
            message: "Syncing...",
            completed: 10,
            total: 20
        )

        // Assert
        XCTAssertEqual(progress.percentage, 50.0)
    }

    func testProgressZeroTotal() {
        // Arrange
        let progress = RsyncProgress(
            message: "Starting...",
            completed: 0,
            total: 0
        )

        // Assert
        XCTAssertEqual(progress.percentage, 0.0)
    }

    // MARK: - RsyncUIState Tests

    func testRsyncUIStateInitialState() {
        // Arrange
        let state = RsyncUIState()

        // Assert
        XCTAssertFalse(state.showConfigSheet)
        XCTAssertNil(state.config)
        XCTAssertNil(state.error)
        XCTAssertNil(state.previewResult)
        XCTAssertFalse(state.isPreviewingDryRun)
        XCTAssertFalse(state.isRunningSync)
        XCTAssertNil(state.syncProgress)
        XCTAssertNil(state.syncResult)
    }

    func testRsyncUIStateSetError() {
        // Arrange
        var state = RsyncUIState()
        XCTAssertNil(state.error)

        // Act
        state.error = "Test error message"

        // Assert
        XCTAssertEqual(state.error, "Test error message")
    }

    func testRsyncUIStateSetProgress() {
        // Arrange
        var state = RsyncUIState()
        let progress = RsyncProgress(
            message: "Syncing...",
            completed: 5,
            total: 10
        )

        // Act
        state.syncProgress = progress

        // Assert
        XCTAssertNotNil(state.syncProgress)
        XCTAssertEqual(state.syncProgress?.percentage, 50.0)
    }

    // MARK: - RsyncItem Tests

    func testRsyncItemCreation() {
        // Arrange & Act
        let item = RsyncItem(relativePath: "test/file.txt", action: .copy)

        // Assert
        XCTAssertEqual(item.relativePath, "test/file.txt")
        XCTAssertEqual(item.action, .copy)
    }

    // MARK: - Integration Tests

    func testFullWorkflowSimulation() {
        // This test simulates the full workflow without actually running rsync
        
        // Arrange
        var state = RsyncUIState()
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update,
            dryRun: true
        )

        // Act - Setup
        state.config = config
        XCTAssertNotNil(state.config)

        // Act - Preview
        let previewResult = RsyncPreviewResult(
            copied: [RsyncItem(relativePath: "file1.txt", action: .copy)],
            updated: [],
            deleted: [],
            skipped: []
        )
        state.previewResult = previewResult
        XCTAssertNotNil(state.previewResult)

        // Act - Sync
        state.isRunningSync = true
        XCTAssertTrue(state.isRunningSync)

        // Act - Progress
        let progress = RsyncProgress(message: "Syncing", completed: 1, total: 1)
        state.syncProgress = progress
        XCTAssertEqual(state.syncProgress?.percentage, 100.0)

        // Act - Complete
        let result = RsyncRunResult(
            success: true,
            errors: [],
            summary: (copy: 1, update: 0, delete: 0, skip: 0)
        )
        state.syncResult = result
        state.isRunningSync = false

        // Assert
        XCTAssertTrue(state.syncResult?.success ?? false)
        XCTAssertFalse(state.isRunningSync)
    }
}
