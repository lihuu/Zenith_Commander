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
    
    // Provider Registry
    private var providers: [String: FileSystemProvider] = [:]
    private let localProvider = LocalFileSystemProvider()

    private init() {
        // Register default local provider
        register(provider: localProvider)
        
        // Register SFTP provider
        let sftpProvider = SFTPFileSystemProvider()
        register(provider: sftpProvider)
    }
    
    // MARK: - Provider Management
    
    func register(provider: FileSystemProvider) {
        providers[provider.scheme] = provider
    }
    
    private func getProvider(for url: URL) -> FileSystemProvider {
        // Default to local provider if scheme is file or empty
        if url.isFileURL || url.scheme == nil || url.scheme == "file" {
            return localProvider
        }
        
        if let scheme = url.scheme, let provider = providers[scheme] {
            return provider
        }
        
        // Fallback to local provider (or handle error)
        Logger.fileSystem.warning("No provider found for scheme: \(url.scheme ?? "nil"), defaulting to local")
        return localProvider
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

    /// 加载目录内容（带权限检查）- 异步
    func loadDirectoryWithPermissionCheck(
        at path: URL,
        showHidden: Bool = false
    ) async -> DirectoryLoadResult {
        let provider = getProvider(for: path)
        
        do {
            let files = try await provider.loadDirectory(at: path)
            // Filter hidden files if needed (though providers might handle this)
            let filteredFiles = showHidden ? files : files.filter { !$0.isHidden }
            return .success(filteredFiles)
        } catch {
            // Handle specific errors
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && (nsError.code == NSFileReadNoPermissionError || nsError.code == 257) {
                return .permissionDenied(path)
            }
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
                return .notFound(path)
            }
            return .error(error)
        }
    }

    /// 加载目录内容（简单版本，兼容旧代码）- 异步
    func loadDirectory(at path: URL, showHidden: Bool = false) async
        -> [FileItem]
    {
        let result = await loadDirectoryWithPermissionCheck(
            at: path,
            showHidden: showHidden
        )
        switch result {
        case .success(let files):
            return files
        default:
            return []
        }
    }


    /// 获取上级目录
    func parentDirectory(of path: URL) -> URL {
        let provider = getProvider(for: path)
        return provider.parentDirectory(of: path)
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
        var drives: [DriveInfo] = []

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

                let driveType: DriveType
                if volumeURL.path == "/" {
                    driveType = .system
                } else if !isLocal {
                    driveType = .network
                } else if isRemovable {
                    driveType = .removable
                } else {
                    driveType = .external
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

    /// 复制文件
    func copyFiles(_ files: [FileItem], to destination: URL) async throws {
        guard let firstFile = files.first else { return }
        // Assume all files are from the same provider
        let provider = getProvider(for: firstFile.path)
        // Check if destination is same provider
        let destProvider = getProvider(for: destination)
        
        if provider.scheme == destProvider.scheme {
            try await provider.copy(items: files, to: destination)
        } else {
            // TODO: Handle cross-provider copy (download then upload)
            throw NSError(domain: "FileSystemService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cross-provider copy not implemented yet"])
        }
    }

    /// 移动文件
    func moveFiles(_ files: [FileItem], to destination: URL) async throws {
        guard let firstFile = files.first else { return }
        let provider = getProvider(for: firstFile.path)
        let destProvider = getProvider(for: destination)
        
        if provider.scheme == destProvider.scheme {
            try await provider.move(items: files, to: destination)
        } else {
             throw NSError(domain: "FileSystemService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cross-provider move not implemented yet"])
        }
    }

    /// 删除文件（移动到废纸篓）
    func trashFiles(_ files: [FileItem]) async throws {
        guard let firstFile = files.first else { return }
        let provider = getProvider(for: firstFile.path)
        try await provider.delete(items: files)
    }

    /// 永久删除文件
    func deleteFiles(_ files: [FileItem]) async throws {
        // Currently mapped to delete in provider
        try await trashFiles(files)
    }

    /// 创建目录
    func createDirectory(at path: URL, name: String) async throws -> URL {
        let provider = getProvider(for: path)
        let item = try await provider.createDirectory(at: path, name: name)
        return item.path
    }

    /// 创建空文件
    func createFile(at path: URL, name: String) async throws -> URL {
        let provider = getProvider(for: path)
        let item = try await provider.createFile(at: path, name: name)
        return item.path
    }

    /// 打开文件
    func openFile(_ file: FileItem) {
        let provider = getProvider(for: file.path)
        Task {
            await provider.openFile(file)
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
        let _ = path.path.replacingOccurrences(of: "'", with: "'\\''")

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

