//
//  FzfSettings.swift
//  Zenith Commander
//
//  Settings model for fzf plugin
//

import Foundation

/// Fzf 设置
struct FzfSettings: Codable, Equatable {
    /// 是否启用 Fzf 集成（用户偏好，与「fzf 是否已安装」分离）。
    ///
    /// 设计说明：`enabled` 只表示用户**想不想**开启集成，不应在 `.default` 里快照
    /// `isFzfInstalled()`。原实现把安装状态快照进 `enabled` 并持久化，导致用户首次启动
    /// 时未装 fzf → `enabled=false` 被冻结 → 之后装了 fzf，开关仍是关（即使重启也不恢复，
    /// 因为持久化值覆盖默认）。正确的「可用性」由 `FzfService.shared.isFzfInstalled()`
    /// 实时探测；功能开关点应使用 effective gate `enabled && isFzfInstalled()`。
    /// `PaneView.swift` 的 fzf 按钮已是 `isFzfInstalled() && settings.fzf.enabled`，正确。
    var enabled: Bool

    /// 默认设置：用户偏好默认开启，实际可用性由安装探测决定。
    static var `default`: FzfSettings {
        FzfSettings(enabled: true)
    }
}
