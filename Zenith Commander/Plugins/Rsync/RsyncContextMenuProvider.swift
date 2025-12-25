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
        self.pluginContext = context
    }

    func menuItems() -> [MenuElement] {
        guard SettingsManager.shared.settings.rsync.enabled else {
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
        await pluginContext.dispatch(.ui(.openRsync))
    }
}
