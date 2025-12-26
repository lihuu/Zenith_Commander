//
//  RsyncPlugin.swift
//  Zenith Commander
//
//  Created by Hu Li on 12/19/25.
//

import SwiftUI

struct RsyncPlugin: ZenithPlugin {

    let id = PluginID(rawValue: "rsync")
    let displayName: String = "Rsync"
    let version: String = "1.0.0"

    func makeCapabilities(context: PluginContext) -> [any PluginCapability] {
        let cmd = RsyncCommandProvider(context: context)
        let ui = RsyncUIContribution { req in
            guard req == .rsyncSheet else { return nil }
            return AnyView(RsyncSyncSheetView(context: context))
        }
        let contextMenu = RsyncContextMenuProvider(context: context)
        let keybindings = RsyncKeybindingProvider(context: context)
        let settings = RsyncSettingsProvider(context: context)
        return [cmd, ui, contextMenu, keybindings, settings]
    }
}
