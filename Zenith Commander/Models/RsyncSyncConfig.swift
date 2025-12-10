//
//  RsyncSyncConfig.swift
//  Zenith Commander
//
//  Rsync synchronization configuration and supporting types
//

import Foundation

// MARK: - Enums

/// Rsync synchronization modes
enum RsyncMode: String, Codable, CaseIterable {
    case update = "update"           // Skip newer files (default)
    case mirror = "mirror"           // Delete extras in destination
    case copyAll = "copyAll"         // Overwrite all existing files
    case custom = "custom"           // User-defined custom flags
    
    var displayName: String {
        switch self {
        case .update: return "Update (Skip newer files)"
        case .mirror: return "Mirror (Delete extras)"
        case .copyAll: return "Copy All (Overwrite existing)"
        case .custom: return "Custom"
        }
    }
}

/// Actions that can be performed on files during sync
enum RsyncAction: String, Codable {
    case copy = "copy"               // File will be copied to destination
    case update = "update"           // Existing file will be updated
    case delete = "delete"           // File will be deleted from destination
    case skip = "skip"               // File will be skipped
    
    var displayName: String {
        switch self {
        case .copy: return "Copy"
        case .update: return "Update"
        case .delete: return "Delete"
        case .skip: return "Skip"
        }
    }
}

// MARK: - Data Structures

/// Represents a single item in the rsync operation
struct RsyncItem: Identifiable, Codable {
    let id = UUID()
    let relativePath: String
    let action: RsyncAction
    
    enum CodingKeys: String, CodingKey {
        case relativePath
        case action
    }
}

/// Result of a dry-run preview operation
struct RsyncPreviewResult: Codable {
    let copied: [RsyncItem]
    let updated: [RsyncItem]
    let deleted: [RsyncItem]
    let skipped: [RsyncItem]
    
    var counts: (copy: Int, update: Int, delete: Int, skip: Int) {
        (copy: copied.count, update: updated.count, delete: deleted.count, skip: skipped.count)
    }
    
    var totalItems: Int {
        copied.count + updated.count + deleted.count + skipped.count
    }
    
    var isEmpty: Bool {
        totalItems == 0
    }
}

/// Progress information during rsync execution
struct RsyncProgress: Codable {
    let message: String              // Current operation message
    let completed: Int               // Number of operations completed
    let total: Int                   // Total number of operations
    
    var percentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(completed) / Double(total) * 100.0
    }
    
    var isComplete: Bool {
        completed >= total && total > 0
    }
}

/// Final result after rsync execution completes
struct RsyncRunResult: Codable {
    let success: Bool
    let errors: [String]
    let summary: (copy: Int, update: Int, delete: Int, skip: Int)
    
    enum CodingKeys: String, CodingKey {
        case success
        case errors
        case copiedCount
        case updatedCount
        case deletedCount
        case skippedCount
    }
    
    init(success: Bool, errors: [String], summary: (copy: Int, update: Int, delete: Int, skip: Int)) {
        self.success = success
        self.errors = errors
        self.summary = summary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        errors = try container.decode([String].self, forKey: .errors)
        let copy = try container.decode(Int.self, forKey: .copiedCount)
        let update = try container.decode(Int.self, forKey: .updatedCount)
        let delete = try container.decode(Int.self, forKey: .deletedCount)
        let skip = try container.decode(Int.self, forKey: .skippedCount)
        summary = (copy: copy, update: update, delete: delete, skip: skip)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(errors, forKey: .errors)
        try container.encode(summary.copy, forKey: .copiedCount)
        try container.encode(summary.update, forKey: .updatedCount)
        try container.encode(summary.delete, forKey: .deletedCount)
        try container.encode(summary.skip, forKey: .skippedCount)
    }
    
    var totalOperations: Int {
        summary.copy + summary.update + summary.delete + summary.skip
    }
    
    var hasErrors: Bool {
        !errors.isEmpty
    }
}
