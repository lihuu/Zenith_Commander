//
//  SortOptionTests.swift
//  Zenith CommanderTests
//
//  排序功能单元测试
//

import Testing
import Foundation
@testable import Zenith_Commander

@MainActor
struct SortOptionTests {
    
    // MARK: - Test Data
    
    func createTestFiles() -> [FileItem] {
        let now = Date()
        
        return [
            // 父目录项
            FileItem(
                id: "..",
                name: "..",
                path: URL(fileURLWithPath: "/parent"),
                type: .folder,
                size: 0,
                modifiedDate: now,
                createdDate: now,
                isHidden: false,
                permissions: "755",
                fileExtension: ""
            ),
            // 文件夹
            FileItem(
                id: "folder_z",
                name: "ZFolder",
                path: URL(fileURLWithPath: "/test/ZFolder"),
                type: .folder,
                size: 0,
                modifiedDate: now.addingTimeInterval(-3600), // 1 hour ago
                createdDate: now,
                isHidden: false,
                permissions: "755",
                fileExtension: ""
            ),
            FileItem(
                id: "folder_a",
                name: "AFolder",
                path: URL(fileURLWithPath: "/test/AFolder"),
                type: .folder,
                size: 0,
                modifiedDate: now.addingTimeInterval(-7200), // 2 hours ago
                createdDate: now,
                isHidden: false,
                permissions: "755",
                fileExtension: ""
            ),
            // 文件
            FileItem(
                id: "file_large",
                name: "large.txt",
                path: URL(fileURLWithPath: "/test/large.txt"),
                type: .file,
                size: 1000000,
                modifiedDate: now.addingTimeInterval(-1800), // 30 min ago
                createdDate: now,
                isHidden: false,
                permissions: "644",
                fileExtension: "txt"
            ),
            FileItem(
                id: "file_small",
                name: "small.txt",
                path: URL(fileURLWithPath: "/test/small.txt"),
                type: .file,
                size: 100,
                modifiedDate: now, // most recent
                createdDate: now,
                isHidden: false,
                permissions: "644",
                fileExtension: "txt"
            ),
            FileItem(
                id: "file_medium",
                name: "medium.txt",
                path: URL(fileURLWithPath: "/test/medium.txt"),
                type: .file,
                size: 5000,
                modifiedDate: now.addingTimeInterval(-10800), // 3 hours ago (oldest)
                createdDate: now,
                isHidden: false,
                permissions: "644",
                fileExtension: "txt"
            )
        ]
    }
    
    // MARK: - Sort Field Tests
    
    @Test func sortFieldDisplayNames() {
        #expect(SortField.name.displayName == "Name")
        #expect(SortField.size.displayName == "Size")
        #expect(SortField.modifiedDate.displayName == "Date")
    }
    
    // MARK: - Sort Order Tests
    
    @Test func sortOrderToggle() {
        #expect(SortOrder.ascending.toggled() == .descending)
        #expect(SortOrder.descending.toggled() == .ascending)
    }
    
    @Test func sortOrderIndicator() {
        #expect(SortOrder.ascending.indicator == "▲")
        #expect(SortOrder.descending.indicator == "▼")
    }
    
    // MARK: - Sort Option Tests
    
    @Test func defaultSortOption() {
        let defaultSort = SortOption.default
        #expect(defaultSort.field == .name)
        #expect(defaultSort.order == .ascending)
    }
    
    @Test func toggleSortOptionSameField() {
        let option = SortOption(field: .name, order: .ascending)
        let toggled = option.toggled(to: .name)
        
        #expect(toggled.field == .name)
        #expect(toggled.order == .descending)
    }
    
    @Test func toggleSortOptionDifferentField() {
        let option = SortOption(field: .name, order: .descending)
        let toggled = option.toggled(to: .size)
        
        #expect(toggled.field == .size)
        #expect(toggled.order == .ascending) // Reset to ascending
    }
    
    // MARK: - Sorting Tests
    
    @Test func sortByNameAscending() {
        let files = createTestFiles()
        let option = SortOption(field: .name, order: .ascending)
        let sorted = option.sort(files)
        
        // Parent directory should be first
        #expect(sorted[0].name == "..")
        
        // Folders should come before files
        #expect(sorted[1].type == .folder)
        #expect(sorted[2].type == .folder)
        
        // Folders sorted alphabetically
        #expect(sorted[1].name == "AFolder")
        #expect(sorted[2].name == "ZFolder")
        
        // Files sorted alphabetically
        #expect(sorted[3].name == "large.txt")
        #expect(sorted[4].name == "medium.txt")
        #expect(sorted[5].name == "small.txt")
    }
    
    @Test func sortByNameDescending() {
        let files = createTestFiles()
        let option = SortOption(field: .name, order: .descending)
        let sorted = option.sort(files)
        
        // Parent directory should still be first
        #expect(sorted[0].name == "..")
        
        // Folders in reverse alphabetical order
        #expect(sorted[1].name == "ZFolder")
        #expect(sorted[2].name == "AFolder")
        
        // Files in reverse alphabetical order
        #expect(sorted[3].name == "small.txt")
        #expect(sorted[4].name == "medium.txt")
        #expect(sorted[5].name == "large.txt")
    }
    
    @Test func sortBySizeAscending() {
        let files = createTestFiles()
        let option = SortOption(field: .size, order: .ascending)
        let sorted = option.sort(files)
        
        // Parent directory first
        #expect(sorted[0].name == "..")
        
        // Folders (size doesn't matter for folders, maintain original order)
        #expect(sorted[1].type == .folder)
        #expect(sorted[2].type == .folder)
        
        // Files sorted by size (smallest to largest)
        #expect(sorted[3].name == "small.txt")
        #expect(sorted[3].size == 100)
        #expect(sorted[4].name == "medium.txt")
        #expect(sorted[4].size == 5000)
        #expect(sorted[5].name == "large.txt")
        #expect(sorted[5].size == 1000000)
    }
    
    @Test func sortBySizeDescending() {
        let files = createTestFiles()
        let option = SortOption(field: .size, order: .descending)
        let sorted = option.sort(files)
        
        // Parent directory first
        #expect(sorted[0].name == "..")
        
        // Files sorted by size (largest to smallest)
        let filesSorted = sorted.filter { $0.type == .file }
        #expect(filesSorted[0].name == "large.txt")
        #expect(filesSorted[1].name == "medium.txt")
        #expect(filesSorted[2].name == "small.txt")
    }
    
    @Test func sortByDateAscending() {
        let files = createTestFiles()
        let option = SortOption(field: .modifiedDate, order: .ascending)
        let sorted = option.sort(files)
        
        // Parent directory first
        #expect(sorted[0].name == "..")
        
        // Files sorted by date (oldest to newest)
        let filesSorted = sorted.filter { $0.type == .file }
        #expect(filesSorted[0].name == "medium.txt") // 3 hours ago (oldest)
        #expect(filesSorted[1].name == "large.txt")  // 30 min ago
        #expect(filesSorted[2].name == "small.txt")  // now (newest)
    }
    
    @Test func sortByDateDescending() {
        let files = createTestFiles()
        let option = SortOption(field: .modifiedDate, order: .descending)
        let sorted = option.sort(files)
        
        // Parent directory first
        #expect(sorted[0].name == "..")
        
        // Files sorted by date (newest to oldest)
        let filesSorted = sorted.filter { $0.type == .file }
        #expect(filesSorted[0].name == "small.txt")  // now (newest)
        #expect(filesSorted[1].name == "large.txt")  // 30 min ago
        #expect(filesSorted[2].name == "medium.txt") // 3 hours ago (oldest)
    }
    
    @Test func foldersAlwaysBeforeFiles() {
        let files = createTestFiles()
        
        // Test with all sort options
        let sortOptions = [
            SortOption(field: .name, order: .ascending),
            SortOption(field: .name, order: .descending),
            SortOption(field: .size, order: .ascending),
            SortOption(field: .size, order: .descending),
            SortOption(field: .modifiedDate, order: .ascending),
            SortOption(field: .modifiedDate, order: .descending)
        ]
        
        for option in sortOptions {
            let sorted = option.sort(files)
            
            // Find first file (non-folder, non-parent)
            if let firstFileIndex = sorted.firstIndex(where: { $0.type == .file }) {
                // All items before first file should be folders or parent
                for i in 0..<firstFileIndex {
                    #expect(sorted[i].type == .folder)
                }
            }
        }
    }
    
    @Test func parentDirectoryAlwaysFirst() {
        let files = createTestFiles()
        
        let sortOptions = [
            SortOption(field: .name, order: .ascending),
            SortOption(field: .name, order: .descending),
            SortOption(field: .size, order: .ascending),
            SortOption(field: .size, order: .descending),
            SortOption(field: .modifiedDate, order: .ascending),
            SortOption(field: .modifiedDate, order: .descending)
        ]
        
        for option in sortOptions {
            let sorted = option.sort(files)
            #expect(sorted[0].isParentDirectory)
            #expect(sorted[0].name == "..")
        }
    }
}
