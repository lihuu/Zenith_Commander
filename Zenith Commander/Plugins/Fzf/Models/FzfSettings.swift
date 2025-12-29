//
//  FzfSettings.swift
//  Zenith Commander
//
//  Settings model for fzf plugin
//

import Foundation

/// Fzf 设置
struct FzfSettings: Codable, Equatable {
    /// 是否启用 Fzf 集成
    var enabled: Bool
    
    /// 默认设置
    static var `default`: FzfSettings {
        // Default to enabled if fzf is installed
        FzfSettings(
            enabled: FzfService.shared.isFzfInstalled()
        )
    }
}
