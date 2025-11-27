//
//  FileSystemService.swift
//  Zenith Commander
//
//  文件系统服务 - 读取真实文件系统
//

import Foundation
import AppKit

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
    
    private init() {}
    
    // MARK: - 权限检查
    
    /// 检查是否有读取权限
    func hasReadPermission(for path: URL) -> Bool {
        return fileManager.isReadableFile(atPath: path.path)
    }
    
    /// 检查目录是否存在
    func directoryExists(at path: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    /// 请求用户选择文件夹授权（通过 NSOpenPanel）
    func requestFolderAccess(for path: URL, completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.message = "Zenith Commander needs access to this folder.\nPlease select the folder to grant access."
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - 目录操作
    
    /// 加载目录内容（带权限检查）
    func loadDirectoryWithPermissionCheck(at path: URL, showHidden: Bool = false) -> DirectoryLoadResult {
        // 检查目录是否存在
        guard directoryExists(at: path) else {
            return .notFound(path)
        }
        
        // 检查读取权限
        guard hasReadPermission(for: path) else {
            return .permissionDenied(path)
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey,
                    .isHiddenKey
                ],
                options: showHidden ? [] : [.skipsHiddenFiles]
            )
            
            let files = contents.compactMap { url in
                FileItem.fromURL(url)
            }.sorted { item1, item2 in
                // 文件夹优先，然后按名称排序
                if item1.type == .folder && item2.type != .folder {
                    return true
                } else if item1.type != .folder && item2.type == .folder {
                    return false
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
            
            return .success(files)
        } catch let error as NSError {
            // 检查是否是权限错误
            if error.domain == NSCocoaErrorDomain && 
               (error.code == NSFileReadNoPermissionError || error.code == 257) {
                return .permissionDenied(path)
            }
            print("Error loading directory: \(error)")
            return .error(error)
        }
    }
    
    /// 加载目录内容（简单版本，兼容旧代码）
    func loadDirectory(at path: URL, showHidden: Bool = false) -> [FileItem] {
        let result = loadDirectoryWithPermissionCheck(at: path, showHidden: showHidden)
        switch result {
        case .success(let files):
            return files
        default:
            return []
        }
    }
    
    /// 获取上级目录
    func parentDirectory(of path: URL) -> URL {
        return path.deletingLastPathComponent()
    }
    
    /// 检查是否可以进入目录
    func canEnterDirectory(at path: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue && fileManager.isReadableFile(atPath: path.path)
    }
    
    // MARK: - 驱动器/卷操作
    
    /// 获取所有挂载的卷
    func getMountedVolumes() -> [DriveInfo] {
        var drives: [DriveInfo] = []
        
        // 获取所有挂载的卷
        let volumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsLocalKey
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
                    .volumeIsLocalKey
                ])
                
                let name = resourceValues.volumeName ?? volumeURL.lastPathComponent
                let totalCapacity = Int64(resourceValues.volumeTotalCapacity ?? 0)
                let availableCapacity = Int64(resourceValues.volumeAvailableCapacity ?? 0)
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
                print("Error getting volume info: \(error)")
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
    
    /// 生成唯一的文件名（处理重名情况）
    /// 规则：原名 -> 原名 Copy -> 原名 Copy1 -> 原名 Copy2 ...
    func generateUniqueFileName(for fileName: String, in directory: URL) -> String {
        let destURL = directory.appendingPathComponent(fileName)
        
        // 如果不存在同名文件，直接返回原名
        if !fileManager.fileExists(atPath: destURL.path) {
            return fileName
        }
        
        // 分离文件名和扩展名
        let nameWithoutExtension: String
        let fileExtension: String
        
        if fileName.contains(".") && !fileName.hasPrefix(".") {
            let components = fileName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            if components.count == 2 {
                // 处理多重扩展名的情况，如 file.tar.gz
                let lastDotIndex = fileName.lastIndex(of: ".")!
                nameWithoutExtension = String(fileName[..<lastDotIndex])
                fileExtension = String(fileName[lastDotIndex...])
            } else {
                nameWithoutExtension = fileName
                fileExtension = ""
            }
        } else {
            // 隐藏文件或无扩展名
            nameWithoutExtension = fileName
            fileExtension = ""
        }
        
        // 尝试 "原名 Copy"
        let copyName = "\(nameWithoutExtension) Copy\(fileExtension)"
        let copyURL = directory.appendingPathComponent(copyName)
        if !fileManager.fileExists(atPath: copyURL.path) {
            return copyName
        }
        
        // 尝试 "原名 Copy1", "原名 Copy2", ...
        var counter = 1
        while true {
            let numberedName = "\(nameWithoutExtension) Copy\(counter)\(fileExtension)"
            let numberedURL = directory.appendingPathComponent(numberedName)
            if !fileManager.fileExists(atPath: numberedURL.path) {
                return numberedName
            }
            counter += 1
            
            // 防止无限循环（理论上不应该发生）
            if counter > 10000 {
                let timestamp = Int(Date().timeIntervalSince1970)
                return "\(nameWithoutExtension) Copy\(timestamp)\(fileExtension)"
            }
        }
    }
    
    /// 复制文件（自动处理重名）
    func copyFiles(_ files: [FileItem], to destination: URL) throws {
        for file in files {
            let uniqueName = generateUniqueFileName(for: file.name, in: destination)
            let destURL = destination.appendingPathComponent(uniqueName)
            try fileManager.copyItem(at: file.path, to: destURL)
        }
    }
    
    /// 移动文件（自动处理重名）
    func moveFiles(_ files: [FileItem], to destination: URL) throws {
        for file in files {
            let uniqueName = generateUniqueFileName(for: file.name, in: destination)
            let destURL = destination.appendingPathComponent(uniqueName)
            try fileManager.moveItem(at: file.path, to: destURL)
        }
    }
    
    /// 删除文件（移动到废纸篓）
    func trashFiles(_ files: [FileItem]) throws {
        for file in files {
            try fileManager.trashItem(at: file.path, resultingItemURL: nil)
        }
    }
    
    /// 永久删除文件
    func deleteFiles(_ files: [FileItem]) throws {
        for file in files {
            try fileManager.removeItem(at: file.path)
        }
    }
    
    /// 创建目录
    func createDirectory(at path: URL, name: String) throws -> URL {
        let newPath = path.appendingPathComponent(name)
        try fileManager.createDirectory(at: newPath, withIntermediateDirectories: false)
        return newPath
    }
    
    /// 重命名文件
    func renameFile(_ file: FileItem, to newName: String) throws -> URL {
        let newPath = file.path.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: file.path, to: newPath)
        return newPath
    }
    
    /// 批量重命名
    func batchRename(files: [FileItem], findPattern: String, replacePattern: String, useRegex: Bool) throws -> [(old: String, new: String)] {
        var results: [(old: String, new: String)] = []
        
        for (index, file) in files.enumerated() {
            let oldName = file.name
            var newName: String
            
            // 处理动态变量
            var processedReplace = replacePattern
                .replacingOccurrences(of: "{n}", with: String(format: "%03d", index + 1))
                .replacingOccurrences(of: "{date}", with: formattedDate())
            
            if useRegex {
                // 正则表达式替换
                if let regex = try? NSRegularExpression(pattern: findPattern, options: []) {
                    let range = NSRange(oldName.startIndex..., in: oldName)
                    newName = regex.stringByReplacingMatches(in: oldName, options: [], range: range, withTemplate: processedReplace)
                } else {
                    newName = oldName
                }
            } else {
                // 普通字符串替换
                newName = oldName.replacingOccurrences(of: findPattern, with: processedReplace)
            }
            
            if newName != oldName {
                let _ = try renameFile(file, to: newName)
                results.append((old: oldName, new: newName))
            }
        }
        
        return results
    }
    
    /// 打开文件
    func openFile(_ file: FileItem) {
        NSWorkspace.shared.open(file.path)
    }
    
    /// 在 Finder 中显示
    func revealInFinder(_ file: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([file.path])
    }
    
    /// 在终端打开
    func openInTerminal(path: URL) {
        let script: String
        
        // 尝试打开 iTerm2，如果没有则使用 Terminal.app
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil {
            script = """
            tell application "iTerm2"
                create window with default profile
                tell current session of current window
                    write text "cd '\(path.path)'"
                end tell
                activate
            end tell
            """
        } else {
            script = """
            tell application "Terminal"
                do script "cd '\(path.path)'"
                activate
            end tell
            """
        }
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
}
