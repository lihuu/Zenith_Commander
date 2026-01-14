//
//  FileItem.swift
//  Zenith Commander
//
//  UI display model for file system entries.
//  Contains only UI properties - NO IO operations.
//  Use FileItem.fromEntry() to create from FileEntry.
//

import Foundation
import UniformTypeIdentifiers

/// 文件类型枚举 (kept for backward compatibility)
enum FileType: String, Codable {
    case folder
    case file
    case symlink
    case unknown
    
    /// Convert from FileEntryType
    init(from entryType: FileEntryType) {
        switch entryType {
        case .folder: self = .folder
        case .file: self = .file
        case .symlink: self = .symlink
        case .unknown: self = .unknown
        }
    }
}

/// 文件项模型 - UI展示用
/// 不包含任何IO操作，所有文件系统操作通过FileOps进行
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
        case "swift", "m", "h", "c", "cpp", "py", "js", "ts", "java", "rb",
            "go", "rs":
            "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "yaml", "yml", "plist":
            "curlybraces"
        case "md", "txt", "rtf", "doc", "docx":
            "doc.text"
        case "pdf":
            "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp":
            "photo"
        case "mp3", "wav", "aac", "flac", "m4a":
            "music.note"
        case "mp4", "mov", "avi", "mkv", "wmv":
            "film"
        case "zip", "tar", "gz", "rar", "7z":
            "doc.zipper"
        case "app":
            "app"
        case "dmg":
            "externaldrive"
        default:
            "doc"
        }
    }

    // MARK: - Factory Methods
    
    /// 从 FileEntry 创建 FileItem (推荐方式)
    /// - Parameter entry: FileEntry from FileOps
    /// - Returns: FileItem for UI display
    static func fromEntry(_ entry: FileEntry) -> FileItem {
        FileItem(
            id: entry.url.path,
            name: entry.name,
            path: entry.url,
            type: FileType(from: entry.type),
            size: entry.size ?? 0,
            modifiedDate: entry.modifiedDate ?? Date(),
            createdDate: entry.createdDate ?? Date(),
            isHidden: entry.isHidden,
            permissions: entry.permissions ?? "",
            fileExtension: entry.fileExtension
        )
    }
    
    /// 从 URL 创建 FileItem (已废弃，仅内部使用)
    /// - Warning: 此方法将在未来版本移除，请使用 fromEntry()
    @available(*, deprecated, message: "Use fromEntry() instead. This method will be removed.")
    nonisolated static func fromURL(_ url: URL) -> FileItem? {
        let fileManager = FileManager.default

        // Start accessing security scoped resource if needed
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        else {
            return nil
        }

        let fileType: FileType =
            if let typeAttr = attributes[.type] as? FileAttributeType {
                switch typeAttr {
                case .typeDirectory:
                    .folder
                case .typeSymbolicLink:
                    .symlink
                case .typeRegular:
                    .file
                default:
                    .unknown
                }
            } else {
                .unknown
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
    nonisolated static func parentDirectoryItem(for parentPath: URL) -> FileItem {
        FileItem(
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
        id == ".." && name == ".."
    }

    /// 是否是文件夹（基于类型，不做IO检查）
    nonisolated var isFolder: Bool {
        type == .folder
    }

    nonisolated var isSymlink: Bool {
        type == .symlink
    }
}
