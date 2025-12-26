//
//  FzfPlugin.swift
//  Zenith Commander
//
//  Fzf fuzzy search plugin
//

import SwiftUI

struct FzfPlugin: ZenithPlugin {
    let id = PluginID(rawValue: "fzf")
    let displayName: String = "Fzf"
    let version: String = "1.0.0"
    
    func makeCapabilities(context: PluginContext) -> [any PluginCapability] {
        let cmd = FzfCommandProvider(context: context)
        let ui = FzfUIContribution(context: context)
        let settings = FzfSettingsProvider(context: context)
        return [cmd, ui, settings]
    }
}
