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
        XCTAssertTrue(script.contains("/bin/zsh -ilc 'sh'"))
        XCTAssertTrue(script.contains("exec /bin/zsh -il"))
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

    func testOpenToolInTerminalUsesWarpLaunchConfigurationWhenWarpSelected() throws {
        let launcher = RecordingAITerminalLauncher()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zc-ai-tests-\(UUID().uuidString)", isDirectory: true)
        let warpConfigurationsDirectory =
            temporaryDirectory
            .appendingPathComponent("warp-launch-configs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let service = AIService(
            launcher: launcher,
            terminalProvider: {
                TerminalOption(
                    id: "warp",
                    name: "Warp",
                    bundleId: "dev.warp.Warp-Stable"
                )
            },
            temporaryDirectoryProvider: { temporaryDirectory },
            warpLaunchConfigurationDirectoryProvider: { warpConfigurationsDirectory }
        )
        let tool = AIToolConfig(
            id: "gemini",
            name: "Gemini",
            command: "gemini",
            icon: "sparkles",
            enabled: true
        )
        let directory = URL(fileURLWithPath: "/tmp/Project O'Neil")

        try service.openToolInTerminal(tool: tool, at: directory)

        XCTAssertNil(launcher.launchedScriptURL)
        XCTAssertEqual(launcher.launchedWarpTerminal?.bundleId, "dev.warp.Warp-Stable")
        XCTAssertEqual(launcher.launchedWarpConfigurationName, "Zenith Commander Gemini")

        let files = try FileManager.default.contentsOfDirectory(
            at: warpConfigurationsDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "yaml" || $0.pathExtension == "yml" }

        XCTAssertEqual(files.count, 1)
        let configurationURL = try XCTUnwrap(files.first)
        let configuration = try String(contentsOf: configurationURL, encoding: .utf8)
        XCTAssertTrue(configuration.contains("name: 'Zenith Commander Gemini'"))
        XCTAssertTrue(configuration.contains("cwd: '/tmp/Project O''Neil'"))
        XCTAssertTrue(configuration.contains("exec: 'gemini'"))
    }

    func testOpenToolInTerminalUsesKittyLauncherWhenKittySelected() throws {
        let launcher = RecordingAITerminalLauncher()
        let service = AIService(
            launcher: launcher,
            terminalProvider: {
                TerminalOption(
                    id: "kitty",
                    name: "Kitty",
                    bundleId: "net.kovidgoyal.kitty"
                )
            }
        )
        let tool = AIToolConfig(
            id: "gemini",
            name: "Gemini",
            command: "gemini",
            icon: "sparkles",
            enabled: true
        )
        let directory = URL(fileURLWithPath: "/tmp/project")

        try service.openToolInTerminal(tool: tool, at: directory)

        XCTAssertNil(launcher.launchedScriptURL)
        XCTAssertNil(launcher.launchedWarpConfigurationName)
        XCTAssertEqual(launcher.launchedKittyTerminal?.bundleId, "net.kovidgoyal.kitty")
        XCTAssertEqual(launcher.launchedKittyDirectory?.path, "/tmp/project")
        XCTAssertEqual(launcher.launchedKittyCommand, "gemini")
    }

    func testOpenToolInTerminalUsesGhosttyLauncherWhenGhosttySelected() throws {
        let launcher = RecordingAITerminalLauncher()
        let service = AIService(
            launcher: launcher,
            terminalProvider: {
                TerminalOption(
                    id: "ghostty",
                    name: "Ghostty",
                    bundleId: "com.mitchellh.ghostty"
                )
            }
        )
        let tool = AIToolConfig(
            id: "claude",
            name: "Claude",
            command: "claude",
            icon: "brain.head.profile",
            enabled: true
        )
        let directory = URL(fileURLWithPath: "/tmp/project")

        try service.openToolInTerminal(tool: tool, at: directory)

        XCTAssertNil(launcher.launchedScriptURL)
        XCTAssertNil(launcher.launchedWarpConfigurationName)
        XCTAssertNil(launcher.launchedKittyCommand)
        XCTAssertEqual(launcher.launchedGhosttyTerminal?.bundleId, "com.mitchellh.ghostty")
        XCTAssertEqual(launcher.launchedGhosttyDirectory?.path, "/tmp/project")
        XCTAssertEqual(launcher.launchedGhosttyCommand, "claude")
    }

    func testGhosttyLaunchArgumentsEmbedCdInCommandForWorkingDirectory() {
        let launcher = DefaultAITerminalLauncher()
        let directory = URL(fileURLWithPath: "/tmp/Project O'Neil")

        let arguments = launcher.makeGhosttyLaunchArguments(
            command: "gemini",
            at: directory,
            applicationPath: "/Applications/Ghostty.app"
        )

        XCTAssertEqual(arguments.count, 4)
        XCTAssertEqual(arguments[0], "-na")
        XCTAssertEqual(arguments[1], "/Applications/Ghostty.app")
        XCTAssertEqual(arguments[2], "--args")
        XCTAssertEqual(
            arguments[3],
            "--command=/bin/zsh -c \"cd '/tmp/Project O'\\''Neil' && gemini; exec /bin/zsh -il\""
        )
    }
}

private final class RecordingAITerminalLauncher: AITerminalLaunching {
    var launchedScriptURL: URL?
    var launchedTerminal: TerminalOption?
    var launchedWarpConfigurationName: String?
    var launchedWarpTerminal: TerminalOption?
    var launchedKittyCommand: String?
    var launchedKittyDirectory: URL?
    var launchedKittyTerminal: TerminalOption?
    var launchedGhosttyCommand: String?
    var launchedGhosttyDirectory: URL?
    var launchedGhosttyTerminal: TerminalOption?

    func launch(scriptAt scriptURL: URL, terminal: TerminalOption) throws {
        launchedScriptURL = scriptURL
        launchedTerminal = terminal
    }

    func launchWarp(configurationName: String, terminal: TerminalOption) throws {
        launchedWarpConfigurationName = configurationName
        launchedWarpTerminal = terminal
    }

    func launchKitty(command: String, at directory: URL, terminal: TerminalOption) throws {
        launchedKittyCommand = command
        launchedKittyDirectory = directory
        launchedKittyTerminal = terminal
    }

    func launchGhostty(command: String, at directory: URL, terminal: TerminalOption) throws {
        launchedGhosttyCommand = command
        launchedGhosttyDirectory = directory
        launchedGhosttyTerminal = terminal
    }
}
