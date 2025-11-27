//
//  FileSystemService.swift
//  Zenith Commander
//
//  文件系统服务 - 读取真实文件系统
//

import Foundation
import AppKit

/// 文件系统服务
class FileSystemService {
    static let shared = FileSystemService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - 目录操作
    
    /// 加载目录内容
    func loadDirectory(at path: URL, showHidden: Bool = false) -> [FileItem] {
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
            
            return contents.compactMap { url in
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
        } catch {
            print("Error loading directory: \(error)")
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
    
    /// 复制文件
    func copyFiles(_ files: [FileItem], to destination: URL) throws {
        for file in files {
            let destURL = destination.appendingPathComponent(file.name)
            try fileManager.copyItem(at: file.path, to: destURL)
        }
    }
    
    /// 移动文件
    func moveFiles(_ files: [FileItem], to destination: URL) throws {
        for file in files {
            let destURL = destination.appendingPathComponent(file.name)
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
