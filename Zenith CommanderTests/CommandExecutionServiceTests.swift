//
//  CommandExecutionServiceTests.swift
//  Zenith CommanderTests
//

import XCTest
@testable import Zenith_Commander

@MainActor
final class CommandExecutionServiceTests: XCTestCase {
    final class StubFileSystem: FileSysteming {
        var createdDirectories: [(path: URL, name: String)] = []
        var createdFiles: [(path: URL, name: String)] = []
        var movedItems: [(src: URL, dest: URL)] = []
        var copiedItems: [(src: URL, dest: URL)] = []
        var trashedItems: [URL] = []
        var movedFiles: [[FileItem]] = []
        var copiedFiles: [[FileItem]] = []
        var trashedFiles: [[FileItem]] = []
        var openedFiles: [FileItem] = []
        var openedTerminals: [URL] = []

        func homeDirectory() -> URL {
            URL(fileURLWithPath: "/")
        }

        func tempDirectory() -> URL {
            URL(fileURLWithPath: "/tmp")
        }

        func fileExists(_ url: URL) -> Bool {
            false
        }

        func createDirectory(_ url: URL) throws {}

        func createDirectory(
            at path: URL,
            name: String,
            undoManager: UndoManager?
        ) async throws -> URL {
            createdDirectories.append((path: path, name: name))
            return path.appendingPathComponent(name)
        }

        func createFile(
            at path: URL,
            name: String,
            undoManager: UndoManager?
        ) async throws -> URL {
            createdFiles.append((path: path, name: name))
            return path.appendingPathComponent(name)
        }

        func loadDirectory(at url: URL) async -> [FileItem] {
            []
        }

        func copyFiles(
            _ files: [FileItem],
            to dest: URL,
            undoManager: UndoManager?
        ) async throws {
            copiedFiles.append(files)
        }

        func moveFiles(
            _ files: [FileItem],
            to dest: URL,
            undoManager: UndoManager?
        ) async throws {
            movedFiles.append(files)
        }

        func trashFiles(_ files: [FileItem], undoManager: UndoManager?) async throws {
            trashedFiles.append(files)
        }

        func moveItem(at src: URL, to dest: URL) async throws {
            movedItems.append((src: src, dest: dest))
        }

        func copyItem(at src: URL, to dest: URL) async throws {
            copiedItems.append((src: src, dest: dest))
        }

        func trashItem(at url: URL) async throws {
            trashedItems.append(url)
        }

        func parentDirectory(of url: URL) -> URL {
            url.deletingLastPathComponent()
        }

        func openFile(_ file: FileItem) {
            openedFiles.append(file)
        }

        func openInTerminal(path: URL) {
            openedTerminals.append(path)
        }

        func mountedVolumes() async -> [DriveInfo] {
            []
        }
    }

    func testExecuteCommand_DeleteWithoutSelectionShowsToast() async {
        let fileSystem = StubFileSystem()
        let service = CommandExecutionService(fileSystem: fileSystem)
        let context = CommandExecutionContext(
            commandInput: "delete",
            currentPath: URL(fileURLWithPath: "/tmp"),
            selectedFiles: [],
            currentFile: nil,
            undoManager: nil
        )

        let result = await service.executeCommand(context)

        XCTAssertEqual(
            result.toastMessage,
            LocalizationManager.shared.localized(.toastNoFileSelected)
        )
        XCTAssertTrue(fileSystem.trashedFiles.isEmpty)
        XCTAssertTrue(fileSystem.trashedItems.isEmpty)
    }

    func testExecuteCommand_MkdirCreatesDirectoryAndRefreshes() async {
        let fileSystem = StubFileSystem()
        let service = CommandExecutionService(fileSystem: fileSystem)
        let context = CommandExecutionContext(
            commandInput: "mkdir TestFolder",
            currentPath: URL(fileURLWithPath: "/tmp"),
            selectedFiles: [],
            currentFile: nil,
            undoManager: nil
        )

        let result = await service.executeCommand(context)

        XCTAssertEqual(fileSystem.createdDirectories.count, 1)
        XCTAssertTrue(result.refreshCurrentPane)
        XCTAssertNil(result.toastMessage)
    }

    func testExecuteCommand_RsyncShowsSheetRequest() async {
        let fileSystem = StubFileSystem()
        let service = CommandExecutionService(fileSystem: fileSystem)
        let context = CommandExecutionContext(
            commandInput: "rsync",
            currentPath: URL(fileURLWithPath: "/tmp"),
            selectedFiles: [],
            currentFile: nil,
            undoManager: nil
        )

        let result = await service.executeCommand(context)

        XCTAssertEqual(result.uiRequest, .rsyncSheet)
    }
}
