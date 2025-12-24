//
//  AppEnvironment+Implementations.swift
//  Zenith Commander
//

import Foundation

final class LiveSettingsAdapter: SettingsProviding {
    var rsyncEnabled: Bool {
        get { SettingsManager.shared.settings.rsync.enabled }
        set {
            var settings = SettingsManager.shared.settings
            settings.rsync.enabled = newValue
            SettingsManager.shared.settings = settings
        }
    }
}

final class TestSettings: SettingsProviding {
    var rsyncEnabled: Bool

    init(rsyncEnabled: Bool = true) {
        self.rsyncEnabled = rsyncEnabled
    }
}

struct LiveToolRunner: ToolRunning {
    private let runner: ToolRunner

    init(runner: ToolRunner = ProcessToolRunner()) {
        self.runner = runner
    }

    func run(_ command: ToolCommand) async throws -> ToolResult {
        let request = ToolRequest(
            executable: command.executable,
            args: command.arguments,
            workingDirectory: command.workingDirectory?.path
        )
        let response = try await runner.run(request)
        return ToolResult(
            exitCode: response.exitCode,
            stdout: response.stdout.joined(separator: "\n"),
            stderr: response.stderr.joined(separator: "\n")
        )
    }
}

struct FakeToolRunner: ToolRunning {
    func run(_ command: ToolCommand) async throws -> ToolResult {
        ToolResult(exitCode: 0, stdout: "", stderr: "")
    }
}

struct LiveMainScheduler: MainScheduling {
    func async(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async {
            work()
        }
    }

    func asyncAfter(seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            work()
        }
    }
}

struct ImmediateMainScheduler: MainScheduling {
    func async(_ work: @escaping @MainActor () -> Void) {
        work()
    }

    func asyncAfter(seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        work()
    }
}

enum TestFileSystemError: Error {
    case outsideRoot(URL)
}

struct TestFileSystem: FileSysteming {
    let tempRoot: URL

    init(tempRoot: URL) {
        self.tempRoot = tempRoot
    }

    func homeDirectory() -> URL {
        tempRoot
    }

    func tempDirectory() -> URL {
        tempRoot.appendingPathComponent("tmp")
    }

    func fileExists(_ url: URL) -> Bool {
        guard isWithinRoot(url) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func createDirectory(_ url: URL) throws {
        try assertWithinRoot(url)
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
        let target = path.appendingPathComponent(name)
        try assertWithinRoot(target)
        try await runFileOperation {
            try FileManager.default.createDirectory(
                at: target,
                withIntermediateDirectories: true
            )
        }
        return target
    }

    func createFile(
        at path: URL,
        name: String,
        undoManager: UndoManager?
    ) async throws -> URL {
        let target = path.appendingPathComponent(name)
        try assertWithinRoot(target)
        try await runFileOperation {
            let manager = FileManager.default
            manager.createFile(atPath: target.path, contents: nil)
        }
        return target
    }

    func loadDirectory(at url: URL) async -> [FileItem] {
        guard isWithinRoot(url) else { return [] }
        return await FileSystemService.shared.loadDirectory(at: url)
    }

    func copyFiles(
        _ files: [FileItem],
        to dest: URL,
        undoManager: UndoManager?
    ) async throws {
        try assertWithinRoot(dest)
        try assertWithinRoot(files.map(\.path))
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
        try assertWithinRoot(dest)
        try assertWithinRoot(files.map(\.path))
        try await FileSystemService.shared.moveFiles(
            files,
            to: dest,
            undoManager: undoManager
        )
    }

    func trashFiles(_ files: [FileItem], undoManager: UndoManager?) async throws {
        try assertWithinRoot(files.map(\.path))
        try await FileSystemService.shared.trashFiles(
            files,
            undoManager: undoManager
        )
    }

    func moveItem(at src: URL, to dest: URL) async throws {
        try assertWithinRoot([src, dest])
        try await runFileOperation {
            try FileManager.default.moveItem(at: src, to: dest)
        }
    }

    func copyItem(at src: URL, to dest: URL) async throws {
        try assertWithinRoot([src, dest])
        try await runFileOperation {
            try FileManager.default.copyItem(at: src, to: dest)
        }
    }

    func trashItem(at url: URL) async throws {
        try assertWithinRoot(url)
        try await runFileOperation {
            try FileManager.default.trashItem(
                at: url,
                resultingItemURL: nil
            )
        }
    }

    func parentDirectory(of url: URL) -> URL {
        guard isWithinRoot(url) else { return tempRoot }
        let parent = url.deletingLastPathComponent()
        return isWithinRoot(parent) ? parent : tempRoot
    }

    func openFile(_ file: FileItem) {
        // No-op in tests to avoid launching external apps.
    }

    func openInTerminal(path: URL) {
        // No-op in tests to avoid launching terminal.
    }

    func mountedVolumes() async -> [DriveInfo] {
        [
            DriveInfo(
                id: "test-root",
                name: "Test Root",
                path: tempRoot,
                type: .system,
                totalCapacity: 0,
                availableCapacity: 0
            )
        ]
    }

    private func isWithinRoot(_ url: URL) -> Bool {
        let rootPath = tempRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private func assertWithinRoot(_ url: URL) throws {
        guard isWithinRoot(url) else {
            throw TestFileSystemError.outsideRoot(url)
        }
    }

    private func assertWithinRoot(_ urls: [URL]) throws {
        for url in urls {
            try assertWithinRoot(url)
        }
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
}

extension AppEnvironment {
    static func live(
        fileSystem: FileSysteming = LiveFileSystem(),
        settings: SettingsProviding = LiveSettingsAdapter(),
        toolRunner: ToolRunning = LiveToolRunner(),
        main: MainScheduling = LiveMainScheduler(),
        userDefaults: UserDefaults = .standard,
        runtime: RuntimePolicy = RuntimePolicy(startSideEffects: true)
    ) -> AppEnvironment {
        AppEnvironment(
            fileSystem: fileSystem,
            settings: settings,
            toolRunner: toolRunner,
            main: main,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }

    static func test(
        tempRoot: URL,
        settings: SettingsProviding = TestSettings(),
        toolRunner: ToolRunning = FakeToolRunner(),
        main: MainScheduling = ImmediateMainScheduler(),
        suiteName: String = "ZenithCommanderTests"
    ) -> AppEnvironment {
        let defaults = UserDefaults(suiteName: suiteName)
        if defaults == nil {
            assertionFailure("Failed to create test UserDefaults suite.")
        }
        return AppEnvironment(
            fileSystem: TestFileSystem(tempRoot: tempRoot),
            settings: settings,
            toolRunner: toolRunner,
            main: main,
            userDefaults: defaults ?? .standard,
            runtime: RuntimePolicy(startSideEffects: false)
        )
    }
}
