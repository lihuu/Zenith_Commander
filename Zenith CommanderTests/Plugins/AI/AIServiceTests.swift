//
//  AIServiceTests.swift
//  Zenith CommanderTests
//

import XCTest

@testable import Zenith_Commander

@MainActor
final class AIServiceTests: XCTestCase {
    func testOpenToolInTerminalCreatesEscapedScriptAndLaunchesPreferredTerminal() throws {
        let launcher = RecordingAITerminalLauncher()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zc-ai-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let service = AIService(
            launcher: launcher,
            terminalProvider: {
                TerminalOption(
                    id: "terminal",
                    name: "Terminal",
                    bundleId: "com.apple.Terminal"
                )
            },
            temporaryDirectoryProvider: { temporaryDirectory }
        )
        let tool = AIToolConfig(
            id: "gemini",
            name: "Gemini",
            command: "sh",
            icon: "sparkles",
            enabled: true
        )
        let directory = URL(fileURLWithPath: "/tmp/Project O'Neil")

        try service.openToolInTerminal(tool: tool, at: directory)

        XCTAssertEqual(launcher.launchedTerminal?.bundleId, "com.apple.Terminal")
        XCTAssertNotNil(launcher.launchedScriptURL)

        let scriptURL = try XCTUnwrap(launcher.launchedScriptURL)
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        XCTAssertTrue(script.contains("cd '/tmp/Project O'\\''Neil'"))
        XCTAssertTrue(script.contains("sh"))
        XCTAssertTrue(script.contains("exec \"${SHELL:-/bin/bash}\" -l"))
    }

    func testIsToolInstalledReturnsFalseForUnknownExecutable() {
        let service = AIService()
        let tool = AIToolConfig(
            id: "missing",
            name: "Missing",
            command: "definitely-not-a-real-command-zc",
            icon: "sparkles",
            enabled: true
        )

        XCTAssertFalse(service.isToolInstalled(tool))
    }

    func testIsToolInstalledReturnsTrueForShell() {
        let service = AIService()
        let tool = AIToolConfig(
            id: "shell",
            name: "Shell",
            command: "sh",
            icon: "terminal",
            enabled: true
        )

        XCTAssertTrue(service.isToolInstalled(tool))
    }
}

private final class RecordingAITerminalLauncher: AITerminalLaunching {
    var launchedScriptURL: URL?
    var launchedTerminal: TerminalOption?

    func launch(scriptAt scriptURL: URL, terminal: TerminalOption) throws {
        launchedScriptURL = scriptURL
        launchedTerminal = terminal
    }
}
