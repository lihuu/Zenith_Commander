//
//  RsyncSettingsProvider.swift
//  Zenith Commander
//
//  Rsync 插件设置提供者
//

import SwiftUI

/// Rsync 插件的设置提供者
struct RsyncSettingsProvider: SettingsProvider {
    let context: PluginContext

    var pluginId: String { "rsync" }

    var settingsTitle: String {
        LocalizationManager.shared.localized(.settingsRsync)
    }

    var settingsIcon: String { "arrow.triangle.2.circlepath" }

    var settingsOrder: Int { 40 }

    func settingsView() -> AnyView {
        AnyView(
            RsyncSettingsSection(
                settings: Binding(
                    get: { SettingsManager.shared.settings.rsync },
                    set: { newValue in
                        SettingsManager.shared.settings.rsync = newValue
                    }
                )
            )
        )
    }
}
