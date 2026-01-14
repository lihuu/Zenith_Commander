//
//  FileEntry.swift
//  Zenith Commander
//
//  Protocol-agnostic file system entry model.
//  Used by FileOps for directory listings and stat operations.
//  Contains no UI logic - pure data carrier for IO operations.
//

import Foundation

// MARK: - File Entry Type

/// File entry type - protocol-agnostic
/// Mirrors the concept of file types without UI dependencies
enum FileEntryType: String, Sendable, Codable {
    case folder
    case file
    case symlink
    case unknown
}

// MARK: - File Entry

/// Protocol-agnostic file entry model
/// This is the data carrier returned by FileOps.list() and FileOps.stat()
/// Contains only file system metadata - no UI properties
struct FileEntry: Sendable {
    /// File/directory name
    let name: String
    
    /// Full URL (local or remote)
    let url: URL
    
    /// Entry type
    let type: FileEntryType
    
    /// File size in bytes (nil if unknown or directory)
    let size: Int64?
    
    /// Last modification date (nil if unknown)
    let modifiedDate: Date?
    
    /// Creation date (nil if unknown)
    let createdDate: Date?
    
    /// Whether the file is hidden
    let isHidden: Bool
    
    /// POSIX permissions string (nil if unknown or not applicable)
    let permissions: String?
    
    /// File extension (empty string if none)
    let fileExtension: String
    
    /// Whether this entry represents a folder (including symlinks to folders)
    var isFolder: Bool {
        type == .folder
    }
    
    /// Whether this is a symbolic link
    var isSymlink: Bool {
        type == .symlink
    }
}

// MARK: - Convenience Initializers

extension FileEntry {
    /// Create a FileEntry with minimal required fields
    /// Optional fields default to nil/false/empty as appropriate
    /// nonisolated to allow creation from any actor context
    nonisolated init(
        name: String,
        url: URL,
        type: FileEntryType,
        size: Int64? = nil,
        modifiedDate: Date? = nil,
        createdDate: Date? = nil,
        isHidden: Bool = false,
        permissions: String? = nil
    ) {
        self.name = name
        self.url = url
        self.type = type
        self.size = size
        self.modifiedDate = modifiedDate
        self.createdDate = createdDate
        self.isHidden = isHidden
        self.permissions = permissions
        self.fileExtension = url.pathExtension
    }
}

// MARK: - Hashable & Equatable

extension FileEntry: Hashable {
    static func == (lhs: FileEntry, rhs: FileEntry) -> Bool {
        lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

// MARK: - Identifiable

extension FileEntry: Identifiable {
    var id: String {
        url.absoluteString
    }
}
