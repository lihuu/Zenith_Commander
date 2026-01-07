//
//  AppState+Filter.swift
//  Zenith Commander
//
//  文件过滤扩展
//

// MARK: - 过滤功能扩展

extension AppState {
    func applyFilter() {
        let pane = currentPane
        let tab = pane.activeTab
        tab.applyFilter(filterInput, useRegex: filterUseRegex)
        pane.cursorIndex = 0
    }

    func doFilter() {
        let pane = currentPane
        pane.activeTab.resetFilter()
        mode = .normal
        filterInput = ""
        filterUseRegex = false
    }
}
