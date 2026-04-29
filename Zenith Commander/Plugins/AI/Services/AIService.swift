//
//  AIService.swift
//  Zenith Commander
//
//  Launch AI CLI tools inside the user's terminal
//

import Foundation

protocol AIServiceProviding {
    func openToolInTerminal(tool: AIToolConfig, at directory: URL) throws
    func isToolInstalled(_ tool: AIToolConfig) -> Bool
    func errorMessage(for error: Error, tool: AIToolConfig) -> String
}

protocol AITerminalLaunching {
    func launch(scriptAt scriptURL: URL, terminal: TerminalOption) throws
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

    init(
        launcher: AITerminalLaunching = DefaultAITerminalLauncher(),
        terminalProvider: @escaping () -> TerminalOption = {
            SettingsManager.shared.settings.terminal.currentTerminal
        },
        temporaryDirectoryProvider: @escaping () -> URL = {
            FileManager.default.temporaryDirectory
        }
    ) {
        self.launcher = launcher
        self.terminalProvider = terminalProvider
        self.temporaryDirectoryProvider = temporaryDirectoryProvider
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

        let tempScript = temporaryDirectoryProvider()
            .appendingPathComponent("zenith_ai_\(UUID().uuidString).command")

        let scriptContent = makeLaunchScript(
            tool: tool,
            executableName: executableName,
            directory: directory,
            scriptPath: tempScript.path
        )

        do {
            try scriptContent.write(to: tempScript, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tempScript.path
            )
        } catch {
            throw AIServiceError.failedToCreateScript
        }

        do {
            try launcher.launch(scriptAt: tempScript, terminal: terminalProvider())
        } catch {
            throw AIServiceError.failedToLaunchTerminal
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
}
