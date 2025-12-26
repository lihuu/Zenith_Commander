//
//  FzfSettingsProvider.swift
//  Zenith Commander
//
//  Settings provider for fzf plugin
//

import SwiftUI

struct FzfSettingsProvider: SettingsProvider {
    let context: PluginContext
    
    var pluginId: String { "fzf" }
    
    var settingsTitle: String {
        LocalizationManager.shared.localized(.settingsFzf)
    }
    
    var settingsIcon: String { "magnifyingglass" }
    
    var settingsOrder: Int { 50 }
    
    func settingsView() -> AnyView {
        AnyView(
            FzfSettingsSection(
                settings: Binding(
                    get: { SettingsManager.shared.settings.fzf },
                    set: { newValue in
                        SettingsManager.shared.settings.fzf = newValue
                    }
                )
            )
        )
    }
}
