//
//  SortOption.swift
//  Zenith Commander
//
//  排序选项模型
//

import Foundation

/// 排序字段
enum SortField: String, Codable, CaseIterable {
    case name
    case size
    case modifiedDate
    
    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .size:
            return "Size"
        case .modifiedDate:
            return "Date"
        }
    }
}

/// 排序顺序
enum SortOrder: String, Codable {
    case ascending
    case descending
    
    /// 切换排序顺序
    func toggled() -> SortOrder {
        self == .ascending ? .descending : .ascending
    }
    
    /// 排序指示器符号
    var indicator: String {
        self == .ascending ? "▲" : "▼"
    }
}

/// 排序选项（字段 + 顺序）
struct SortOption: Codable, Equatable {
    var field: SortField?
    var order: SortOrder
    
    /// 默认：无排序
    static let `default` = SortOption(field: nil, order: .ascending)
    
    /// 是否有排序
    var isActive: Bool {
        field != nil
    }
    
    /// 切换到指定字段的排序
    /// 如果已经是该字段，则切换顺序；否则使用升序
    func toggled(to newField: SortField) -> SortOption {
        if field == newField {
            return SortOption(field: field, order: order.toggled())
        } else {
            return SortOption(field: newField, order: .ascending)
        }
    }
    
    /// 对文件列表进行排序
    /// - Parameter files: 要排序的文件列表
    /// - Returns: 排序后的文件列表（无排序时返回原始列表）
    func sort(_ files: [FileItem]) -> [FileItem] {
        // 无排序时直接返回原始列表
        guard field != nil else {
            return files
        }
        
        // 分离文件夹和文件
        let folders = files.filter { $0.type == .folder }
        let regularFiles = files.filter { $0.type != .folder }
        
        // 分别排序
        let sortedFolders = sortItems(folders)
        let sortedFiles = sortItems(regularFiles)
        
        // 合并：文件夹在前
        return sortedFolders + sortedFiles
    }
    
    /// 对单一类型的项目进行排序
    private func sortItems(_ items: [FileItem]) -> [FileItem] {
        guard let sortField = field else {
            return items
        }
        
        return items.sorted { lhs, rhs in
            // 父目录项 (..) 始终排在最前面
            if lhs.isParentDirectory { return true }
            if rhs.isParentDirectory { return false }
            
            let ascending = order == .ascending
            
            switch sortField {
            case .name:
                return ascending 
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.name.localizedStandardCompare(rhs.name) == .orderedDescending
                
            case .size:
                return ascending ? lhs.size < rhs.size : lhs.size > rhs.size
                
            case .modifiedDate:
                return ascending 
                    ? lhs.modifiedDate < rhs.modifiedDate 
                    : lhs.modifiedDate > rhs.modifiedDate
            }
        }
    }
}
