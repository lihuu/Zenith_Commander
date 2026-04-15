//
//  AIPlugin.swift
//  Zenith Commander
//
//  Configurable AI tools plugin
//

import SwiftUI

struct AIPlugin: ZenithPlugin {
    let id = PluginID(rawValue: "ai")
    let displayName = "AI"
    let version = "1.0.0"

    func makeCapabilities(context: PluginContext) -> [any PluginCapability] {
        let commandProvider = AICommandProvider(context: context)
        let contextMenuProvider = AIContextMenuProvider(context: context)
        let settingsProvider = AISettingsProvider(context: context)
        return [commandProvider, contextMenuProvider, settingsProvider]
    }
}
