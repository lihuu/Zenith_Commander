//
//  AISettingsProvider.swift
//  Zenith Commander
//
//  Settings provider for AI plugin
//

import SwiftUI

struct AISettingsProvider: SettingsProvider {
    let context: PluginContext

    var pluginId: String { "ai" }

    var settingsTitle: String {
        LocalizationManager.shared.localized(.settingsAI)
    }

    var settingsIcon: String { "sparkles.rectangle.stack" }

    var settingsOrder: Int { 60 }

    func settingsView() -> AnyView {
        AnyView(
            AISettingsSection(
                settings: Binding(
                    get: { SettingsManager.shared.settings.ai },
                    set: { newValue in
                        SettingsManager.shared.settings.ai = newValue
                    }
                )
            )
        )
    }
}
