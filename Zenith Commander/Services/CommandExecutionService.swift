//
//  CommandExecutionService.swift
//  Zenith Commander
//
//  Command execution service for command mode.
//

import Foundation

struct CommandExecutionContext {
    let commandInput: String
    let currentPath: URL
    let selectedFiles: [FileItem]
    let currentFile: FileItem?
    let undoManager: UndoManager?
}

struct CommandExecutionResult {
    var exitCommandMode: Bool = true
    var enterMode: AppMode?
    var refreshCurrentPane: Bool = false
    var newPath: URL?
    var toastMessage: String?
    var uiRequest: UIRequest?
    var shouldTerminate: Bool = false
}

protocol CommandExecutionServicing {
    func executeCommand(_ context: CommandExecutionContext) async -> CommandExecutionResult
}

final class CommandExecutionService: CommandExecutionServicing {
    private let fileSystem: FileSysteming

    init(fileSystem: FileSysteming) {
        self.fileSystem = fileSystem
    }

    func executeCommand(_ context: CommandExecutionContext) async -> CommandExecutionResult {
        let trimmedInput = context.commandInput.trimmingCharacters(in: .whitespaces)
        guard !trimmedInput.isEmpty else {
            return CommandExecutionResult(exitCommandMode: true)
        }

        let command = CommandParser.parse(trimmedInput)

        switch command.type {
        case .mkdir:
            return await executeMkdir(command: command, context: context)

        case .touch:
            return await executeTouch(command: command, context: context)

        case .move, .mv:
            return await executeMove(command: command, context: context)

        case .copy, .cp:
            return await executeCopy(command: command, context: context)

        case .delete, .rm:
            return await executeDelete(command: command, context: context)

        case .cd:
            return executeCd(command: command, context: context)

        case .open:
            if let file = context.currentFile {
                fileSystem.openFile(file)
            }
            return CommandExecutionResult(exitCommandMode: true)

        case .term, .terminal:
            fileSystem.openInTerminal(path: context.currentPath)
            return CommandExecutionResult(exitCommandMode: true)

        case .q, .quit:
            return CommandExecutionResult(exitCommandMode: true, shouldTerminate: true)

        case .help:
            return CommandExecutionResult(
                exitCommandMode: false,
                enterMode: .help
            )

        case .ls:
            var result = CommandExecutionResult(exitCommandMode: true)
            result.refreshCurrentPane = true
            return result

        case .unknown:
            return CommandExecutionResult(
                exitCommandMode: true,
                toastMessage: LocalizationManager.shared.localized(
                    .toastUnknownCommand,
                    command.rawInput
                )
            )

        case .rsync:
            let (valid, _, error) = CommandParser.validateRsync(command)
            if valid {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    uiRequest: .rsyncSheet
                )
            }
            return CommandExecutionResult(exitCommandMode: true, toastMessage: error)
        }
    }

    private func executeMkdir(
        command: ParsedCommand,
        context: CommandExecutionContext
    ) async -> CommandExecutionResult {
        let (_, folderName) = CommandParser.validateMkdir(command)
        do {
            _ = try await fileSystem.createDirectory(
                at: context.currentPath,
                name: folderName,
                undoManager: context.undoManager
            )
            return CommandExecutionResult(exitCommandMode: true, refreshCurrentPane: true)
        } catch {
            return CommandExecutionResult(
                exitCommandMode: true,
                toastMessage: LocalizationManager.shared.localized(
                    .toastFailedToCreateDirectory,
                    error.localizedDescription
                )
            )
        }
    }

    private func executeTouch(
        command: ParsedCommand,
        context: CommandExecutionContext
    ) async -> CommandExecutionResult {
        let (_, fileName) = CommandParser.validateTouch(command)
        do {
            _ = try await fileSystem.createFile(
                at: context.currentPath,
                name: fileName,
                undoManager: context.undoManager
            )
            return CommandExecutionResult(exitCommandMode: true, refreshCurrentPane: true)
        } catch {
            return CommandExecutionResult(
                exitCommandMode: true,
                toastMessage: LocalizationManager.shared.localized(
                    .toastFailedToCreateFile,
                    error.localizedDescription
                )
            )
        }
    }

    private func executeMove(
        command: ParsedCommand,
        context: CommandExecutionContext
    ) async -> CommandExecutionResult {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: context.currentPath
        )

        guard result.valid else {
            return CommandExecutionResult(exitCommandMode: true, toastMessage: result.error)
        }

        if let srcPath = result.source, let destPath = result.destination {
            do {
                try await fileSystem.moveItem(at: srcPath, to: destPath)
                return CommandExecutionResult(exitCommandMode: true, refreshCurrentPane: true)
            } catch {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(
                        .toastMoveFailed,
                        error.localizedDescription
                    )
                )
            }
        }

        if let destPath = result.destination {
            guard !context.selectedFiles.isEmpty else {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(.toastNoFileSelected)
                )
            }

            do {
                try await fileSystem.moveFiles(
                    context.selectedFiles,
                    to: destPath,
                    undoManager: context.undoManager
                )
                return CommandExecutionResult(exitCommandMode: true, refreshCurrentPane: true)
            } catch {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(
                        .toastMoveFailed,
                        error.localizedDescription
                    )
                )
            }
        }

        return CommandExecutionResult(exitCommandMode: true)
    }

    private func executeCopy(
        command: ParsedCommand,
        context: CommandExecutionContext
    ) async -> CommandExecutionResult {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: context.currentPath
        )

        guard result.valid else {
            return CommandExecutionResult(exitCommandMode: true, toastMessage: result.error)
        }

        if let srcPath = result.source, let destPath = result.destination {
            do {
                try await fileSystem.copyItem(at: srcPath, to: destPath)
                return CommandExecutionResult(exitCommandMode: true, refreshCurrentPane: true)
            } catch {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(
                        .toastCopyFailed,
                        error.localizedDescription
                    )
                )
            }
        }

        if let destPath = result.destination {
            guard !context.selectedFiles.isEmpty else {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(.toastNoFileSelected)
                )
            }

            do {
                try await fileSystem.copyFiles(
                    context.selectedFiles,
                    to: destPath,
                    undoManager: context.undoManager
                )
                return CommandExecutionResult(exitCommandMode: true, refreshCurrentPane: true)
            } catch {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(
                        .toastCopyFailed,
                        error.localizedDescription
                    )
                )
            }
        }

        return CommandExecutionResult(exitCommandMode: true)
    }

    private func executeDelete(
        command: ParsedCommand,
        context: CommandExecutionContext
    ) async -> CommandExecutionResult {
        let result = CommandParser.validateDelete(
            command,
            currentPath: context.currentPath
        )

        if let targetPath = result.targetPath {
            do {
                try await fileSystem.trashItem(at: targetPath)
                return CommandExecutionResult(
                    exitCommandMode: true,
                    refreshCurrentPane: true,
                    toastMessage: LocalizationManager.shared.localized(.toastDeleted)
                        + ": \(targetPath.lastPathComponent)"
                )
            } catch {
                return CommandExecutionResult(
                    exitCommandMode: true,
                    toastMessage: LocalizationManager.shared.localized(
                        .toastDeleteFailed,
                        error.localizedDescription
                    )
                )
            }
        }

        guard !context.selectedFiles.isEmpty else {
            return CommandExecutionResult(
                exitCommandMode: true,
                toastMessage: LocalizationManager.shared.localized(.toastNoFileSelected)
            )
        }

        do {
            try await fileSystem.trashFiles(
                context.selectedFiles,
                undoManager: context.undoManager
            )
            return CommandExecutionResult(
                exitCommandMode: true,
                refreshCurrentPane: true,
                toastMessage: LocalizationManager.shared.localized(
                    .toastFilesMovedToTrash,
                    context.selectedFiles.count
                )
            )
        } catch {
            return CommandExecutionResult(
                exitCommandMode: true,
                toastMessage: LocalizationManager.shared.localized(
                    .toastDeleteFailed,
                    error.localizedDescription
                )
            )
        }
    }

    private func executeCd(
        command: ParsedCommand,
        context: CommandExecutionContext
    ) -> CommandExecutionResult {
        let result = CommandParser.validateCd(
            command,
            currentPath: context.currentPath
        )
        if result.valid, let targetPath = result.targetPath {
            return CommandExecutionResult(
                exitCommandMode: true,
                refreshCurrentPane: true,
                newPath: targetPath
            )
        }

        if let error = result.error {
            return CommandExecutionResult(exitCommandMode: true, toastMessage: error)
        }

        return CommandExecutionResult(exitCommandMode: true)
    }
}
