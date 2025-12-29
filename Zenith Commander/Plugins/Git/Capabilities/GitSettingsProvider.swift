//
//  GitSettingsProvider.swift
//  Zenith Commander
//
//  Git 插件设置提供者
//

import SwiftUI

/// Git 插件的设置提供者
struct GitSettingsProvider: SettingsProvider {
    let context: PluginContext

    var pluginId: String { "git" }

    var settingsTitle: String {
        LocalizationManager.shared.localized(.settingsGit)
    }

    var settingsIcon: String { "arrow.triangle.branch" }

    var settingsOrder: Int { 30 }

    func settingsView() -> AnyView {
        AnyView(
            GitSettingsSection(
                settings: Binding(
                    get: { SettingsManager.shared.settings.git },
                    set: { newValue in
                        SettingsManager.shared.settings.git = newValue
                    }
                )
            )
        )
    }
}
