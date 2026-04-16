//
//  AIService.swift
//  Zenith Commander
//
//  Launch AI CLI tools inside the user's terminal
//

import AppKit
import Foundation

protocol AIServiceProviding {
    func openToolInTerminal(tool: AIToolConfig, at directory: URL) throws
    func isToolInstalled(_ tool: AIToolConfig) -> Bool
    func errorMessage(for error: Error, tool: AIToolConfig) -> String
}

protocol AITerminalLaunching {
    func launch(scriptAt scriptURL: URL, terminal: TerminalOption) throws
    func launchWarp(configurationName: String, terminal: TerminalOption) throws
    func launchKitty(command: String, at directory: URL, terminal: TerminalOption) throws
    func launchGhostty(command: String, at directory: URL, terminal: TerminalOption) throws
}

struct DefaultAITerminalLauncher: AITerminalLaunching {
    func launch(scriptAt scriptURL: URL, terminal: TerminalOption) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", terminal.bundleId, scriptURL.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    func launchWarp(configurationName: String, terminal: TerminalOption) throws {
        guard let launchURI = makeWarpLaunchURI(configurationName: configurationName) else {
            throw AIServiceError.failedToLaunchTerminal
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", terminal.bundleId, launchURI.absoluteString]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    func launchKitty(command: String, at directory: URL, terminal: TerminalOption) throws {
        guard let kittyExecutable = resolveKittyExecutablePath(terminal: terminal) else {
            throw AIServiceError.failedToLaunchTerminal
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: kittyExecutable)
        process.arguments = [
            "--detach",
            "--single-instance",
            "--working-directory", directory.path,
            "/bin/zsh", "-ilc", "\(command)\nexec /bin/zsh -il",
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    func launchGhostty(command: String, at directory: URL, terminal: TerminalOption) throws {
        guard let applicationPath = resolveGhosttyApplicationPath(terminal: terminal) else {
            throw AIServiceError.failedToLaunchTerminal
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = makeGhosttyLaunchArguments(
            command: command,
            at: directory,
            applicationPath: applicationPath
        )

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    func makeGhosttyLaunchArguments(
        command: String,
        at directory: URL,
        applicationPath: String
    ) -> [String] {
        let escapedDir = shellEscaped(directory.path)
        return [
            "-na", applicationPath,
            "--args",
            "--command=/bin/zsh -c \"cd '\(escapedDir)' && \(command); exec /bin/zsh -il\"",
        ]
    }

    private func resolveKittyExecutablePath(terminal: TerminalOption) -> String? {
        var candidatePaths: [String] = []

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleId) {
            let executable = appURL
                .appendingPathComponent("Contents/MacOS/kitty")
                .path
            candidatePaths.append(executable)
        }

        candidatePaths.append(contentsOf: ExternalToolchain.candidatePaths.map { "\($0)kitty" })
        candidatePaths.append("/Applications/kitty.app/Contents/MacOS/kitty")

        return ToolPathUtils.resolveFirstExecutablePath(candidatePaths: candidatePaths)
    }

    private func resolveGhosttyApplicationPath(terminal: TerminalOption) -> String? {
        var candidatePaths: [String] = []

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleId) {
            candidatePaths.append(appURL.path)
        }

        candidatePaths.append("/Applications/Ghostty.app")

        return candidatePaths.first {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    private func shellEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func makeWarpLaunchURI(configurationName: String) -> URL? {
        guard let encodedName = percentEncodeURIComponent(configurationName) else {
            return nil
        }
        return URL(string: "warp://launch/\(encodedName)")
    }

    private func percentEncodeURIComponent(_ value: String) -> String? {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}

enum AIServiceError: Error {
    case unsupportedLocation
    case toolNotInstalled
    case invalidCommand
    case failedToCreateScript
    case failedToLaunchTerminal
}

final class AIService: AIServiceProviding {
    static let shared = AIService()

    private let launcher: AITerminalLaunching
    private let terminalProvider: () -> TerminalOption
    private let temporaryDirectoryProvider: () -> URL
    private let warpLaunchConfigurationDirectoryProvider: () -> URL

    init(
        launcher: AITerminalLaunching = DefaultAITerminalLauncher(),
        terminalProvider: @escaping () -> TerminalOption = {
            SettingsManager.shared.settings.terminal.currentTerminal
        },
        temporaryDirectoryProvider: @escaping () -> URL = {
            FileManager.default.temporaryDirectory
        },
        warpLaunchConfigurationDirectoryProvider: @escaping () -> URL = {
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".warp", isDirectory: true)
                .appendingPathComponent("launch_configurations", isDirectory: true)
        }
    ) {
        self.launcher = launcher
        self.terminalProvider = terminalProvider
        self.temporaryDirectoryProvider = temporaryDirectoryProvider
        self.warpLaunchConfigurationDirectoryProvider = warpLaunchConfigurationDirectoryProvider
    }

    func openToolInTerminal(tool: AIToolConfig, at directory: URL) throws {
        guard directory.isFileURL else {
            throw AIServiceError.unsupportedLocation
        }

        guard let executableName = tool.executableName else {
            throw AIServiceError.invalidCommand
        }

        guard isToolInstalled(tool) else {
            throw AIServiceError.toolNotInstalled
        }

        let terminal = terminalProvider()
        switch terminal.id {
        case "warp":
            try openToolInWarp(tool: tool, at: directory, terminal: terminal)
        case "terminal":
            try openToolInMacTerminal(
                tool: tool,
                executableName: executableName,
                at: directory,
                terminal: terminal
            )
        case "kitty":
            try openToolInKitty(tool: tool, at: directory, terminal: terminal)
        case "ghostty":
            try openToolInGhostty(tool: tool, at: directory, terminal: terminal)
        default:
            try openToolWithScript(tool: tool, executableName: executableName, at: directory, terminal: terminal)
        }
    }

    func isToolInstalled(_ tool: AIToolConfig) -> Bool {
        guard let executableName = tool.executableName else {
            return false
        }

        let candidatePaths = ExternalToolchain.candidatePaths.map {
            "\($0)\(executableName)"
        }
        if let resolvedPath = ToolPathUtils.resolveFirstExecutablePath(
            candidatePaths: candidatePaths
        ) {
            return !resolvedPath.isEmpty
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", executableName]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func errorMessage(for error: Error, tool: AIToolConfig) -> String {
        let localizationManager = LocalizationManager.shared

        guard let serviceError = error as? AIServiceError else {
            return localizationManager.localized(.aiLaunchFailed, tool.displayName)
        }

        switch serviceError {
        case .unsupportedLocation:
            return localizationManager.localized(.aiRequiresLocalPath)
        case .toolNotInstalled:
            return localizationManager.localized(.aiToolUnavailable, tool.displayName)
        case .invalidCommand:
            return localizationManager.localized(.aiInvalidCommand, tool.displayName)
        case .failedToCreateScript, .failedToLaunchTerminal:
            return localizationManager.localized(.aiLaunchFailed, tool.displayName)
        }
    }

    func makeLaunchScript(
        tool: AIToolConfig,
        executableName: String,
        directory: URL,
        scriptPath: String
    ) -> String {
        let escapedDirectory = shellEscaped(directory.path)
        let escapedScriptPath = shellEscaped(scriptPath)
        let escapedCommand = tool.command.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedExecutableName = shellEscaped(executableName)

        return """
            #!/bin/bash
            cd '\(escapedDirectory)'
            rm -f '\(escapedScriptPath)'
            if ! command -v '\(escapedExecutableName)' >/dev/null 2>&1; then
                exec "${SHELL:-/bin/bash}" -l
            fi
            \(escapedCommand)
            exec "${SHELL:-/bin/bash}" -l
            """
    }

    private func shellEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func openToolWithScript(
        tool: AIToolConfig,
        executableName: String,
        at directory: URL,
        terminal: TerminalOption
    ) throws {
        let tempScript = temporaryDirectoryProvider()
            .appendingPathComponent("zenith_ai_\(UUID().uuidString).command")

        let scriptContent = makeLaunchScript(
            tool: tool,
            executableName: executableName,
            directory: directory,
            scriptPath: tempScript.path
        )

        try writeScriptAndLaunch(
            scriptContent: scriptContent,
            scriptURL: tempScript,
            terminal: terminal
        )
    }

    private func openToolInMacTerminal(
        tool: AIToolConfig,
        executableName: String,
        at directory: URL,
        terminal: TerminalOption
    ) throws {
        let tempScript = temporaryDirectoryProvider()
            .appendingPathComponent("zenith_ai_\(UUID().uuidString).command")

        let scriptContent = makeTerminalLaunchScript(
            tool: tool,
            executableName: executableName,
            directory: directory,
            scriptPath: tempScript.path
        )

        try writeScriptAndLaunch(
            scriptContent: scriptContent,
            scriptURL: tempScript,
            terminal: terminal
        )
    }

    private func writeScriptAndLaunch(
        scriptContent: String,
        scriptURL: URL,
        terminal: TerminalOption
    ) throws {
        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            throw AIServiceError.failedToCreateScript
        }

        do {
            try launcher.launch(scriptAt: scriptURL, terminal: terminal)
        } catch {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    private func makeTerminalLaunchScript(
        tool: AIToolConfig,
        executableName _: String,
        directory: URL,
        scriptPath: String
    ) -> String {
        let escapedDirectory = shellEscaped(directory.path)
        let escapedScriptPath = shellEscaped(scriptPath)
        let escapedCommand = shellEscaped(
            tool.command.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        return """
            #!/bin/zsh
            cd '\(escapedDirectory)'
            rm -f '\(escapedScriptPath)'
            /bin/zsh -ilc '\(escapedCommand)'
            exec /bin/zsh -il
            """
    }

    private func openToolInWarp(
        tool: AIToolConfig,
        at directory: URL,
        terminal: TerminalOption
    ) throws {
        let configurationName = "Zenith Commander \(tool.displayName)"
        let configurationDirectory = warpLaunchConfigurationDirectoryProvider()
        let configurationURL = configurationDirectory
            .appendingPathComponent("zenith_ai_\(UUID().uuidString).yaml")

        let configuration = makeWarpLaunchConfiguration(
            name: configurationName,
            tool: tool,
            directory: directory
        )

        do {
            try FileManager.default.createDirectory(
                at: configurationDirectory,
                withIntermediateDirectories: true
            )
            try configuration.write(to: configurationURL, atomically: true, encoding: .utf8)
        } catch {
            throw AIServiceError.failedToCreateScript
        }

        do {
            try launcher.launchWarp(configurationName: configurationName, terminal: terminal)
        } catch {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    private func openToolInKitty(
        tool: AIToolConfig,
        at directory: URL,
        terminal: TerminalOption
    ) throws {
        let command = tool.command.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try launcher.launchKitty(command: command, at: directory, terminal: terminal)
        } catch {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    private func openToolInGhostty(
        tool: AIToolConfig,
        at directory: URL,
        terminal: TerminalOption
    ) throws {
        let command = tool.command.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try launcher.launchGhostty(command: command, at: directory, terminal: terminal)
        } catch {
            throw AIServiceError.failedToLaunchTerminal
        }
    }

    private func makeWarpLaunchConfiguration(
        name: String,
        tool: AIToolConfig,
        directory: URL
    ) -> String {
        let escapedLaunchName = yamlSingleQuoted(name)
        let escapedName = yamlSingleQuoted(tool.displayName)
        let escapedCommand = yamlSingleQuoted(
            tool.command.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let escapedDirectory = yamlSingleQuoted(directory.path)

        return """
            ---
            name: '\(escapedLaunchName)'
            windows:
              - tabs:
                  - title: '\(escapedName)'
                    layout:
                      cwd: '\(escapedDirectory)'
                      commands:
                        - exec: '\(escapedCommand)'
            """
    }

    private func yamlSingleQuoted(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
