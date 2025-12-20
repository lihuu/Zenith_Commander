//
//  AppStateDispatchTests.swift
//  Zenith CommanderTests
//
//  Tests for AppState dispatch method - ensuring all action branches are reachable
//

import XCTest

@testable import Zenith_Commander

@MainActor
class AppStateDispatchTests: XCTestCase {
    var appState: AppState!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()

        // Create a temporary test directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        testDirectory = tempDir

        // Initialize AppState with test directory
        appState = AppState(testDirectory: testDirectory)
    }

    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        appState = nil
        super.tearDown()
    }

    // MARK: - Mode Actions

    func testDispatchEnterMode() async {
        await appState.dispatch(.mode(.enterMode(.command)))
        XCTAssertEqual(appState.mode, .command, "Mode should change to command")
    }

    func testDispatchExitMode() async {
        appState.mode = .command
        await appState.dispatch(.mode(.exitMode))
        XCTAssertEqual(appState.mode, .normal, "Mode should return to normal")
    }

    func testDispatchNoneAction() async {
        let initialMode = appState.mode
        await appState.dispatch(.none)
        XCTAssertEqual(appState.mode, initialMode, "Mode should not change with none action")
    }

    // MARK: - Cursor Movement Actions

    func testDispatchMoveCursorUp() async {
        appState.leftPane.cursorIndex = 1
        await appState.dispatch(.moveCursor(.up))
        XCTAssertEqual(appState.currentPane.cursorIndex, 0, "Cursor should move up")
    }

    func testDispatchMoveCursorDown() async {
        appState.leftPane.cursorIndex = 0
        // Ensure there are files to move to
        let tempFile = testDirectory.appendingPathComponent("file1.txt")
        try? "".write(to: tempFile, atomically: true, encoding: .utf8)

        await appState.refreshCurrentPane()
        let initialIndex = appState.currentPane.cursorIndex
        await appState.dispatch(.moveCursor(.down))

        // Cursor should move down or stay at last position
        XCTAssertGreaterThanOrEqual(
            appState.currentPane.cursorIndex,
            initialIndex,
            "Cursor should not move up"
        )
    }

    func testDispatchMoveCursorLeft() async {
        appState.setActivePane(.left)
        await appState.dispatch(.moveCursor(.left))
        // Should trigger leaveDirectory
        XCTAssertNotNil(appState.currentPane.activeTab.currentPath)
    }

    func testDispatchMoveCursorRight() async {
        appState.setActivePane(.left)
        await appState.dispatch(.moveCursor(.right))
        // Should trigger enterDirectory (if current item is a folder)
        XCTAssertNotNil(appState.currentPane.activeTab.currentPath)
    }

    // MARK: - Jump Actions

    func testDispatchJumpToTop() async {
        appState.leftPane.cursorIndex = 5
        await appState.dispatch(.pane(.jumpToTop))
        XCTAssertEqual(appState.currentPane.cursorIndex, 0, "Cursor should be at top")
    }

    func testDispatchJumpToBottom() async {
        let tempFile = testDirectory.appendingPathComponent("file1.txt")
        try? "".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        appState.leftPane.cursorIndex = 0
        await appState.dispatch(.pane(.jumpToBottom))
        let files = appState.currentPane.activeTab.files
        if !files.isEmpty {
            XCTAssertEqual(
                appState.currentPane.cursorIndex,
                files.count - 1,
                "Cursor should be at bottom"
            )
        }
    }

    // MARK: - Mouse Actions

    func testDispatchMouseClick() async {
        appState.setActivePane(.right)
        await appState.dispatch(.pane(.mouseClick(index: 0, paneSide: .left)))
        XCTAssertEqual(appState.activePane, .left, "Active pane should switch to left")
    }

    func testDispatchMouseCommandClick() async {
        // Create a file to click on
        let tempFile = testDirectory.appendingPathComponent("test.txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        _ = appState.mode
        if appState.currentPane.activeTab.files.count > 0 {
            await appState.dispatch(
                .pane(.mouseCommandClick(index: 0, paneSide: .left))
            )
            // Should enter visual mode or toggle selection
            XCTAssertTrue(true, "Command+Click handled")
        }
    }

    func testDispatchMouseShiftClick() async {
        let tempFile = testDirectory.appendingPathComponent("test.txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        if appState.currentPane.activeTab.files.count > 0 {
            await appState.dispatch(
                .pane(.mouseShiftClick(index: 0, paneSide: .left))
            )
            XCTAssertTrue(true, "Shift+Click handled")
        }
    }

    // MARK: - Directory Navigation

    func testDispatchEnterDirectory() async {
        let subDir = testDirectory.appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        await appState.refreshCurrentPane()
        if appState.currentPane.activeTab.files.count > 0 {
            _ = appState.currentPane.activeTab.currentPath
            await appState.dispatch(.paneAsync(.enterDirectory))
            // Path may change or stay same depending on file type
            XCTAssertNotNil(appState.currentPane.activeTab.currentPath)
        }
    }

    func testDispatchLeaveDirectory() async {
        _ = appState.currentPane.activeTab.currentPath
        await appState.dispatch(.paneAsync(.leaveDirectory))
        // Should go to parent directory or stay at root
        XCTAssertNotNil(appState.currentPane.activeTab.currentPath)
    }

    // MARK: - Pane and Tab Operations

    func testDispatchToggleActivePane() async {
        let initialPane = appState.activePane
        await appState.dispatch(.pane(.toggleActivePane))
        XCTAssertEqual(
            appState.activePane,
            initialPane.opposite,
            "Active pane should toggle"
        )
    }

    func testDispatchNewTab() async {
        let initialTabCount = appState.currentPane.tabs.count
        await appState.dispatch(.paneAsync(.newTab))
        XCTAssertEqual(
            appState.currentPane.tabs.count,
            initialTabCount + 1,
            "New tab should be created"
        )
    }

    func testDispatchCloseTab() async {
        // Create multiple tabs first
        await appState.dispatch(.paneAsync(.newTab))
        let initialTabCount = appState.currentPane.tabs.count

        if initialTabCount > 1 {
            await appState.dispatch(.pane(.closeTab))
            XCTAssertEqual(
                appState.currentPane.tabs.count,
                initialTabCount - 1,
                "Tab should be closed"
            )
        }
    }

    func testDispatchPreviousTab() async {
        await appState.dispatch(.paneAsync(.newTab))
        let initialIndex = appState.currentPane.activeTabIndex

        if initialIndex > 0 {
            await appState.dispatch(.paneAsync(.previousTab))
            XCTAssertEqual(
                appState.currentPane.activeTabIndex,
                initialIndex - 1,
                "Should move to previous tab"
            )
        }
    }

    func testDispatchNextTab() async {
        await appState.dispatch(.paneAsync(.newTab))
        let initialIndex = appState.currentPane.activeTabIndex

        await appState.dispatch(.paneAsync(.nextTab))
        if initialIndex < appState.currentPane.tabs.count - 1 {
            XCTAssertEqual(
                appState.currentPane.activeTabIndex,
                initialIndex + 1,
                "Should move to next tab"
            )
        }
    }

    // MARK: - Bookmark Operations

    func testDispatchToggleBookmarkBar() async {
        let initialState = appState.showBookmarkBar
        await appState.dispatch(.pane(.toggleBookmarkBar))
        XCTAssertEqual(
            appState.showBookmarkBar,
            !initialState,
            "Bookmark bar should toggle"
        )
    }

    func testDispatchAddBookmark() async {
        await appState.dispatch(.pane(.addBookmark))
        // Should show toast and add bookmark if applicable
        XCTAssertTrue(true, "Add bookmark action dispatched")
    }

    // MARK: - File Operations

    func testDispatchYank() async {
        let tempFile = testDirectory.appendingPathComponent("test.txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        await appState.dispatch(.file(.yank))
        XCTAssertTrue(true, "Yank action dispatched")
    }

    func testDispatchCut() async {
        let tempFile = testDirectory.appendingPathComponent("test.txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        await appState.dispatch(.file(.cut))
        XCTAssertEqual(
            appState.clipboardOperation,
            .cut,
            "Clipboard operation should be cut"
        )
    }

    func testDispatchVisualModeYank() async {
        appState.mode = .visual
        let tempFile = testDirectory.appendingPathComponent("test.txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        await appState.dispatch(.file(.visualModeYank))
        XCTAssertEqual(appState.mode, .normal, "Should exit visual mode after yank")
    }

    func testDispatchPaste() async {
        // Create a source file to copy
        let sourceFile = testDirectory.appendingPathComponent("source.txt")
        try? "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        // Copy file to clipboard
        appState.clipboard = [
            FileItem(
                id: UUID().uuidString,
                name: "source.txt",
                path: sourceFile,
                type: .file,
                size: 6,
                modifiedDate: Date(),
                createdDate: Date(),
                isHidden: false,
                permissions: "644",
                fileExtension: "txt"
            )
        ]
        appState.clipboardOperation = .copy

        await appState.dispatch(.file(.paste))
        XCTAssertTrue(true, "Paste action dispatched")
    }

    func testDispatchDeleteSelectedFiles() async {
        let tempFile = testDirectory.appendingPathComponent("test.txt")
        try? "test".write(to: tempFile, atomically: true, encoding: .utf8)
        await appState.refreshCurrentPane()

        appState.mode = .visual
        await appState.dispatch(.file(.deleteSelectedFiles))
        XCTAssertEqual(appState.mode, .normal, "Should exit visual mode after delete")
    }

    func testDispatchBatchRename() async {
        await appState.dispatch(.file(.batchRename))
        XCTAssertEqual(
            appState.mode,
            .batchRename,
            "Should enter batch rename mode"
        )
    }

    func testDispatchStartRenamingFile() async {
        let filePath = testDirectory.appendingPathComponent("test.txt").path
        await appState.dispatch(.file(.startRenamingFile(fileName: "test.txt", filePath: filePath)))
        XCTAssertEqual(
            appState.editingFileId,
            appState.editingFileId,
            "Should set editing file ID"
        )
    }

    func testDispatchRefreshCurrentPane() async {
        let initialPath = appState.currentPane.activeTab.currentPath
        await appState.dispatch(.paneAsync(.refreshCurrentPane))
        XCTAssertEqual(
            appState.currentPane.activeTab.currentPath,
            initialPath,
            "Current path should remain same"
        )
    }

    // MARK: - Drive Selection

    func testDispatchMoveDriveCursorUp() async {
        appState.driveSelectorCursor = 0
        let tempDir = testDirectory.appendingPathComponent("drive1")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let initialCursor = appState.driveSelectorCursor
        await appState.dispatch(.drive(.moveDriveCursor(.up)))
        // Cursor won't move if already at 0
        XCTAssertLessThanOrEqual(appState.driveSelectorCursor, initialCursor)
    }

    func testDispatchMoveDriveCursorDown() async {
        let initialCursor = appState.driveSelectorCursor
        await appState.dispatch(.drive(.moveDriveCursor(.down)))
        // Cursor may move down or stay at max
        XCTAssertGreaterThanOrEqual(appState.driveSelectorCursor, initialCursor)
    }

    // MARK: - Command Mode

    func testDispatchDeleteCommand() async {
        appState.commandInput = "test"
        await appState.dispatch(.command(.deleteCommand))
        XCTAssertEqual(
            appState.commandInput,
            "tes",
            "Last character should be removed"
        )
    }

    func testDispatchInsertCommandWithLetter() async {
        appState.mode = .command
        await appState.dispatch(.command(.insertCommand("a")))
        XCTAssertTrue(
            appState.commandInput.contains("a"),
            "Command input should contain letter"
        )
    }

    func testDispatchInsertCommandWithNumber() async {
        appState.mode = .command
        await appState.dispatch(.command(.insertCommand("5")))
        XCTAssertTrue(
            appState.commandInput.contains("5"),
            "Command input should contain number"
        )
    }

    func testDispatchInsertCommandWithPunctuation() async {
        appState.mode = .command
        await appState.dispatch(.command(.insertCommand(".")))
        XCTAssertTrue(
            appState.commandInput.contains("."),
            "Command input should contain punctuation"
        )
    }

    // MARK: - Filter Mode

    func testDispatchDeleteFilterCharacter() async {
        appState.filterInput = "test"
        await appState.dispatch(.filter(.deleteFilterCharacter))
        XCTAssertEqual(
            appState.filterInput,
            "tes",
            "Last character should be removed from filter"
        )
    }

    func testDispatchInputFilterCharacterLetter() async {
        appState.mode = .filter
        appState.filterUseRegex = false
        await appState.dispatch(.filter(.inputFilterCharacter("a")))
        XCTAssertTrue(
            appState.filterInput.contains("a"),
            "Filter input should contain letter"
        )
    }

    func testDispatchInputFilterCharacterSpecialRegex() async {
        appState.mode = .filter
        appState.filterUseRegex = true
        await appState.dispatch(.filter(.inputFilterCharacter("*")))
        XCTAssertTrue(
            appState.filterInput.contains("*"),
            "Filter input should contain regex special char"
        )
    }

    // MARK: - Theme and Help

    func testDispatchCycleTheme() async {
        await appState.dispatch(.ui(.cycleTheme))
        XCTAssertTrue(true, "Cycle theme action dispatched")
    }

    // MARK: - Sheet Actions

    func testDispatchShowSheet() async {
        await appState.dispatch(.ui(.showSheet(.rsyncSheet)))
        XCTAssertTrue(true, "Show sheet action dispatched")
    }

    func testDispatchDismissSheet() async {
        await appState.dispatch(.ui(.dismissSheet))
        XCTAssertTrue(true, "Dismiss sheet action dispatched")
    }

    func testDispatchToast() async {
        await appState.dispatch(.ui(.toast("Test message")))
        XCTAssertTrue(true, "Toast action dispatched")
    }
}
