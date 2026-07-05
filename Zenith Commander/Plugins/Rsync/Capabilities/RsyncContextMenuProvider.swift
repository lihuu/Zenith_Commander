//
//  RsyncContextMenuProvider.swift
//  Zenith Commander
//
//  Rsync plugin context menu contribution
//

import SwiftUI

final class RsyncContextMenuProvider: ContextMenuProvider {
    private let pluginContext: PluginContext

    init(context: PluginContext) {
        pluginContext = context
    }

    func menuItems(for context: ContextMenuContext) -> [MenuElement] {
        // Effective gate = 用户偏好 && rsync 已安装（与 PaneView 的 fzf 按钮模式一致）。
        // 单独看 settings.rsync.enabled 会在「装了 rsync 后未重启 / 卸载 rsync 后未改设置」
        // 等场景下产生不一致菜单项。
        guard
            SettingsManager.shared.settings.rsync.enabled,
            RsyncService.shared.isRsyncInstalled()
        else {
            return []
        }

        return [
            .item(
                ContextMenuItem(
                    id: "showRsyncSync",
                    title: LocalizationManager.shared.localized(.rsyncSync),
                    isEnabled: true,
                    action: { [weak self] in
                        await self?.handleConfigureSync()
                    }
                ))
        ]
    }

    @MainActor
    private func handleConfigureSync() async {
        await pluginContext.dispatch(.ui(.showSheet(.rsyncSheet)))
    }
}
