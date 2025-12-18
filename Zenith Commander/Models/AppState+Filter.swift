//
//  AppState+Filter.swift
//  Zenith Commander
//
//  文件过滤扩展
//

import Foundation

// MARK: - 过滤功能扩展
extension AppState {
    func applyFilter() {
        let pane = currentPane
        let tab = pane.activeTab
        let filter = filterInput

        // 首次过滤时保存原始文件列表
        if tab.unfilteredFiles.isEmpty && !tab.files.isEmpty {
            tab.unfilteredFiles = tab.files
        }

        if filter.isEmpty {
            // 过滤词为空时，恢复原始列表
            if !tab.unfilteredFiles.isEmpty {
                tab.files = tab.unfilteredFiles
            }
        } else {
            // 从原始列表过滤
            let sourceFiles =
                tab.unfilteredFiles.isEmpty ? tab.files : tab.unfilteredFiles

            if filterUseRegex {
                // 正则表达式过滤
                do {
                    let regex = try NSRegularExpression(
                        pattern: filter,
                        options: [.caseInsensitive]
                    )
                    tab.files = sourceFiles.filter { file in
                        let range = NSRange(
                            file.name.startIndex...,
                            in: file.name
                        )
                        return regex.firstMatch(
                            in: file.name,
                            options: [],
                            range: range
                        ) != nil
                    }
                } catch {
                    // 正则表达式无效时，不过滤
                    tab.files = sourceFiles
                }
            } else {
                // 普通字符串匹配（大小写不敏感）
                let lowerFilter = filter.lowercased()
                tab.files = sourceFiles.filter {
                    $0.name.lowercased().contains(lowerFilter)
                }
            }
        }
        pane.cursorIndex = 0
    }

    func doFilter() {
        let pane = currentPane
        pane.activeTab.unfilteredFiles = []
        mode = .normal
        filterInput = ""
        filterUseRegex = false
    }
}
