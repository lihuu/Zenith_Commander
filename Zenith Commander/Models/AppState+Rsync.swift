//
//  AppState+Rsync.swift
//  Zenith Commander
//
//  Rsync 同步功能状态管理扩展
//

import Foundation

// Helper function to access localization
private func L(_ key: LocalizedStringKey) -> String {
    LocalizationManager.shared.localized(key)
}

extension AppState {

    /// 关闭 Rsync 配置弹窗
    func dismissRsyncSheet() {
        activeSheet = nil
    }
}
