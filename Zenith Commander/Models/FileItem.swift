//
//  FileItem.swift
//  Zenith Commander
//
//  文件系统项模型
//

import Foundation
import UniformTypeIdentifiers

/// 文件类型枚举
enum FileType: String, Codable {
    case folder
    case file
    case symlink
    case unknown
}

/// 文件项模型
struct FileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let type: FileType
    let size: Int64
    let modifiedDate: Date
    let createdDate: Date
    let isHidden: Bool
    let permissions: String
    let fileExtension: String
    
    /// Git 状态（可选）
    var gitStatus: GitFileStatus = .clean
    
    /// 创建带有 Git 状态的副本
    func withGitStatus(_ status: GitFileStatus?) -> FileItem {
        var copy = self
        copy.gitStatus = status ?? .clean
        return copy
    }
    
    /// 格式化的文件大小
    var formattedSize: String {
        if type == .folder {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 格式化的修改日期
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(modifiedDate) {
            formatter.dateFormat = "HH:mm"
            return "Today, \(formatter.string(from: modifiedDate))"
        } else if calendar.isDateInYesterday(modifiedDate) {
            formatter.dateFormat = "HH:mm"
            return "Yesterday, \(formatter.string(from: modifiedDate))"
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: modifiedDate)
        }
    }
    
    /// SF Symbol 图标名称
    var iconName: String {
        // 父目录项使用特殊图标
        if isParentDirectory {
            return "arrow.turn.up.left"
        }
        
        switch type {
        case .folder:
            return "folder.fill"
        case .symlink:
            return "link"
        case .file:
            return iconForExtension(fileExtension)
        case .unknown:
            return "doc"
        }
    }
    
    /// 根据扩展名返回图标
    private func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "swift", "m", "h", "c", "cpp", "py", "js", "ts", "java", "rb", "go", "rs":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "yaml", "yml", "plist":
            return "curlybraces"
        case "md", "txt", "rtf", "doc", "docx":
            return "doc.text"
        case "pdf":
            return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp":
            return "photo"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "mp4", "mov", "avi", "mkv", "wmv":
            return "film"
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"
        case "app":
            return "app"
        case "dmg":
            return "externaldrive"
        default:
            return "doc"
        }
    }
    
    /// 从 URL 创建 FileItem
    static func fromURL(_ url: URL) -> FileItem? {
        let fileManager = FileManager.default
        
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        
        let fileType: FileType
        if let typeAttr = attributes[.type] as? FileAttributeType {
            switch typeAttr {
            case .typeDirectory:
                fileType = .folder
            case .typeSymbolicLink:
                fileType = .symlink
            case .typeRegular:
                fileType = .file
            default:
                fileType = .unknown
            }
        } else {
            fileType = .unknown
        }
        
        let size = (attributes[.size] as? Int64) ?? 0
        let modifiedDate = (attributes[.modificationDate] as? Date) ?? Date()
        let createdDate = (attributes[.creationDate] as? Date) ?? Date()
        let posixPermissions = (attributes[.posixPermissions] as? Int) ?? 0
        let permissionsString = String(format: "%o", posixPermissions)
        
        let name = url.lastPathComponent
        let isHidden = name.hasPrefix(".")
        
        return FileItem(
            id: url.path,
            name: name,
            path: url,
            type: fileType,
            size: size,
            modifiedDate: modifiedDate,
            createdDate: createdDate,
            isHidden: isHidden,
            permissions: permissionsString,
            fileExtension: url.pathExtension
        )
    }
    
    /// 创建父目录项（..）
    /// - Parameter parentPath: 父目录的 URL
    /// - Returns: 代表父目录的 FileItem
    static func parentDirectoryItem(for parentPath: URL) -> FileItem {
        return FileItem(
            id: "..",
            name: "..",
            path: parentPath,
            type: .folder,
            size: 0,
            modifiedDate: Date(),
            createdDate: Date(),
            isHidden: false,
            permissions: "",
            fileExtension: ""
        )
    }
    
    /// 是否是父目录项
    var isParentDirectory: Bool {
        return id == ".." && name == ".."
    }
}

/// 驱动器/卷信息
struct DriveInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let type: DriveType
    let totalCapacity: Int64
    let availableCapacity: Int64
    
    var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(totalCapacity - availableCapacity) / Double(totalCapacity) * 100
    }
    
    var formattedCapacity: String {
        let used = ByteCountFormatter.string(fromByteCount: totalCapacity - availableCapacity, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
        return "\(used) / \(total)"
    }
    
    var iconName: String {
        switch type {
        case .system:
            return "laptopcomputer"
        case .external:
            return "externaldrive.fill"
        case .network:
            return "network"
        case .removable:
            return "externaldrive.badge.plus"
        }
    }
}

enum DriveType {
    case system
    case external
    case network
    case removable
}
