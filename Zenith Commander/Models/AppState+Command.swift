//
//  AppState+Command.swift
//  Zenith Commander
//
//  命令模式处理扩展
//

import AppKit
import Foundation

// For command mode process
extension AppState {
    func executeCommand() async {
        let commandInput = commandInput.trimmingCharacters(
            in: .whitespaces
        )
        guard !commandInput.isEmpty else {
            exitMode()
            return
        }

        // 使用 CommandParser 解析命令
        let command = CommandParser.parse(commandInput)
        let currentPath = currentPane.activeTab.currentPath

        switch command.type {
        case .mkdir:
            // mkdir <name> - 在当前目录创建文件夹
            let (_, folderName) = CommandParser.validateMkdir(command)
            do {
                _ = try await env.fileSystem.createDirectory(
                    at: currentPath,
                    name: folderName,
                    undoManager: undoManager
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastFailedToCreateDirectory,
                        error.localizedDescription
                    )
                )
            }

        case .touch:
            // touch <name> - 在当前目录创建文件
            let (_, fileName) = CommandParser.validateTouch(command)
            do {
                _ = try await env.fileSystem.createFile(
                    at: currentPath,
                    name: fileName,
                    undoManager: undoManager
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastFailedToCreateFile,
                        error.localizedDescription
                    )
                )
            }

        case .move, .mv:
            // move <src> <dest> 或 move <dest> (使用选中文件作为源)
            await executeMove(command: command, currentPath: currentPath)

        case .copy, .cp:
            // copy <src> <dest> 或 copy <dest> (使用选中文件作为源)
            await executeCopy(command: command, currentPath: currentPath)

        case .delete, .rm:
            // delete [name] - 删除指定文件或当前选中文件
            await executeDelete(command: command, currentPath: currentPath)

        case .cd:
            // cd <path> - 切换目录
            let result = CommandParser.validateCd(
                command,
                currentPath: currentPath
            )
            if result.valid, let targetPath = result.targetPath {
                currentPane.activeTab.currentPath = targetPath
                await refreshCurrentPane()
            } else if let error = result.error {
                showToast(error)
            }

        case .open:
            // open - 打开当前选中的文件
            if let file = currentFile() {
                env.fileSystem.openFile(file)
            }

        case .term, .terminal:
            // term - 在当前目录打开终端
            env.fileSystem.openInTerminal(path: currentPath)

        case .q, .quit:
            NSApp.terminate(nil)

        case .help:
            // help or ? - 显示帮助
            enterMode(.help)
            return  // 不要退出 command 模式，因为 help 会显示为 sheet

        case .ls:
            // ls - 刷新当前目录（相当于重新加载文件列表）
            await refreshCurrentPane()

        case .unknown:
            showToast(
                LocalizationManager.shared.localized(
                    .toastUnknownCommand,
                    command.rawInput
                )
            )

        case .rsync:
            let (valid, _, error) = CommandParser.validateRsync(command)

            if valid {
                presentRsyncSheet(sourceIsLeft: true)
            } else if let error {
                showToast(error)
            }
        }

        exitMode()
    }

    func deleteSelectedFiles() async {
        let pane = currentPane
        if pane.selections.isEmpty,
            let file = pane.activeTab.files[safe: pane.cursorIndex],
            file.isParentDirectory
        {
            showToast(
                LocalizationManager.shared.localized(.toastCannotDeleteParent)
            )
            return
        }

        let filesToDelete = selectedFiles()

        guard !filesToDelete.isEmpty else {
            showToast(
                LocalizationManager.shared.localized(.toastNoFilesToDelete)
            )
            return
        }

        do {
            try await env.fileSystem.trashFiles(
                filesToDelete,
                undoManager: undoManager
            )
            showToast(
                LocalizationManager.shared.localized(
                    .toastFilesMovedToTrash,
                    filesToDelete.count
                )
            )
            pane.clearSelections()
            await refreshCurrentPane()
        } catch {
            showToast(
                LocalizationManager.shared.localized(.error)
                    + ": \(error.localizedDescription)"
            )
        }
    }

    func selectedFiles() -> [FileItem] {
        let pane = currentPane
        let selections = pane.selections

        if selections.isEmpty {
            // 如果没有选中，返回当前光标所在的文件
            if let file = pane.activeTab.files[safe: pane.cursorIndex],
                !file.isParentDirectory
            {
                return [file]
            }
            return []
        } else {
            // 返回选中的文件，排除父目录项
            return pane.activeTab.files.filter {
                selections.contains($0.id) && !$0.isParentDirectory
            }
        }
    }

    func currentFile() -> FileItem? {
        let pane = currentPane
        guard let file = pane.activeTab.files[safe: pane.cursorIndex],
            !file.isParentDirectory
        else {
            return nil
        }
        return file
    }

    private func executeMove(
        command: ParsedCommand,
        currentPath: URL
    ) async {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: currentPath
        )

        guard result.valid else {
            if let error = result.error {
                showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // move <src> <dest>
            do {
                try await env.fileSystem.moveItem(at: srcPath, to: destPath)
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastMoveFailed,
                        error.localizedDescription
                    )
                )
            }
        } else if let destPath = result.destination {
            // move <dest> - 移动当前选中文件
            let selectedFiles = selectedFiles()
            guard !selectedFiles.isEmpty else {
                showToast(
                    LocalizationManager.shared.localized(.toastNoFileSelected)
                )
                return
            }

            do {
                try await env.fileSystem.moveFiles(
                    selectedFiles,
                    to: destPath,
                    undoManager: undoManager
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastMoveFailed,
                        error.localizedDescription
                    )
                )
            }
        }
    }

    /// 执行复制命令
    private func executeCopy(
        command: ParsedCommand,
        currentPath: URL
    ) async {
        let result = CommandParser.validateMoveOrCopy(
            command,
            currentPath: currentPath
        )

        guard result.valid else {
            if let error = result.error {
                showToast(error)
            }
            return
        }

        if let srcPath = result.source, let destPath = result.destination {
            // copy <src> <dest>
            do {
                try await env.fileSystem.copyItem(at: srcPath, to: destPath)
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastCopyFailed,
                        error.localizedDescription
                    )
                )
            }
        } else if let destPath = result.destination {
            // copy <dest> - 复制当前选中文件
            let selectedFiles = selectedFiles()
            guard !selectedFiles.isEmpty else {
                showToast(
                    LocalizationManager.shared.localized(.toastNoFileSelected)
                )
                return
            }

            do {
                try await env.fileSystem.copyFiles(
                    selectedFiles,
                    to: destPath,
                    undoManager: undoManager
                )
                await refreshCurrentPane()
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastCopyFailed,
                        error.localizedDescription
                    )
                )
            }
        }
    }

    /// 执行删除命令
    private func executeDelete(
        command: ParsedCommand,
        currentPath: URL
    ) async {
        let result = CommandParser.validateDelete(
            command,
            currentPath: currentPath
        )

        if let targetPath = result.targetPath {
            // delete <name> - 删除指定文件
            do {
                try await env.fileSystem.trashItem(at: targetPath)
                await refreshCurrentPane()
                showToast(
                    LocalizationManager.shared.localized(.toastDeleted)
                        + ": \(targetPath.lastPathComponent)"
                )
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastDeleteFailed,
                        error.localizedDescription
                    )
                )
            }
        } else {
            // delete - 删除当前选中文件
            let selectedFiles = selectedFiles()
            guard !selectedFiles.isEmpty else {
                showToast(
                    LocalizationManager.shared.localized(.toastNoFileSelected)
                )
                return
            }

            do {
                try await env.fileSystem.trashFiles(
                    selectedFiles,
                    undoManager: undoManager
                )
                await refreshCurrentPane()
                showToast(
                    LocalizationManager.shared.localized(
                        .toastFilesMovedToTrash,
                        selectedFiles.count
                    )
                )
            } catch {
                showToast(
                    LocalizationManager.shared.localized(
                        .toastDeleteFailed,
                        error.localizedDescription
                    )
                )
            }
        }
    }
}
