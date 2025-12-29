//
//  RsyncKeybindingProvider.swift
//  Zenith Commander
//
//  Provides keybindings for Rsync plugin
//

import SwiftUI

struct RsyncKeybindingProvider: KeybindingProvider {
    let context: PluginContext

    var keybindings: [KeybindingDefinition] {
        [
            // Normal mode: Open Rsync sync sheet with Shift+S
            KeybindingDefinition(
                mode: .normal,
                keyChord: KeyChord("S", [.shift]),
                action: .ui(.showSheet(.rsyncSheet)),
                description: "Open Rsync synchronization sheet"
            ),

            // Visual mode: Sync selected files
            KeybindingDefinition(
                mode: .visual,
                keyChord: KeyChord("S", [.shift]),
                action: .ui(.showSheet(.rsyncSheet)),
                description: "Sync selected files with Rsync"
            ),
        ]
    }
}
