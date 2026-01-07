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
        let context = CommandExecutionContext(
            commandInput: commandInput,
            currentPath: currentPane.activeTab.currentPath,
            selectedFiles: selectedFiles(),
            currentFile: currentFile(),
            undoManager: undoManager
        )

        let result = await env.commandExecution.executeCommand(context)

        if let newPath = result.newPath {
            currentPane.activeTab.currentPath = newPath
        }

        if let enterMode = result.enterMode {
            self.enterMode(enterMode)
        }

        if let uiRequest = result.uiRequest {
            await dispatch(.ui(.showSheet(uiRequest)))
        }

        if let toastMessage = result.toastMessage {
            showToast(toastMessage)
        }

        if result.refreshCurrentPane {
            await refreshCurrentPane()
        }

        if result.shouldTerminate {
            NSApp.terminate(nil)
        }

        if result.exitCommandMode {
            exitMode()
        }
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
}
