//  AppEnvironment.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/24/25.
//

import AppKit
import Combine
import Foundation

protocol FileSysteming {
    func homeDirectory() -> URL
    func tempDirectory() -> URL
    func fileExists(_ url: URL) -> Bool
    func createDirectory(_ url: URL) throws
    func createDirectory(
        at path: URL,
        name: String,
        undoManager: UndoManager?
    ) async throws -> URL
    func createFile(
        at path: URL,
        name: String,
        undoManager: UndoManager?
    ) async throws -> URL
    func loadDirectory(at url: URL) async -> [FileItem]  // 或你自己的类型
    func copyFiles(
        _ files: [FileItem],
        to dest: URL,
        undoManager: UndoManager?
    ) async throws
    func moveFiles(
        _ files: [FileItem],
        to dest: URL,
        undoManager: UndoManager?
    ) async throws
    func trashFiles(_ files: [FileItem], undoManager: UndoManager?) async throws
    func moveItem(at src: URL, to dest: URL) async throws
    func copyItem(at src: URL, to dest: URL) async throws
    func trashItem(at url: URL) async throws
    func parentDirectory(of url: URL) -> URL
    func openFile(_ file: FileItem)
    func openInTerminal(path: URL)
    func mountedVolumes() async -> [DriveInfo]
}

protocol SettingsProviding: AnyObject {
    var rsyncEnabled: Bool { get set }
    // 后面你需要更多再加：theme、keymap、bookmark...
}

protocol ToolRunning {
    func run(_ command: ToolCommand) async throws -> ToolResult
}

struct ToolCommand {
    var executable: String
    var arguments: [String]
    var workingDirectory: URL?
}

struct ToolResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

protocol MainScheduling {
    func async(_ work: @escaping @MainActor () -> Void)
    func asyncAfter(seconds: TimeInterval, _ work: @escaping @MainActor () -> Void)
}

struct RuntimePolicy: Sendable {
    var startSideEffects: Bool
}

struct InitParam{
    let leftInitPath:URL
    let rightInitPath:URL
}

struct AppEnvironment {
    var fileSystem: FileSysteming
    var settings: SettingsProviding
    var toolRunner: ToolRunning
    var main: MainScheduling
    var userDefaults: UserDefaults
    var runtime: RuntimePolicy
    var plugins: [ZenithPlugin] = []
    var initParam: InitParam
}

extension AppEnvironment{
    static var current: AppEnvironment = .live()
}

struct LiveFileSystem: FileSysteming {
    func homeDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }

    func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    func createDirectory(
        at path: URL,
        name: String,
        undoManager: UndoManager?
    ) async throws -> URL {
        try await FileSystemService.shared.createDirectory(
            at: path,
            name: name,
            undoManager: undoManager
        )
    }

    func createFile(
        at path: URL,
        name: String,
        undoManager: UndoManager?
    ) async throws -> URL {
        try await FileSystemService.shared.createFile(
            at: path,
            name: name,
            undoManager: undoManager
        )
    }

    func loadDirectory(at url: URL) async -> [FileItem] {
        await FileSystemService.shared.loadDirectory(at: url)
    }

    func copyFiles(
        _ files: [FileItem],
        to dest: URL,
        undoManager: UndoManager?
    ) async throws {
        try await FileSystemService.shared.copyFiles(
            files,
            to: dest,
            undoManager: undoManager
        )
    }

    func moveFiles(
        _ files: [FileItem],
        to dest: URL,
        undoManager: UndoManager?
    ) async throws {
        try await FileSystemService.shared.moveFiles(
            files,
            to: dest,
            undoManager: undoManager
        )
    }

    func trashFiles(_ files: [FileItem], undoManager: UndoManager?) async throws {
        try await FileSystemService.shared.trashFiles(
            files,
            undoManager: undoManager
        )
    }

    private func runFileOperation(_ work: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try work()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func moveItem(at src: URL, to dest: URL) async throws {
        try await runFileOperation {
            try FileManager.default.moveItem(at: src, to: dest)
        }
    }

    func copyItem(at src: URL, to dest: URL) async throws {
        try await runFileOperation {
            try FileManager.default.copyItem(at: src, to: dest)
        }
    }

    func trashItem(at url: URL) async throws {
        try await runFileOperation {
            try FileManager.default.trashItem(
                at: url,
                resultingItemURL: nil
            )
        }
    }

    func parentDirectory(of url: URL) -> URL {
        FileSystemService.shared.parentDirectory(of: url)
    }

    func openFile(_ file: FileItem) {
        FileSystemService.shared.openFile(file)
    }

    func openInTerminal(path: URL) {
        FileSystemService.shared.openInTerminal(path: path)
    }

    func mountedVolumes() async -> [DriveInfo] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(
                    returning: FileSystemService.shared.getMountedVolumes()
                )
            }
        }
    }
}
