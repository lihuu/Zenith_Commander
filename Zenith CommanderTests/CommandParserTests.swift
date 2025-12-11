//
//  CommandParserTests.swift
//  Zenith CommanderTests
//
//  Unit tests for CommandParser
//

import XCTest
@testable import Zenith_Commander

final class CommandParserTests: XCTestCase {
    
    // MARK: - :rsync Command Tests (T062)
    
    func testParseRsync_NoArguments() {
        // Given
        let input = "rsync"
        
        // When
        let command = CommandParser.parse(input)
        
        // Then
        XCTAssertEqual(command.type, .rsync)
        XCTAssertEqual(command.argCount, 0)
    }
    
    func testParseRsync_UpdateMode() {
        // Given
        let input = "rsync update"
        
        // When
        let command = CommandParser.parse(input)
        
        // Then
        XCTAssertEqual(command.type, .rsync)
        XCTAssertEqual(command.firstArg, "update")
    }
    
    func testParseRsync_MirrorMode() {
        // Given
        let input = "rsync mirror"
        
        // When
        let command = CommandParser.parse(input)
        
        // Then
        XCTAssertEqual(command.type, .rsync)
        XCTAssertEqual(command.firstArg, "mirror")
    }
    
    func testParseRsync_CopyAllMode() {
        // Given
        let input = "rsync copyAll"
        
        // When
        let command = CommandParser.parse(input)
        
        // Then
        XCTAssertEqual(command.type, .rsync)
        XCTAssertEqual(command.firstArg, "copyAll")
    }
    
    func testParseRsync_CustomMode() {
        // Given
        let input = "rsync custom"
        
        // When
        let command = CommandParser.parse(input)
        
        // Then
        XCTAssertEqual(command.type, .rsync)
        XCTAssertEqual(command.firstArg, "custom")
    }
    
    func testValidateRsync_NoArguments() {
        // Given
        let command = CommandParser.parse("rsync")
        
        // When
        let (valid, mode, error) = CommandParser.validateRsync(command)
        
        // Then
        XCTAssertTrue(valid)
        XCTAssertNil(mode) // No mode specified, will use default
        XCTAssertNil(error)
    }
    
    func testValidateRsync_ValidUpdateMode() {
        // Given
        let command = CommandParser.parse("rsync update")
        
        // When
        let (valid, mode, error) = CommandParser.validateRsync(command)
        
        // Then
        XCTAssertTrue(valid)
        XCTAssertEqual(mode, "update")
        XCTAssertNil(error)
    }
    
    func testValidateRsync_ValidMirrorMode() {
        // Given
        let command = CommandParser.parse("rsync mirror")
        
        // When
        let (valid, mode, error) = CommandParser.validateRsync(command)
        
        // Then
        XCTAssertTrue(valid)
        XCTAssertEqual(mode, "mirror")
        XCTAssertNil(error)
    }
    
    func testValidateRsync_ValidCopyAllMode() {
        // Given
        let command = CommandParser.parse("rsync copyAll")
        
        // When
        let (valid, mode, error) = CommandParser.validateRsync(command)
        
        // Then
        XCTAssertTrue(valid)
        XCTAssertEqual(mode, "copyall") // Lowercase normalized
        XCTAssertNil(error)
    }
    
    func testValidateRsync_ValidCustomMode() {
        // Given
        let command = CommandParser.parse("rsync custom")
        
        // When
        let (valid, mode, error) = CommandParser.validateRsync(command)
        
        // Then
        XCTAssertTrue(valid)
        XCTAssertEqual(mode, "custom")
        XCTAssertNil(error)
    }
    
    func testValidateRsync_InvalidMode() {
        // Given
        let command = CommandParser.parse("rsync invalid_mode")
        
        // When
        let (valid, mode, error) = CommandParser.validateRsync(command)
        
        // Then
        XCTAssertFalse(valid)
        XCTAssertNil(mode)
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("Invalid rsync mode") ?? false)
    }
    
    func testValidateRsync_CaseInsensitive() {
        // Given
        let testCases = [
            "rsync UPDATE",
            "rsync Mirror",
            "rsync COPYALL",
            "rsync CuStOm"
        ]
        
        // When/Then
        for testCase in testCases {
            let command = CommandParser.parse(testCase)
            let (valid, _, error) = CommandParser.validateRsync(command)
            XCTAssertTrue(valid, "Failed for input: \(testCase)")
            XCTAssertNil(error, "Unexpected error for input: \(testCase)")
        }
    }
    
    func testParseRsync_WithQuotes() {
        // Given
        let input = "rsync \"mirror\""
        
        // When
        let command = CommandParser.parse(input)
        
        // Then
        XCTAssertEqual(command.type, .rsync)
        XCTAssertEqual(command.firstArg, "mirror")
    }
    
    func testCommandType_FromString() {
        // Given/When/Then
        XCTAssertEqual(CommandType.from("rsync"), .rsync)
        XCTAssertEqual(CommandType.from("RSYNC"), .rsync)
        XCTAssertEqual(CommandType.from("RsYnC"), .rsync)
    }
}
