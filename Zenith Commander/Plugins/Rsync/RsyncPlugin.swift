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
            return AnyView(RsyncSyncSheetView(context: context))
        }
        let contextMenu = RsyncContextMenuProvider(context: context)
        let keybindings = RsyncKeybindingProvider(context: context)
        return [cmd, ui, contextMenu, keybindings]
    }
}
