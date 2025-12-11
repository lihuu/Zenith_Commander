//
//  RsyncSyncSheetViewTests.swift
//  Zenith_CommanderTests
//
//  Rsync Sync Sheet View Unit Tests
//

import SwiftUI
import XCTest

@testable import Zenith_Commander

@MainActor
class RsyncSyncSheetViewTests: XCTestCase {

    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    override func tearDown() {
        appState = nil
        super.tearDown()
    }

    // MARK: - Sheet Presentation Tests

    func testPresentRsyncSheetWithLeftSource() {
        // Arrange
        let sourceURL = URL(fileURLWithPath: "/Users/test/source")
        let destURL = URL(fileURLWithPath: "/Users/test/dest")

        let drive = DriveInfo(
            id: "test-drive",
            name: "Test Drive",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 1_000_000,
            availableCapacity: 500_000
        )

        appState.leftPane = PaneState(side: .left, initialPath: sourceURL, drive: drive)
        appState.rightPane = PaneState(side: .right, initialPath: destURL, drive: drive)

        // Act
        appState.presentRsyncSheet(sourceIsLeft: true)

        // Assert
        XCTAssertTrue(appState.rsyncUIState.showConfigSheet)
        XCTAssertEqual(appState.rsyncUIState.config?.source, sourceURL)
        XCTAssertEqual(appState.rsyncUIState.config?.destination, destURL)
        XCTAssertEqual(appState.rsyncUIState.config?.mode, .update)
        XCTAssertTrue(appState.rsyncUIState.config?.dryRun ?? false)
    }

    func testPresentRsyncSheetWithRightSource() {
        // Arrange
        let sourceURL = URL(fileURLWithPath: "/Users/test/source")
        let destURL = URL(fileURLWithPath: "/Users/test/dest")

        let drive = DriveInfo(
            id: "test-drive",
            name: "Test Drive",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 1_000_000,
            availableCapacity: 500_000
        )

        appState.leftPane = PaneState(side: .left, initialPath: destURL, drive: drive)
        appState.rightPane = PaneState(side: .right, initialPath: sourceURL, drive: drive)

        // Act
        appState.presentRsyncSheet(sourceIsLeft: false)

        // Assert
        XCTAssertTrue(appState.rsyncUIState.showConfigSheet)
        XCTAssertEqual(appState.rsyncUIState.config?.source, sourceURL)
        XCTAssertEqual(appState.rsyncUIState.config?.destination, destURL)
    }

    func testDismissRsyncSheet() {
        // Arrange
        appState.rsyncUIState.showConfigSheet = true
        appState.rsyncUIState.config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update
        )

        // Act
        appState.dismissRsyncSheet()

        // Assert
        XCTAssertFalse(appState.rsyncUIState.showConfigSheet)
        XCTAssertNil(appState.rsyncUIState.config)
        XCTAssertNil(appState.rsyncUIState.previewResult)
        XCTAssertNil(appState.rsyncUIState.syncResult)
    }

    // MARK: - Config Update Tests

    func testUpdateRsyncConfig() {
        // Arrange
        let initialConfig = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update
        )
        appState.rsyncUIState.config = initialConfig

        var updatedConfig = initialConfig
        updatedConfig.mode = .mirror
        updatedConfig.preserveAttributes = true
        updatedConfig.deleteExtras = true

        // Act
        appState.updateRsyncConfig(updatedConfig)

        // Assert
        XCTAssertEqual(appState.rsyncUIState.config?.mode, .mirror)
        XCTAssertTrue(appState.rsyncUIState.config?.preserveAttributes ?? false)
        XCTAssertTrue(appState.rsyncUIState.config?.deleteExtras ?? false)
    }

    func testUpdateRsyncConfigWithExcludePatterns() {
        // Arrange
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/test/source"),
            destination: URL(fileURLWithPath: "/test/dest"),
            mode: .update,
            excludePatterns: []
        )
        appState.rsyncUIState.config = config

        var updatedConfig = config
        updatedConfig.excludePatterns = ["*.tmp", ".DS_Store", "node_modules"]

        // Act
        appState.updateRsyncConfig(updatedConfig)

        // Assert
        XCTAssertEqual(appState.rsyncUIState.config?.excludePatterns.count, 3)
        XCTAssertTrue(
            appState.rsyncUIState.config?.excludePatterns.contains("*.tmp")
                ?? false
        )
        XCTAssertTrue(
            appState.rsyncUIState.config?.excludePatterns.contains(".DS_Store")
                ?? false
        )
        XCTAssertTrue(
            appState.rsyncUIState.config?.excludePatterns.contains(
                "node_modules"
            ) ?? false
        )
    }

    // MARK: - Preview Result Tests

    func testSetPreviewResult() {
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

        // Act
        appState.rsyncUIState.previewResult = previewResult

        // Assert
        XCTAssertNotNil(appState.rsyncUIState.previewResult)
        XCTAssertEqual(appState.rsyncUIState.previewResult?.copied.count, 2)
        XCTAssertEqual(appState.rsyncUIState.previewResult?.updated.count, 0)
    }

    func testClearPreviewResult() {
        // Arrange
        let items = [RsyncItem(relativePath: "test.txt", action: .copy)]
        let previewResult = RsyncPreviewResult(
            copied: items,
            updated: [],
            deleted: [],
            skipped: []
        )
        appState.rsyncUIState.previewResult = previewResult

        // Act
        appState.rsyncUIState.previewResult = nil

        // Assert
        XCTAssertNil(appState.rsyncUIState.previewResult)
    }

    // MARK: - Sync Result Tests

    func testSetSyncResultSuccess() {
        // Arrange
        let summary = (copy: 5, update: 2, delete: 0, skip: 1)
        let syncResult = RsyncRunResult(
            success: true,
            errors: [],
            summary: summary
        )

        // Act
        appState.rsyncUIState.syncResult = syncResult

        // Assert
        XCTAssertNotNil(appState.rsyncUIState.syncResult)
        XCTAssertTrue(appState.rsyncUIState.syncResult?.success ?? false)
        XCTAssertEqual(appState.rsyncUIState.syncResult?.summary.copy, 5)
        XCTAssertTrue(appState.rsyncUIState.syncResult?.errors.isEmpty ?? false)
    }

    func testSetSyncResultWithErrors() {
        // Arrange
        let summary = (copy: 0, update: 0, delete: 0, skip: 0)
        let errors = ["Permission denied", "File not found"]
        let syncResult = RsyncRunResult(
            success: false,
            errors: errors,
            summary: summary
        )

        // Act
        appState.rsyncUIState.syncResult = syncResult

        // Assert
        XCTAssertFalse(appState.rsyncUIState.syncResult?.success ?? true)
        XCTAssertEqual(appState.rsyncUIState.syncResult?.errors.count, 2)
        XCTAssertTrue(
            appState.rsyncUIState.syncResult?.errors.contains(
                "Permission denied"
            ) ?? false
        )
    }

    // MARK: - UI State Transitions Tests

    @MainActor
    func testProgressViewStateTransitions() {
        // Arrange
        XCTAssertFalse(appState.rsyncUIState.isRunningSync)

        // Act & Assert - Starting sync
        appState.rsyncUIState.isRunningSync = true
        XCTAssertTrue(appState.rsyncUIState.isRunningSync)

        // Act & Assert - Setting progress
        let progress = RsyncProgress(
            message: "Syncing...", completed: 10,
            total: 22
        )
        appState.rsyncUIState.syncProgress = progress
        let percentage = appState.rsyncUIState.syncProgress?.percentage
        XCTAssertEqual(percentage, 45.0)

        // Act & Assert - Completing sync
        appState.rsyncUIState.isRunningSync = false
        XCTAssertFalse(appState.rsyncUIState.isRunningSync)
    }

    func testErrorMessageFlow() {
        // Arrange
        XCTAssertNil(appState.rsyncUIState.error)

        // Act - Set error
        appState.rsyncUIState.error = "Source directory not found"

        // Assert
        XCTAssertNotNil(appState.rsyncUIState.error)
        XCTAssertEqual(
            appState.rsyncUIState.error,
            "Source directory not found"
        )

        // Act - Clear error
        appState.rsyncUIState.error = nil

        // Assert
        XCTAssertNil(appState.rsyncUIState.error)
    }

    // MARK: - Configuration Validation Tests

    func testConfigValidationWithValidPaths() {
        // Arrange
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/Users/test/source"),
            destination: URL(fileURLWithPath: "/Users/test/destination"),
            mode: .update
        )

        // Act & Assert
        XCTAssertTrue(config.isValid())
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
            var config = RsyncSyncConfig(
                source: URL(fileURLWithPath: "/test/source"),
                destination: URL(fileURLWithPath: "/test/dest"),
                mode: mode
            )

            // Act
            let selectedMode = config.mode

            // Assert
            XCTAssertEqual(selectedMode, mode)
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
        XCTAssertTrue(flags.contains("-t"))
        XCTAssertTrue(flags.contains("--dry-run"))
        XCTAssertTrue(flags.contains("--exclude=*.tmp"))
    }
}
