//
//  FileSystemService.swift
//  Zenith Commander
//
//  文件系统服务 - 读取真实文件系统
//
//  Refactored to use FileSystemProvider pattern for supporting multiple file systems (Local, SFTP, etc.)
//

import AppKit
import Foundation
import os.log

/// 目录加载结果
enum DirectoryLoadResult {
    case success([FileItem])
    case permissionDenied(URL)
    case notFound(URL)
    case error(Error)
}

/// 文件系统服务
class FileSystemService {
    static let shared = FileSystemService()

    private let fileManager = FileManager.default

    private let transferService = TransferService.shared

    private func withUndoManager<T>(endpoint: FileEndpoint, manager: UndoManager?, perform action: () async throws -> T) async throws -> T {
        if endpoint is UndoSupportingEndpoint {
            let targetEndpoint = endpoint as! UndoSupportingEndpoint
            targetEndpoint.undoManager = manager
            defer {
                targetEndpoint.undoManager = nil // Ensure undoManager is reset
            }
            return try await action()
        } else {
            return try await action()
        }
    }

    // MARK: - 权限检查 (Local Only for now)

    /// 检查是否有读取权限
    func hasReadPermission(for path: URL) -> Bool {
        // Only relevant for local files
        if path.isFileURL {
            return fileManager.isReadableFile(atPath: path.path)
        }
        return true // Assume true for remote, provider will handle errors
    }

    /// 检查目录是否存在
    func directoryExists(at path: URL) -> Bool {
        if path.isFileURL {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: path.path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue
        }
        return true // Assume true for remote
    }

    /// 请求用户选择文件夹授权（通过 NSOpenPanel）
    func requestFolderAccess(
        for path: URL,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.message =
                "Zenith Commander needs access to this folder.\nPlease select the folder to grant access."
            openPanel.prompt = "Grant Access"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = path
            openPanel.canCreateDirectories = false

            openPanel.begin { response in
                if response == .OK, let selectedURL = openPanel.url {
                    // 启动安全作用域访问
                    _ = selectedURL.startAccessingSecurityScopedResource()
                    completion(selectedURL)
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// 打开系统偏好设置 - 安全与隐私
    func openSystemPreferencesPrivacy() {
        if let url = URL(
            string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 目录操作

    /// 加载目录内容（带权限检查）- 使用新 Endpoint 架构
    /// 通过 EndpointRegistry → FileOps.list() → FileItem.fromEntry()
    @MainActor
    func loadDirectoryWithPermissionCheck(
        at path: URL,
        showHidden: Bool = false
    ) async -> DirectoryLoadResult {
        // Use EndpointRegistry to resolve URL to FileEndpoint
        guard let endpoint = EndpointRegistry.shared.resolve(for: path) else {
            Logger.fileSystem.error("No endpoint found for URL: \(path)")
            return .error(NSError(domain: "FileSystemService", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No endpoint for URL"]))
        }

        let ops = endpoint.ops

        do {
            // 1. Load via FileOps.list() → [FileEntry]
            let entries = try await ops.list(at: path)

            // 2. Convert FileEntry → FileItem via fromEntry()
            var items = entries.map { FileItem.fromEntry($0) }

            // 3. Filter hidden files if needed
            if !showHidden {
                items = items.filter { !$0.isHidden }
            }

            // 4. Sort: folders first, then by name
            items.sort { item1, item2 in
                if item1.isFolder, !item2.isFolder { return true }
                if !item1.isFolder, item2.isFolder { return false }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }

            // 5. Add parent directory item if not root
            if path.standardizedFileURL.path != "/" {
                let parentPath = path.deletingLastPathComponent()
                let parentItem = FileItem.parentDirectoryItem(for: parentPath)
                items.insert(parentItem, at: 0)
            }

            return .success(items)
        } catch {
            // Handle specific errors
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain,
               nsError.code == NSFileReadNoPermissionError || nsError.code == 257
            {
                return .permissionDenied(path)
            }
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoSuchFileError {
                return .notFound(path)
            }
            if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOTDIR) {
                return .notFound(path)
            }
            return .error(error)
        }
    }

    /// 加载目录内容（简单版本，兼容旧代码）- 异步
    @MainActor
    func loadDirectory(at path: URL, showHidden: Bool = false) async
        -> [FileItem]
    {
        let result = await loadDirectoryWithPermissionCheck(
            at: path,
            showHidden: showHidden
        )
        switch result {
        case let .success(files):
            return files
        default:
            return []
        }
    }

    /// 获取上级目录
    ///
    func parentDirectory(of path: URL) -> URL {
        path.deletingLastPathComponent()
    }

    /// 检查是否可以进入目录
    func canEnterDirectory(at path: URL) -> Bool {
        // For local files, check existence and permission
        if path.isFileURL {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: path.path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue
                && fileManager.isReadableFile(atPath: path.path)
        }
        // For remote, assume yes until we try
        return true
    }

    // MARK: - 驱动器/卷操作

    /// 获取所有挂载的卷
    func getMountedVolumes() -> [DriveInfo] {
        Self.loadMountedVolumes()
    }

    nonisolated static func loadMountedVolumes() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        let fileManager = FileManager.default

        // 获取所有挂载的卷
        let volumeURLs =
            fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeIsLocalKey,
                ],
                options: [.skipHiddenVolumes]
            ) ?? []

        for volumeURL in volumeURLs {
            do {
                let resourceValues = try volumeURL.resourceValues(forKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeIsLocalKey,
                ])

                let name =
                    resourceValues.volumeName ?? volumeURL.lastPathComponent
                let totalCapacity = Int64(
                    resourceValues.volumeTotalCapacity ?? 0
                )
                let availableCapacity = Int64(
                    resourceValues.volumeAvailableCapacity ?? 0
                )
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                let isLocal = resourceValues.volumeIsLocal ?? true

                let driveType: DriveType = if volumeURL.path == "/" {
                    .system
                } else if !isLocal {
                    .network
                } else if isRemovable {
                    .removable
                } else {
                    .external
                }

                let drive = DriveInfo(
                    id: volumeURL.path,
                    name: name,
                    path: volumeURL,
                    type: driveType,
                    totalCapacity: totalCapacity,
                    availableCapacity: availableCapacity
                )
                drives.append(drive)
            } catch {
                Logger.fileSystem.warning(
                    "Error getting volume info: \(error.localizedDescription)"
                )
            }
        }

        return drives.sorted { d1, d2 in
            // 系统盘优先
            if d1.type == .system { return true }
            if d2.type == .system { return false }
            return d1.name < d2.name
        }
    }

    // MARK: - 文件操作

    //
    private func resolveEndpoint(for url: URL) throws -> FileEndpoint {
        guard let endpoint = EndpointRegistry.shared.resolve(for: url) else {
            Logger.fileSystem.error("No endpoint found for URL: \(url)")
            throw NSError(domain: "FileSystemService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No endpoint for URL"])
        }
        return endpoint
    }

    /// 复制文件
    func copyFiles(_ files: [FileItem], to destination: URL, undoManager: UndoManager? = nil) async throws {
        guard !files.isEmpty else { return }
        let sources = files.map(\.path)
        let result = try await transferService.transfer(sources: sources, to: destination, operation: TransferOperation.copy, undoManager: undoManager)

        if result.failedCount > 0 {
            let errorMsg = result.errors.first?.localizedDescription ?? "Unknown error"
            Logger.fileSystem.error("File transfer completed with errors: \(errorMsg)")
        } else if result.successCount > 0 {
            // 成功传输，显示提示
            let message = "Copied \(result.successCount) item(s)"
            Logger.fileSystem.info("File transfer successful: \(message)")
        }
    }

    /// 移动文件
    func moveFiles(_ files: [FileItem], to destination: URL, undoManager: UndoManager? = nil) async throws {
        guard !files.isEmpty else { return }

        let result = try await transferService.transfer(sources: files.map(\.path), to: destination, operation: .move, undoManager: undoManager)

        if result.failedCount > 0 {
            let errorMsg = result.errors.first?.localizedDescription ?? "Unknown error"
            Logger.fileSystem.error("File move completed with errors: \(errorMsg)")
        } else if result.successCount > 0 {
            // 成功传输，显示提示
            let message = "Moved \(result.successCount) item(s)"
            Logger.fileSystem.info("File move successful: \(message)")
        }
    }

    /// 删除文件（移动到废纸篓）
    func trashFiles(_ files: [FileItem], undoManager: UndoManager? = nil) async throws {
        guard !files.isEmpty else { return }
        let endpoint = try resolveEndpoint(for: files.first!.path) // Ensure we have an endpoint for the file
        try await withUndoManager(endpoint: endpoint, manager: undoManager) {
            for file in files {
                Logger.fileSystem.debug("Trashing file: \(file.path)")
                try await endpoint.ops.trash(at: file.path)
            }
        }
    }

    /// 永久删除文件
    func deleteFiles(_ files: [FileItem], undoManager: UndoManager? = nil) async throws {
        // Currently mapped to delete in provider
        try await trashFiles(files, undoManager: undoManager)
    }

    /// 创建目录
    func createDirectory(at path: URL, name: String, undoManager: UndoManager? = nil) async throws -> URL {
        let endpoint = try resolveEndpoint(for: path)

        return try await withUndoManager(endpoint: endpoint, manager: undoManager) {
            try await endpoint.ops.mkdir(at: path, name: name, recursive: false)
        }
    }

    /// 创建空文件
    func createFile(at path: URL, name: String, undoManager: UndoManager? = nil) async throws -> URL {
        let endpoint = try resolveEndpoint(for: path)
        return try await withUndoManager(endpoint: endpoint, manager: undoManager) {
            try await endpoint.ops.createFile(at: path, name: name)
        }
    }

    /// 打开文件
    func openFile(_ file: FileItem) {
        do {
            // Ensure an endpoint exists for this file; resolveEndpoint throws if not
            let endpoint = try resolveEndpoint(for: file.path)

            Task { @MainActor in
                try await endpoint.ops.openFile(at: file.path)
            }
        } catch {
            Logger.fileSystem.error("Failed to resolve endpoint for file: \(file.path), error: \(error.localizedDescription)")
            return
        }
    }

    /// 在 Finder 中显示
    func revealInFinder(_ file: FileItem) {
        if file.path.isFileURL {
            NSWorkspace.shared.activateFileViewerSelecting([file.path])
        } else {
            // Not supported for remote files yet
        }
    }

    /// 在终端打开（使用用户设置的默认终端）
    func openInTerminal(path: URL) {
        // Only support local paths for now
        guard path.isFileURL else { return }

        // 获取用户设置的默认终端
        let settings = SettingsManager.shared.settings
        let terminalOption = settings.terminal.currentTerminal

        Logger.fileSystem.debug(
            "Opening terminal '\(terminalOption.name)' at path: \(path.path)"
        )

        // 根据终端类型选择打开方式
        switch terminalOption.id {
        case "terminal":
            openInMacTerminal(path: path)
        case "iterm":
            openInITerm(path: path)
        case "warp":
            openInWarp(path: path)
        case "alacritty":
            openInAlacritty(path: path)
        case "kitty":
            openInKitty(path: path)
        case "hyper":
            openInHyper(path: path)
        default:
            openInMacTerminal(path: path)
        }
    }

    /// 在 macOS Terminal.app 打开
    private func openInMacTerminal(path: URL) {
        // 使用 open 命令 + .command 脚本文件，避免 AppleScript 权限问题
        let escapedPath = path.path.replacingOccurrences(of: "'", with: "'\\''")

        // 创建临时 .command 脚本
        let tempScript = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith_open_\(UUID().uuidString).command")

        // 脚本内容：cd 到目录，然后清理自身，启动交互式 shell
        let scriptContent = """
        #!/bin/bash
        cd '\(escapedPath)'
        rm -f "\(tempScript.path)"
        exec bash -l
        """

        do {
            try scriptContent.write(
                to: tempScript,
                atomically: true,
                encoding: .utf8
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tempScript.path
            )

            // 使用 open -a Terminal 打开脚本
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", tempScript.path]
            try process.run()

            Logger.fileSystem.debug("Opened Terminal.app at: \(path.path)")
        } catch {
            Logger.fileSystem.error(
                "Failed to open Terminal: \(error.localizedDescription)"
            )
        }
    }

    /// 在 iTerm2 打开
    private func openInITerm(path: URL) {
        _ = path.path.replacingOccurrences(of: "'", with: "'\\''")

        // iTerm2 支持通过 URL scheme 打开
        // 或者使用 open -a 打开目录
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "iTerm", path.path]

        do {
            try process.run()
            process.waitUntilExit()
            Logger.fileSystem.debug("Opened iTerm at: \(path.path)")
        } catch {
            Logger.fileSystem.error(
                "Failed to open iTerm: \(error.localizedDescription)"
            )
            // 回退到默认终端
            openInMacTerminal(path: path)
        }
    }

    /// 在 Warp 打开
    private func openInWarp(path: URL) {
        // Warp 支持通过 open -a Warp <directory> 打开指定目录
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Warp", path.path]

        do {
            try process.run()
            process.waitUntilExit()
            Logger.fileSystem.debug("Opened Warp at: \(path.path)")
        } catch {
            Logger.fileSystem.error(
                "Failed to open Warp: \(error.localizedDescription)"
            )
            openInMacTerminal(path: path)
        }
    }

    /// 在 Alacritty 打开
    private func openInAlacritty(path: URL) {
        // Alacritty 使用 --working-directory 参数
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-a", "Alacritty", "--args", "--working-directory", path.path,
        ]

        do {
            try process.run()
            Logger.fileSystem.debug("Opened Alacritty at: \(path.path)")
        } catch {
            Logger.fileSystem.error(
                "Failed to open Alacritty: \(error.localizedDescription)"
            )
            openInMacTerminal(path: path)
        }
    }

    /// 在 Kitty 打开
    private func openInKitty(path: URL) {
        // Kitty 使用 --directory 参数
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "kitty", "--args", "--directory", path.path]

        do {
            try process.run()
            Logger.fileSystem.debug("Opened Kitty at: \(path.path)")
        } catch {
            Logger.fileSystem.error(
                "Failed to open Kitty: \(error.localizedDescription)"
            )
            openInMacTerminal(path: path)
        }
    }

    /// 在 Hyper 打开
    private func openInHyper(path: URL) {
        // Hyper 通过打开目录来工作
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Hyper", path.path]

        do {
            try process.run()
            Logger.fileSystem.debug("Opened Hyper at: \(path.path)")
        } catch {
            Logger.fileSystem.error(
                "Failed to open Hyper: \(error.localizedDescription)"
            )
            openInMacTerminal(path: path)
        }
    }
}
