//
//  AppState+InlineEditing.swift
//  Zenith Commander
//
//  单个文件内联编辑扩展
//

import Foundation

extension AppState {
    /// 开始编辑指定文件
    func startEditingFile(_ file: FileItem) {
        editingFileId = file.id
        editingFileName = file.name
        enterMode(.rename)
    }

    /// 完成文件编辑并重命名
    func finishEditingFile() async {
        guard let fileId = editingFileId,
              let file = currentPane.activeTab.files.first(where: { $0.id == fileId })
        else {
            cancelEditingFile()
            return
        }

        let newName = editingFileName.trimmingCharacters(in: .whitespaces)

        // 如果新名称与原名称相同或为空，直接取消
        if newName.isEmpty || newName == file.name {
            cancelEditingFile()
            return
        }

        let newPath = file.path.deletingLastPathComponent()
            .appendingPathComponent(newName)

        do {
            try await env.fileSystem.moveItem(at: file.path, to: newPath)
            showToast(
                LocalizationManager.shared.localized(
                    .toastFileRenamed,
                    file.name,
                    newName
                )
            )
            await refreshCurrentPane()
        } catch {
            showToast(
                LocalizationManager.shared.localized(
                    .toastRenameError,
                    error.localizedDescription
                )
            )
        }

        cancelEditingFile()
    }

    /// 取消编辑
    func cancelEditingFile() {
        editingFileId = nil
        editingFileName = ""
        exitMode()
    }
}
