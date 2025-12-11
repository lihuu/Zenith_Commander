//
//  RsyncServiceTests.swift
//  Zenith CommanderTests
//
//  Unit tests for RsyncService
//

import XCTest
@testable import Zenith_Commander

final class RsyncServiceTests: XCTestCase {
    
    var service: RsyncService!
    
    // Helper to create a dummy DriveInfo for PaneState initialization
    func createTestDrive() -> DriveInfo {
        return DriveInfo(
            id: UUID().uuidString,
            name: "Test Drive",
            path: URL(fileURLWithPath: "/"),
            type: .system,
            totalCapacity: 0,
            availableCapacity: 0
        )
    }
    
    @MainActor
    override func setUp() {
        super.setUp()
        service = RsyncService.shared
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - buildCommand Tests (T058)
    
    func testBuildCommand_UpdateMode() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/source"),
            destination: URL(fileURLWithPath: "/dest"),
            mode: .update,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When
        let command = service.buildCommand(config: config)
        
        // Then
        XCTAssertTrue(command.contains("/usr/bin/rsync"))
        XCTAssertTrue(command.contains("-itemize-changes"))
        XCTAssertTrue(command.contains("-u"))
        XCTAssertTrue(command.contains("/source/"))
        XCTAssertTrue(command.contains("/dest"))
        XCTAssertFalse(command.contains("--delete"))
    }
    
    func testBuildCommand_MirrorMode() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/source"),
            destination: URL(fileURLWithPath: "/dest"),
            mode: .mirror,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: true,
            excludePatterns: [],
            customFlags: []
        )
        
        // When
        let command = service.buildCommand(config: config)
        
        // Then
        XCTAssertTrue(command.contains("--delete"))
    }
    
    func testBuildCommand_PreserveAttributes() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/source"),
            destination: URL(fileURLWithPath: "/dest"),
            mode: .update,
            dryRun: false,
            preserveAttributes: true,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When
        let command = service.buildCommand(config: config)
        
        // Then
        XCTAssertTrue(command.contains("-a") || command.contains("-rlptgoD"))
    }
    
    func testBuildCommand_ExcludePatterns() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/source"),
            destination: URL(fileURLWithPath: "/dest"),
            mode: .update,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: ["*.log", "*.tmp"],
            customFlags: []
        )
        
        // When
        let command = service.buildCommand(config: config)
        
        // Then
        let commandString = command.joined(separator: " ")
        XCTAssertTrue(commandString.contains("--exclude=*.log"))
        XCTAssertTrue(commandString.contains("--exclude=*.tmp"))
    }
    
    func testBuildCommand_CustomMode() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/source"),
            destination: URL(fileURLWithPath: "/dest"),
            mode: .custom,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: ["-z", "--compress"]
        )
        
        // When
        let command = service.buildCommand(config: config)
        
        // Then
        XCTAssertTrue(command.contains("-z"))
        XCTAssertTrue(command.contains("--compress"))
    }
    
    func testBuildCommand_DryRun() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/source"),
            destination: URL(fileURLWithPath: "/dest"),
            mode: .update,
            dryRun: true,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When
        let command = service.buildCommand(config: config)
        
        // Then
        XCTAssertTrue(command.contains("--dry-run") || command.contains("-n"))
    }
    
    // MARK: - parseDryRunOutput Tests (T059)
    
    func testParseDryRunOutput_EmptyOutput() {
        // Given
        let output = ""
        
        // When
        let result = service.parseDryRunOutput(output)
        
        // Then
        XCTAssertEqual(result.copied.count, 0)
        XCTAssertEqual(result.updated.count, 0)
        XCTAssertEqual(result.deleted.count, 0)
        XCTAssertEqual(result.skipped.count, 0)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testParseDryRunOutput_NewFiles() {
        // Given
        let output = """
        >f+++++++++ file1.txt
        >f+++++++++ file2.txt
        """
        
        // When
        let result = service.parseDryRunOutput(output)
        
        // Then
        XCTAssertEqual(result.copied.count, 2)
        XCTAssertEqual(result.updated.count, 0)
        XCTAssertEqual(result.deleted.count, 0)
        XCTAssertTrue(result.copied.contains { $0.relativePath == "file1.txt" })
        XCTAssertTrue(result.copied.contains { $0.relativePath == "file2.txt" })
    }
    
    func testParseDryRunOutput_UpdatedFiles() {
        // Given
        let output = """
        .f..t...... file1.txt
        .f.s....... file2.txt
        """
        
        // When
        let result = service.parseDryRunOutput(output)
        
        // Then
        XCTAssertEqual(result.updated.count, 2)
        XCTAssertEqual(result.copied.count, 0)
        XCTAssertEqual(result.deleted.count, 0)
    }
    
    func testParseDryRunOutput_DeletedFiles() {
        // Given
        let output = """
        *deleting   file1.txt
        *deleting   file2.txt
        """
        
        // When
        let result = service.parseDryRunOutput(output)
        
        // Then
        XCTAssertEqual(result.deleted.count, 2)
        XCTAssertEqual(result.copied.count, 0)
        XCTAssertEqual(result.updated.count, 0)
        XCTAssertTrue(result.deleted.contains { $0.relativePath == "file1.txt" })
    }
    
    func testParseDryRunOutput_MixedActions() {
        // Given
        let output = """
        >f+++++++++ new_file.txt
        .f..t...... updated_file.txt
        *deleting   deleted_file.txt
        .d........ skipped_dir/
        """
        
        // When
        let result = service.parseDryRunOutput(output)
        
        // Then
        XCTAssertEqual(result.copied.count, 1)
        XCTAssertEqual(result.updated.count, 1)
        XCTAssertEqual(result.deleted.count, 1)
        XCTAssertGreaterThanOrEqual(result.skipped.count, 1)
        XCTAssertEqual(result.totalItems, result.copied.count + result.updated.count + result.deleted.count + result.skipped.count)
    }
    
    // MARK: - validatePaths Tests (T060 partial)
    
    func testValidatePaths_InvalidSource() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: "/nonexistent/source"),
            destination: URL(fileURLWithPath: NSTemporaryDirectory()),
            mode: .update,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When/Then
        XCTAssertThrowsError(try service.validatePaths(config: config)) { error in
            XCTAssertTrue(error is RsyncError)
            if case .sourceNotFound = error as? RsyncError {
                // Expected error type
            } else {
                XCTFail("Expected sourceNotFound error")
            }
        }
    }
    
    func testValidatePaths_InvalidDestination() {
        // Given
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: NSTemporaryDirectory()),
            destination: URL(fileURLWithPath: "/nonexistent/dest"),
            mode: .update,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When/Then
        XCTAssertThrowsError(try service.validatePaths(config: config)) { error in
            XCTAssertTrue(error is RsyncError)
            if case .destinationNotFound = error as? RsyncError {
                // Expected error type
            } else {
                XCTFail("Expected destinationNotFound error")
            }
        }
    }
    
    func testValidatePaths_SameSourceAndDestination() {
        // Given
        let tempDir = NSTemporaryDirectory()
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: tempDir),
            destination: URL(fileURLWithPath: tempDir),
            mode: .update,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When/Then
        XCTAssertThrowsError(try service.validatePaths(config: config)) { error in
            XCTAssertTrue(error is RsyncError)
            if case .sameSourceAndDestination = error as? RsyncError {
                // Expected error type
            } else {
                XCTFail("Expected sameSourceAndDestination error")
            }
        }
    }
    
    func testValidatePaths_ValidPaths() {
        // Given
        let tempDir = NSTemporaryDirectory()
        let sourceDir = (tempDir as NSString).appendingPathComponent("test_source_\(UUID().uuidString)")
        let destDir = (tempDir as NSString).appendingPathComponent("test_dest_\(UUID().uuidString)")
        
        try? FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        
        let config = RsyncSyncConfig(
            source: URL(fileURLWithPath: sourceDir),
            destination: URL(fileURLWithPath: destDir),
            mode: .update,
            dryRun: false,
            preserveAttributes: false,
            deleteExtras: false,
            excludePatterns: [],
            customFlags: []
        )
        
        // When/Then
        XCTAssertNoThrow(try service.validatePaths(config: config))
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: sourceDir)
        try? FileManager.default.removeItem(atPath: destDir)
    }
}
